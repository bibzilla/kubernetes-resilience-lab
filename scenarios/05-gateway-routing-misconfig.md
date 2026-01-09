# Scenario 05 — Gateway API routing misconfiguration (ALB + HTTPRoute)

## Goal
Show a modern Kubernetes routing failure:
- Pods are running
- Service exists
- Gateway/ALB exists
- But traffic fails because **HTTPRoute routes to the wrong backend port**

This is a “routing looks fine, app looks fine, but requests fail” scenario.

---

## Prereqs / Setup (already in this lab)
- Namespace: `krl`
- GatewayClass: `alb`
- Gateway: `krl-gw` (internal ALB)
- HTTPRoute: `api-route`
- Service: `api` (NodePort, `80 -> 8080`)

Get ALB DNS:
```bash
ALB=$(kubectl -n krl get gateway krl-gw -o jsonpath='{.status.addresses[0].value}')
echo "$ALB"
```

---

## Baseline (healthy)

Run from inside cluster (internal ALB):

```bash
kubectl -n krl run curl-ok --image=curlimages/curl --restart=Never \
  --command -- sh -c "curl -m 5 -sS -i http://$ALB/health"
kubectl -n krl logs pod/curl-ok
kubectl -n krl delete pod curl-ok
```

**Expected**

* `HTTP/1.1 200 OK`
* body contains `ok`

---

## Break it (misroute backend port)

Edit:
`k8s/gateway/httproute.yaml`

Change:

```yaml
backendRefs:
  - name: api
    port: 80
```

To:

```yaml
backendRefs:
  - name: api
    port: 81
```

Apply:

```bash
kubectl -n krl apply -f k8s/gateway/httproute.yaml
```

---

## Observe the failure

Test again:

```bash
kubectl -n krl run curl-bad --image=curlimages/curl --restart=Never \
  --command -- sh -c "curl -m 5 -sS -i http://$ALB/health || echo FAIL"
kubectl -n krl logs pod/curl-bad
kubectl -n krl delete pod curl-bad
```

**Expected**

* `502 Bad Gateway` or `503 Service Unavailable` (depends on ALB target health behavior)

Check route status/events:

```bash
kubectl -n krl describe httproute api-route | tail -n 60
kubectl -n krl describe gateway krl-gw | tail -n 60
```

---

## Fix (restore correct backend port)

Change the HTTPRoute backend port back to `80` and apply again:

```bash
kubectl -n krl apply -f k8s/gateway/httproute.yaml
```

Re-test:

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

Gateway/API routing can fail even when:

* Gateway is created
* ALB exists
* Pods are Ready

A single wrong `backendRefs.port` can silently break traffic.
