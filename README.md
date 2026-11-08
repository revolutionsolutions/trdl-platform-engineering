# TRDL — The Responding Dark Laughter

A proof-of-concept deployment of TRDL, a simple HTTP service that returns `42`, running on AWS EKS.

## 1. Overview

The objective of this project is to demonstrate how a small HTTP application can be containerised, deployed and operated on a Kubernetes platform in a public cloud environment.

The application provides:

| Endpoint | Description | Response |
|---|---|---|
| `GET /` | Main application endpoint | `42` |
| `GET /health/live` | Liveness check | `{"status":"alive"}` |
| `GET /health/ready` | Readiness check | `{"status":"ready"}` |

This is a proof of concept, not a production deployment. The architecture demonstrates availability and operational practices but does not claim to meet a several-nines SLA.

## 2. Architecture

The solution uses the following AWS services and technologies:

- **Amazon EKS:** Kubernetes container orchestration.
- **Amazon ECR:** Container image registry.
- **Amazon VPC:** Network isolation across two Availability Zones.
- **EC2 managed node group:** Kubernetes worker nodes.
- **Amazon S3:** Remote Terraform state storage.
- **Terraform:** Infrastructure as Code.
- **Docker:** Application containerisation.
- **GitHub Actions:** Automated testing, building, deployment and Terraform validation.
- **GitHub OIDC:** Short-lived AWS credentials without storing static AWS access keys.
- **Kubernetes RBAC:** Namespace-scoped deployment permissions.

### Deployment flow

1. A developer pushes application changes to the `main` branch.
2. GitHub Actions runs the Python tests.
3. Docker builds the application image.
4. GitHub Actions authenticates to AWS through OIDC.
5. The image is pushed to Amazon ECR using the Git commit SHA as its tag.
6. GitHub Actions connects to EKS and updates the Kubernetes Deployment.
7. Kubernetes performs a rolling update.
8. The pipeline verifies the rollout and application readiness endpoint.

Terraform infrastructure changes follow a separate workflow, which validates pull requests and generates a plan for pushes to `main`.

## 3. Repository structure

```text
trdl/
├── app/
│   ├── main.py
│   ├── requirements.txt
│   └── tests/
│       └── test_main.py
├── docker/
│   └── Dockerfile
├── infrastructure/
│   ├── terraform/
│   │   ├── backend.tf
│   │   └── *.tf
│   └── terraform-bootstrap/
│       └── main.tf
├── kubernetes/
│   ├── trdl.yaml
│   └── github-actions-rbac.yaml
├── .github/
│   └── workflows/
│       ├── app-ci-cd.yml
│       └── terraform-ci.yml
├── docs/
├── DISCOVERY.md
├── ARCHITECTURE_DECISIONS.md
└── README.md
```

## 4. Prerequisites

Install the following tools:

- AWS CLI
- Terraform
- kubectl
- Docker
- Python 3.12 or later
- Git

You also need an AWS account with sufficient permissions to provision the required infrastructure.

Configure an AWS CLI profile and verify the active account before running Terraform:

```bash
aws sts get-caller-identity --profile <profile-name>
```

Select your AWS profile:

```bash
export AWS_PROFILE=<profile-name>
export AWS_REGION=us-east-1
```

On Windows Git Bash, these environment variables apply to the current shell session.

## 5. Run locally

Create and activate a Python virtual environment:

```bash
python -m venv .venv
source .venv/Scripts/activate
```

Install dependencies:

```bash
pip install -r app/requirements.txt
pip install pytest
```

Run the tests:

```bash
python -m pytest -v app/tests/
```

Start the application:

```bash
uvicorn app.main:app --host 0.0.0.0 --port 8080
```

Test the endpoints:

```bash
curl http://localhost:8080/
curl http://localhost:8080/health/live
curl http://localhost:8080/health/ready
```

## 6. Build and run with Docker

Build the image:

```bash
docker build -t trdl:local -f docker/Dockerfile .
```

Run the container:

```bash
docker run --rm -p 8080:8080 trdl:local
```

Test:

```bash
curl http://localhost:8080/
```

Expected response:

```text
42
```

## 7. Provision AWS infrastructure

The Terraform configuration is located in:

```text
infrastructure/
├── terraform-bootstrap/
└── terraform/
```

### 7.1 Bootstrap the Terraform state bucket

The bootstrap configuration creates the S3 bucket used to store the main Terraform state.

Run this step once:

```bash
cd infrastructure/terraform-bootstrap
terraform init
terraform fmt -check
terraform validate
terraform plan
terraform apply
```

The state bucket has versioning enabled and is configured for server-side encryption and public access blocking.

The bootstrap configuration maintains its own local Terraform state. Keep that state secure and do not commit it to Git.

### 7.2 Initialise the main Terraform configuration

The main infrastructure configuration uses an S3 backend with native state locking.

```bash
cd ../terraform
terraform init
```

If migrating from an existing local Terraform state, use:

```bash
terraform init -migrate-state
```

Validate the configuration:

```bash
terraform fmt -check -recursive
terraform validate
```

Review the proposed infrastructure changes:

```bash
terraform plan
```

Apply the infrastructure when the plan has been reviewed:

```bash
terraform apply
```

Review Terraform outputs for the ECR repository URL and other infrastructure details.

The main Terraform state is stored in S3 rather than committed to the repository. State access is restricted through AWS IAM permissions.

## 8. Deploy to Kubernetes

Configure kubectl:

```bash
aws eks update-kubeconfig \
  --name trdl-eks \
  --region us-east-1
```

Apply the Kubernetes manifests:

```bash
kubectl apply -f kubernetes/trdl.yaml
kubectl apply -f kubernetes/github-actions-rbac.yaml
```

Check the deployment:

```bash
kubectl get deployments -n trdl
kubectl get pods -n trdl
kubectl get services -n trdl
```

Wait for the rollout:

```bash
kubectl rollout status deployment/trdl -n trdl
```

The service is configured as a ClusterIP service, so it is not directly accessible from the public internet.

For local testing, use port forwarding:

```bash
kubectl port-forward -n trdl svc/trdl 8080:80
```

Then:

```bash
curl http://localhost:8080/
```

Expected response:

```text
42
```

## 9. CI/CD configuration

Two GitHub Actions workflows are used.

### Application CI/CD

The application pipeline is defined in:

```text
.github/workflows/app-ci-cd.yml
```

The workflow runs the following steps:

- Runs Python unit tests.
- Validates Kubernetes manifests using Kubeconform.
- Builds the Docker image.
- Scans the image for HIGH and CRITICAL vulnerabilities using Trivy.
- Pushes the image to Amazon ECR.
- Deploys the updated image to EKS.
- Verifies the deployment rollout and application health.

Pull requests run the tests, manifest validation, image build and vulnerability scan. Deployment runs only after successful checks on a push to `main`.

AWS authentication uses GitHub OIDC. The IAM role trust policy is restricted to the repository and the `main` branch. Kubernetes RBAC grants deployment permissions within the `trdl` namespace.

No static AWS access keys are stored in GitHub.

The deployment uses the Git commit SHA as the image tag, allowing deployed versions to be traced back to source code.

### Terraform CI

The infrastructure pipeline is defined in:

```text
.github/workflows/terraform-ci.yml
```

It performs the following checks:

- Terraform formatting and validation run on pull requests and pushes to `main`.
- Terraform planning runs on pushes to `main`.
- AWS authentication uses GitHub OIDC.
- The workflow accesses the existing S3 remote state.

The workflow does not automatically apply infrastructure changes. Terraform apply remains a manual operation.

## 10. Availability and resilience

The PoC includes several availability-oriented choices:

- Three application replicas.
- Kubernetes readiness and liveness probes.
- Rolling updates with `maxUnavailable: 0`.
- Worker nodes deployed across two Availability Zones.
- Private worker-node subnets.
- A ClusterIP service for internal application access.

These choices improve resilience, but they do not establish a several-nines SLA.

The current design also uses a single NAT Gateway, which is a potential availability limitation. The PoC does not include production-grade external load balancing, disaster recovery or a multi-region strategy.

## 11. Production considerations

Before using this architecture in production, further work would be required, including:

- Multi-AZ network egress and resilience improvements.
- External load balancing and TLS termination.
- Centralised logs, metrics, tracing and alerting.
- Service-level indicators and objectives.
- Backup and disaster-recovery procedures.
- Security scanning and image vulnerability management.
- Controlled infrastructure and application upgrades.
- Capacity planning and load testing.
- Operational incident response procedures.

These are intentionally outside the implementation scope of this PoC.

## 12. Further documentation

- [Discovery and effort estimation](DISCOVERY.md)
- [Architecture decisions](ARCHITECTURE_DECISIONS.md)