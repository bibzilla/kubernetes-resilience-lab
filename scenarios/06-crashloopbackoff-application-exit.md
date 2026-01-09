# Scenario 06 — CrashLoopBackOff (application exits → restarts → service impact)

## Goal
Demonstrate an **application-level failure** where:

- the application exits with a non-zero code
- pods enter `CrashLoopBackOff`
- restart count increases
- service endpoints become unstable or empty
- user traffic fails even though routing and infrastructure are unchanged

This scenario shows how Kubernetes protects availability during rollouts — and how a crashing app still causes outages.

---

## Baseline (healthy)

Confirm everything works before breaking it.

Pods:
```bash
kubectl -n krl get pods -l app=api
```

Endpoints:
```bash
kubectl -n krl get endpoints api
```

ALB:
```bash
ALB=$(kubectl -n krl get gateway krl-gw -o jsonpath='{.status.addresses[0].value}')
kubectl -n krl run curl-ok --image=curlimages/curl --restart=Never \
  --command -- sh -c "curl -m 5 -sS -i http://$ALB/health"
kubectl -n krl logs pod/curl-ok
kubectl -n krl delete pod curl-ok
```

**Expected**

* Pods: `Running`
* Endpoints: pod IPs present
* ALB returns `200 OK`

---

## Break it (force application to exit)

Patch the Deployment so the container exits immediately with code `1`:

```bash
kubectl -n krl patch deploy api --type='json' -p='[
  {"op":"replace","path":"/spec/template/spec/containers/0/command","value":["/bin/sh","-c","echo FATAL_ERROR && exit 1"]}
]'
```

Watch rollout:
```bash
kubectl -n krl rollout status deploy/api
```

---

## Observe CrashLoopBackOff

### Pods
```bash
kubectl -n krl get pods -l app=api
```

You will see:

* old pods still `Running`
* new pod in `CrashLoopBackOff`

This is expected during a rolling update.

---

### Logs (fatal error)
```bash
kubectl -n krl logs <crashing-pod-name>
kubectl -n krl logs <crashing-pod-name> --previous
```

**Expected**
```
FATAL_ERROR
```

---

### Pod lifecycle & backoff
```bash
kubectl -n krl describe pod <crashing-pod-name> | tail -n 80
```

Look for:

* `Exit Code: 1`
* `Back-off restarting failed container`
* `Restart Count` increasing

---

## Why old pods stayed running (important detail)

The Deployment uses a rolling update strategy:

* `replicas: 2`
* `maxSurge: 25%` → allows **+1 extra pod**
* `maxUnavailable: 25%` → rounded down to **0**

Because the new pod is **not available**, Kubernetes must keep **both old pods running** to satisfy availability guarantees.

This is why you temporarily see **3 pods**:

* 2 old (healthy)
* 1 new (crashing)

---

## Force a full outage (guaranteed)

To demonstrate service failure clearly, remove all old pods:

```bash
kubectl -n krl scale deploy api --replicas=0
kubectl -n krl get pods -l app=api
```

Scale back up (only crashing config exists now):

```bash
kubectl -n krl scale deploy api --replicas=2
kubectl -n krl get pods -l app=api -w
```

**Expected**

* all pods enter `CrashLoopBackOff`

---

## Observe service impact

Endpoints:
```bash
kubectl -n krl get endpoints api
```

**Expected**

* endpoints empty or unstable

ALB:
```bash
ALB=$(kubectl -n krl get gateway krl-gw -o jsonpath='{.status.addresses[0].value}')
kubectl -n krl run curl-bad --image=curlimages/curl --restart=Never \
  --command -- sh -c "curl -m 5 -sS -i http://$ALB/health || echo FAIL"
kubectl -n krl logs pod/curl-bad
kubectl -n krl delete pod curl-bad
```

**Expected**

* `502 Bad Gateway` or timeout

---

## Fix (restore normal startup)

Remove the crashing command override:

```bash
kubectl -n krl patch deploy api --type='json' -p='[
  {"op":"remove","path":"/spec/template/spec/containers/0/command"}
]'
```

Restore replicas:
```bash
kubectl -n krl scale deploy api --replicas=2
kubectl -n krl rollout status deploy/api
```

---

## Verify recovery
```bash
kubectl -n krl get pods -l app=api
kubectl -n krl get endpoints api
```

ALB:
```bash
kubectl -n krl run curl-fixed --image=curlimages/curl --restart=Never \
  --command -- sh -c "curl -m 5 -sS -i http://$ALB/health"
kubectl -n krl logs pod/curl-fixed
kubectl -n krl delete pod curl-fixed
```

**Expected**

* Pods: `Running`
* Endpoints: restored
* ALB returns `200 OK`

---

## Key lesson

CrashLoopBackOff is an **application lifecycle failure**, not a networking problem.

Even with:

* correct routing
* healthy infrastructure
* existing load balancer

a crashing application causes:

* repeated restarts
* endpoint instability
* user-visible outages
