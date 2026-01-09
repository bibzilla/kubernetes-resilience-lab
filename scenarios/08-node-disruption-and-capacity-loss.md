# Scenario 07 — Node disruption and capacity loss (why replicas and placement matter)

## Goal
Demonstrate an **infrastructure-level failure** where:

- a node hosting application pods is drained
- pods are evicted and must reschedule
- traffic impact depends on **replica count and placement**
- real disruption happens only when **all service endpoints are lost**

This scenario explains **why node drains often cause no outage** — and when they *do*.

---

## Initial state (healthy)

- Deployment `api` exists
- Service `api` routes traffic
- Gateway / ALB routing is correct
- Two worker nodes exist

Verify baseline:

```bash
kubectl get nodes
kubectl -n krl get pods -l app=api -o wide
kubectl -n krl get endpoints api
```

ALB test:

```bash
ALB=$(kubectl -n krl get gateway krl-gw -o jsonpath='{.status.addresses[0].value}')

kubectl -n krl run curl-ok --image=curlimages/curl --restart=Never \
  --command -- sh -c "curl -m 3 -sS -i http://$ALB/health"
kubectl -n krl logs pod/curl-ok
kubectl -n krl delete pod curl-ok
```

**Expected**

* Endpoints list pod IPs
* ALB returns `200 OK`

---

## Why draining a node did NOT cause failure initially

When:

* replicas = 2
* pods are placed on **different nodes**

Draining **one** node:

* removes **one pod**
* but **another pod still exists**
* Service endpoints never go empty
* ALB continues returning `200`

This is **correct Kubernetes behavior**, not a bug.

---

## Force conditions for real disruption

To create a **real outage**, all of the following must be true **at the same time**:

1. Only **one replica** exists
2. That replica runs on **one node**
3. No other node is schedulable
4. The node hosting the pod is drained

This removes **all Service endpoints**.

---

## Step 1 — Reduce replicas to 1

```bash
kubectl -n krl scale deploy api --replicas=1
kubectl -n krl rollout status deploy/api
```

Confirm:

```bash
kubectl -n krl get pods -l app=api -o wide
kubectl -n krl get endpoints api
```

You should see **exactly one endpoint**.

---

## Step 2 — Make the other node unschedulable

```bash
kubectl cordon <OTHER_NODE>
```

(This prevents immediate rescheduling.)

---

## Step 3 — Start traffic probe (observer)

```bash
ALB=$(kubectl -n krl get gateway krl-gw -o jsonpath='{.status.addresses[0].value}')

kubectl -n krl run curl-loop --image=curlimages/curl --restart=Never \
  --command -- sh -c 'while true; do date +"%H:%M:%S"; curl --connect-timeout 1 -m 1 -sS -o /dev/null -w "%{http_code}\n" http://'"$ALB"'/health || echo FAIL; sleep 0.2; done'
```

Watch output:

```bash
kubectl -n krl logs -f pod/curl-loop
```

You should see steady `200` responses.

---

## Step 4 — Drain the node hosting the api pod

Identify the node:

```bash
API_NODE=$(kubectl -n krl get pod -l app=api -o jsonpath='{.items[0].spec.nodeName}')
echo "API_NODE=$API_NODE"
```

Drain it:

```bash
kubectl drain "$API_NODE" \
  --ignore-daemonsets \
  --delete-emptydir-data \
  --disable-eviction \
  --force
```

---

## Observed disruption (this is the key moment)

In the curl-loop output, you will see:

```
200
200
000
curl: (28) Resolving timed out after 1001 milliseconds
FAIL
FAIL
FAIL
```

At the same time:

```bash
kubectl -n krl get endpoints api
```

Shows:

```
api   <none>
```

### What happened

* The **only api pod** was evicted
* No node was available to reschedule it
* Service endpoints became **empty**
* ALB had **no healthy backend**
* User traffic failed

---

## Step 5 — Recover the cluster

```bash
kubectl uncordon <OTHER_NODE>
kubectl uncordon "$API_NODE"
```

Restore replicas:

```bash
kubectl -n krl scale deploy api --replicas=2
kubectl -n krl rollout status deploy/api
```

Clean up probe:

```bash
kubectl -n krl delete pod curl-loop
```

Verify recovery:

```bash
kubectl -n krl get endpoints api
kubectl -n krl run curl-up --image=curlimages/curl --restart=Never \
  --command -- sh -c "curl -m 3 -sS -i http://$ALB/health"
kubectl -n krl logs pod/curl-up
kubectl -n krl delete pod curl-up
```

Expected:

* Endpoints restored
* ALB returns `200 OK`

---

## Key lessons

* **Replicas matter**: more than one pod prevents total endpoint loss
* **Placement matters**: replicas must be on different nodes
* **Draining one node is not an outage** if another endpoint exists
* **Outages happen only when all endpoints disappear**
* PDBs protect planned drains, **not real failures**

---

## Real-world relevance

In production:

* Planned drains are common (upgrades, scaling, maintenance)
* Unplanned node loss is harsher (crash, spot reclaim, AZ issue)
* Resilience depends on **replicas + distribution + spare capacity**

This scenario demonstrates **exactly** why.
