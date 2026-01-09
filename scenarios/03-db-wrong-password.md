# Scenario 03 — DB wrong password (auth failure)

## Goal
Reproduce an app-layer failure where the network path is OK, but Postgres rejects authentication because the DB password is wrong.

## Baseline (works)
```bash
kubectl -n krl run curl --image=curlimages/curl --restart=Never \
  --command -- sh -c "curl -m 5 -sS api/db || echo CURL_FAILED"

kubectl -n krl logs pod/curl
kubectl -n krl delete pod curl
```

Expected:
```
db_ok
```

## Break it (Kubernetes Secret)

The API reads DB creds from Secret `postgres-creds` via env vars:

* `PGHOST` -> key `host`
* `PGPORT` -> key `port`
* `PGDATABASE` -> key `dbname`
* `PGUSER` -> key `username`
* `PGPASSWORD` -> key `password`

Patch the Secret with a wrong password:

```bash
kubectl -n krl patch secret postgres-creds \
  --type merge \
  -p '{"stringData":{"password":"WRONG_PASSWORD"}}'
```

Restart the API Deployment so pods pick up the new env var value:

```bash
kubectl -n krl rollout restart deploy/api
kubectl -n krl rollout status deploy/api
```

## Symptom (failure)

Run the same curl test again:

```bash
kubectl -n krl run curl --image=curlimages/curl --restart=Never \
  --command -- sh -c "curl -m 5 -sS api/db || echo CURL_FAILED"

kubectl -n krl logs pod/curl
kubectl -n krl delete pod curl
```

Expected:
```
db_error: password authentication failed for user "appuser"
```

(Optionally check the API logs)

```bash
kubectl -n krl logs deploy/api --tail=200
```

## Fix it (restore correct password)

Patch the Secret back to the real password value and restart the API again:

```bash
kubectl -n krl patch secret postgres-creds \
  --type merge \
  -p '{"stringData":{"password":"<REAL_PASSWORD>"}}'

kubectl -n krl rollout restart deploy/api
kubectl -n krl rollout status deploy/api
```

## Verification (works again)

```bash
kubectl -n krl run curl --image=curlimages/curl --restart=Never \
  --command -- sh -c "curl -m 5 -sS api/db || echo CURL_FAILED"

kubectl -n krl logs pod/curl
kubectl -n krl delete pod curl
```

Expected:
```
db_ok
```

## Cleanup notes

* This scenario requires restarting the API pods because env vars sourced from Secrets are loaded at container start.
* The DB itself is healthy and reachable; only credentials were wrong.
