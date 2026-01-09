# Kubernetes Resilience Lab (EKS)

This repository demonstrates **real failure scenarios in Kubernetes** using a production-like setup on AWS EKS.

The focus is **not** on deploying applications, but on **understanding how systems fail**, how Kubernetes behaves during failures, and how to diagnose and recover.

This mirrors real on-call and incident-response work.

---

## Stack

- **Kubernetes**: Amazon EKS
- **Infrastructure**: Terraform
- **Database**: Amazon RDS (Postgres)
- **Application**: Simple Node.js API
- **Networking**: Services, Readiness/Liveness probes, Gateway API (ALB)
- **Cloud**: AWS (VPC, Security Groups, IAM, ALB)

---

## Repository Structure

```text
.
├── app/                         
│   ├── Dockerfile              
│   ├── package.json             
│   └── server.js        
├── docs/                    
├── infra/
│   └── terraform/               
│       ├── iam_policy.json     
│       ├── main.tf             
│       ├── outputs.tf       
│       ├── rds.tf              
│       
├── k8s/
│   ├── api/                    
│   │   ├── deployment.yaml      
│   │   ├── namespace.yaml   
│   │   └── service.yaml         
│   └── gateway/               
│       ├── gateway.yaml        
│       ├── gatewayclass.yaml   
│       └── httproute.yaml       
├── scenarios/                  
│   ├── 01-db-connectivity.md
│   ├── 02-db-blocked-by-sg.md
│   ├── 03-db-wrong-password.md
│   ├── 04-readiness-blackhole.md
│   ├── 05-gateway-routing-misconfig.md
│   ├── 06-crashloopbackoff-application-exit.md
│   ├── 07-routing-correct-but-readiness-broken.md
│   ├── 08-node-disruption-and-capacity-loss.md
│   └── 09-dns-failure-symptoms.md
└── README.md                  
```

---

## Scenarios (Core of the Lab)

Each scenario:
- starts from a **working baseline**
- introduces **one controlled failure**
- shows the **observable symptoms**
- explains the **root cause**
- restores the system

### Implemented Scenarios

| # | Scenario | What it demonstrates |
|---|--------|----------------------|
| 01 | DB connectivity | Pod → RDS connectivity works |
| 02 | DB blocked by SG | Network-level timeout with pods still Running |
| 03 | Wrong DB password | Auth failure vs network failure |
| 04 | Readiness blackhole | Pods Running but Service has **0 endpoints** |
| 05 | Gateway misrouting | ALB/Gateway exists but traffic is misrouted |
| 06 | CrashLoopBackOff | App exits → restart behavior |
| 07 | Readiness fixed | Recovery after readiness misconfig |
| 08 | Node disruption | Pod rescheduling after node loss |
| 09 | DNS failure | Service name resolution errors |

> Scenarios are intentionally isolated. Each one demonstrates **one failure mode only**.

---

## Key Lessons Demonstrated

- **Running ≠ Ready**  
  Pods can be healthy but still receive zero traffic.

- **Timeout vs Auth error**  
  Network failures and credential failures look very different.

- **Infrastructure bugs look like app bugs**  
  Security Groups, routes, and gateways can break systems without crashing pods.

- **Routing layers matter**  
  Gateway / HTTPRoute misconfigurations can silently blackhole traffic.

- **Kubernetes recovery mechanisms**  
  Restarts, rescheduling, readiness, and endpoint updates.

---

## Why this project exists

Most Kubernetes examples focus on happy paths.

This project focuses on:
- realistic failure modes
- observable symptoms
- root-cause analysis
- recovery steps

The goal is to understand how Kubernetes and infrastructure behave under failure,
not to build a production application.

---

## How to use this repo

Scenarios are independent and can be reviewed individually.

Each scenario documents:
- the initial working state
- the change that introduced the failure
- observed symptoms
- root cause
- recovery steps

Readers can focus on a subset of scenarios to understand specific failure modes.

---

## Notes

- The setup intentionally avoids over-engineering.
- Failures are introduced explicitly to keep cause → effect clear.
- The focus is on Kubernetes and infrastructure behavior, not application logic.

