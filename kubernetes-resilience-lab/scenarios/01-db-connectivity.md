# Scenario 01 — Pod → RDS Postgres connectivity

## Goal
Prove that a Kubernetes workload in EKS can reach a private RDS Postgres instance.

## Setup
- EKS cluster in private subnets
- RDS Postgres in private subnets
- Security Group allows Postgres (5432) from EKS cluster security group
- Kubernetes Secret `postgres-creds` contains host/port/db/user/password
- `api` Deployment reads env vars from that Secret

## Commands

### Check pods
```bash
kubectl -n krl get pods
```

### Test (run curl pod, then read logs)
```bash
kubectl -n krl run curl --image=curlimages/curl --restart=Never \
  --command -- sh -c "curl -sS api/health && curl -sS api/db"

kubectl -n krl logs pod/curl
kubectl -n krl delete pod curl
```

## Expected output
```
ok
db_ok
```
