# Scenario 08 - DNS failure symptoms (wrong name + CoreDNS outage)

## Goal
Demonstrate DNS-related failures in Kubernetes:

- Wrong service name → `Could not resolve host` (NXDOMAIN)
- CoreDNS outage → DNS resolution times out (`Resolving timed out`)
- How to confirm it’s DNS (not Service / endpoints / routing)

This scenario is niche but useful for deep troubleshooting.

---

## 08A — Wrong service name (safe, deterministic)

### What it shows
- DNS returns “name does not exist”
- Curl fails immediately with `Could not resolve host`

### Break (wrong name)
```bash
kubectl -n krl run dns-bad --image=curlimages/curl --restart=Never \
  --command -- sh -c "curl -m 3 -sS http://api-wrong/health || echo DNS_FAILED"
kubectl -n krl logs pod/dns-bad
kubectl -n krl delete pod dns-bad
```

**Expected**

* `curl: (6) Could not resolve host: api-wrong`
* `DNS_FAILED`

### Fix (correct name)

```bash
kubectl -n krl run dns-good --image=curlimages/curl --restart=Never \
  --command -- sh -c "curl -m 3 -sS http://api/health || echo FAILED"
kubectl -n krl logs pod/dns-good
kubectl -n krl delete pod dns-good
```

**Expected**

* `ok`

---

## 08B — CoreDNS disruption (real DNS outage)

⚠️ This breaks DNS cluster-wide temporarily. Do it only in a lab.

### Baseline: CoreDNS pods are running

```bash
kubectl -n kube-system get pods -l k8s-app=kube-dns -o wide
```

Example (healthy):

```
coredns-...  Running
coredns-...  Running
```

### Baseline: service resolves normally (curl works)

```bash
kubectl -n krl run dns-pre --image=curlimages/curl --restart=Never \
  --command -- sh -c "curl -m 3 -sS http://api/health || echo CURL_FAILED"
kubectl -n krl logs pod/dns-pre
kubectl -n krl delete pod dns-pre
```

Observed:

```
ok
```

---

### Break DNS: scale CoreDNS to 0

```bash
kubectl -n kube-system scale deploy coredns --replicas=0
kubectl -n kube-system get pods -l k8s-app=kube-dns
```

Observed:

```
No resources found in kube-system namespace.
```

---

### Observe DNS failure symptom from inside a pod

```bash
kubectl -n krl run dns-down --image=curlimages/curl --restart=Never \
  --command -- sh -c "curl -m 3 -sS http://api/health || echo DNS_OR_CONNECTIVITY_FAILED"
kubectl -n krl logs pod/dns-down
kubectl -n krl delete pod dns-down
```

Observed:

```
curl: (28) Resolving timed out after 3000 milliseconds
DNS_OR_CONNECTIVITY_FAILED
```

Meaning:

* The pod tried to resolve `api` via DNS
* But no DNS server answered (CoreDNS was down)
* So name resolution timed out

---

### Recovery: scale CoreDNS back to 2

```bash
kubectl -n kube-system scale deploy coredns --replicas=2
kubectl -n kube-system rollout status deploy/coredns
kubectl -n kube-system get pods -l k8s-app=kube-dns -o wide
```

Then verify curl works again:

```bash
kubectl -n krl run dns-post --image=curlimages/curl --restart=Never \
  --command -- sh -c "curl -m 3 -sS http://api/health || echo FAILED"
kubectl -n krl logs pod/dns-post
kubectl -n krl delete pod dns-post
```

Observed:

```
ok
```

---

## Key lessons

* Wrong service name → fast failure: `Could not resolve host`
* CoreDNS outage → slow failure: `Resolving timed out`
* DNS failures can look like “network issues”, but the symptom is **name resolution**
* If DNS fails, even healthy Services/Pods become unreachable by name
