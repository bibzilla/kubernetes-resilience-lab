# Scenario 07 — Routing is correct, but traffic fails because readiness is broken (Service has no endpoints → ALB 502)

## Goal
Show a very real production failure:
- Gateway + Route are correct
- ALB exists and is reachable
- But the Service has **no ready endpoints**
- Result: ALB returns **502 Bad Gateway**

This is a “platform is fine, app health gating is wrong” scenario.

---

## Prereqs / Setup (already in this lab)
- Gateway `krl-gw` (internal ALB) works in healthy state
- HTTPRoute `api-route` routes to Service `api`
- Service `api` points to pods on port `8080`

Get ALB DNS:
```bash
ALB=$(kubectl -n krl get gateway krl-gw -o jsonpath='{.status.addresses[0].value}')
echo "$ALB"
```

---

## Baseline (healthy)

Confirm ALB works:

```bash
kubectl -n krl run curl-ok --image=curlimages/curl --restart=Never \
  --command -- sh -c "curl -m 5 -sS -i http://$ALB/health"
kubectl -n krl logs pod/curl-ok
kubectl -n krl delete pod curl-ok
```

Confirm Service has endpoints:

```bash
kubectl -n krl get endpoints api
```

**Expected**

* endpoints show pod IPs like `10.x.x.x:8080,...`

---

## Break it (make readiness probe fail)

Make the readiness probe use a wrong path (example: `/wrong`).
Patch deployment:

```bash
kubectl -n krl patch deploy api --type='json' -p='[
  {"op":"replace","path":"/spec/template/spec/containers/0/readinessProbe/httpGet/path","value":"/wrong"}
]'
```

Wait for rollout:

```bash
kubectl -n krl rollout status deploy/api
```

Now endpoints should disappear:

```bash
kubectl -n krl get endpoints api
```

**Expected**

* `ENDPOINTS` becomes empty (blank)

---

## Observe the symptom (ALB returns 502)

Test ALB again:

```bash
kubectl -n krl run curl-bad --image=curlimages/curl --restart=Never \
  --command -- sh -c "curl -m 5 -sS -i http://$ALB/health || echo FAIL"
kubectl -n krl logs pod/curl-bad
kubectl -n krl delete pod curl-bad
```

**Expected**

* `HTTP/1.1 502 Bad Gateway`

Why 502 happens here:

* ALB routes to the Service
* Service has no ready endpoints
* No healthy targets → ALB responds 502

Confirm endpoints are empty:

```bash
kubectl -n krl get endpoints api
kubectl -n krl get endpointslice -l kubernetes.io/service-name=api
```

Also check readiness state:

```bash
kubectl -n krl get pods -l app=api
kubectl -n krl describe pod -l app=api | tail -n 80
```

---

## Fix (restore correct readiness path)

Patch readiness back to `/health`:

```bash
kubectl -n krl patch deploy api --type='json' -p='[
  {"op":"replace","path":"/spec/template/spec/containers/0/readinessProbe/httpGet/path","value":"/health"}
]'
```

Wait for rollout:

```bash
kubectl -n krl rollout status deploy/api
```

Endpoints should return:

```bash
kubectl -n krl get endpoints api
```

Re-test ALB:

```bash
kubectl -n krl run curl-fixed --image=curlimages/curl --restart=Never \
  --command -- sh -c "curl -m 5 -sS -i http://$ALB/health"
kubectl -n krl logs pod/curl-fixed
kubectl -n krl delete pod curl-fixed
```

**Expected**

* `HTTP/1.1 200 OK`
* body contains `ok`

---

## Key lesson

Correct routing does not guarantee availability.
If readiness is wrong:

* Kubernetes removes endpoints from the Service
* Load balancer has nothing healthy to send traffic to
* Users see 502 even though “infrastructure” looks fine
