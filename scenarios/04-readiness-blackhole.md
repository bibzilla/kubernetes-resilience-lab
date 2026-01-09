# Scenario 04 — Readiness probe misconfig (traffic blackhole)

## Goal
Reproduce a production-style outage where pods are **Running** but **not Ready**, so the Service has **0 endpoints**.
Result: traffic to the Service fails even though containers are up.

## Baseline (works)
The API Deployment normally uses `/health` for readiness, so pods become Ready and the Service has endpoints.

## Break it (misconfigure readiness probe)
Change the readiness probe path to an endpoint that does not exist (example: `/health-wrong`) and roll out.

(Effect: the container stays Running because liveness is still OK, but readiness never succeeds.)

## Symptom (failure)

### Pods are Running but Not Ready
```bash
kubectl -n krl get pods -l app=api
```

Observed:
```
NAME                  READY   STATUS    RESTARTS   AGE
api-6cbf8b99b-92w5g   0/1     Running   0          108s
api-6cbf8b99b-mtzx9   0/1     Running   0          108s
```

### Service has 0 endpoints
```bash
kubectl -n krl describe svc api | sed -n '1,120p'
```

Observed (key lines):
```
Port:                     http  80/TCP
TargetPort:               8080/TCP
Endpoints:
```

### Traffic to the Service fails (blackhole)
```bash
kubectl -n krl run curl --image=curlimages/curl --restart=Never \
  --command -- sh -c "curl -m 5 -sS api/health || echo CURL_FAILED"

kubectl -n krl logs pod/curl
kubectl -n krl delete pod curl
```

Observed:
```
CURL_FAILED
curl: (7) Failed to connect to api port 80 after 1 ms: Could not connect to server
```

### Root cause proof (readiness probe failing)
```bash
kubectl -n krl describe pod api-6cbf8b99b-92w5g
```

Observed (key lines):
```
Liveness:   http-get http://:8080/health
Readiness:  http-get http://:8080/health-wrong
...
Warning  Unhealthy  ...  Readiness probe failed: HTTP probe failed with statuscode: 404
```

## Why this is a “traffic blackhole”

* A pod can be **Running** but still **not receive traffic**.
* Kubernetes only puts **Ready** pods into Service endpoints.
* When *all* pods fail readiness, the Service has **no endpoints**, so requests have nowhere to go.

## Fix (restore correct readiness path)
```bash
kubectl -n krl patch deploy api --type='json' -p='[
  {"op":"replace","path":"/spec/template/spec/containers/0/readinessProbe/httpGet/path","value":"/health"}
]'

kubectl -n krl rollout status deploy/api
```

## Verification (works again)
```bash
kubectl -n krl get endpoints api
```

Expected: endpoints are present again.

## Cleanup notes

* **Running ≠ Ready**.
* Liveness keeps the process alive; readiness controls whether the pod receives traffic.
* This is a common outage mode after a deploy when the readiness probe path/port is wrong.
