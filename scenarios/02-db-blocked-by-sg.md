# Scenario 02 — DB blocked by Security Group

## Goal
Reproduce a real production-style failure: app is healthy, but DB becomes unreachable at the network layer.

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

## Break it (Terraform)

Temporarily remove the DB ingress rule that allows port 5432 from EKS to RDS:

* In `infra/terraform/rds.tf`, comment out:
  `aws_security_group_rule.postgres_ingress_from_eks`
* Apply:

```bash
cd infra/terraform
terraform apply
```

## Symptom (failure)

Run the same curl test.

Expected:
```
curl: (28) Operation timed out after 5003 milliseconds with 0 bytes received
CURL_FAILED
```

## Fix (Terraform)

Restore the ingress rule and apply again:

```bash
cd infra/terraform
terraform apply
```

## Verify recovery

Run the curl test again.

Expected:
```
db_ok
```

## What this scenario proves

* Pods can stay Running and `/health` can still be OK while the system is broken
* Network-layer issues (SG rules) cause timeouts, not clean errors
* Terraform is part of incident recovery (infra change → service recovery)
