# TRDL -- Architecture Decisions

This document captures the main architecture decisions made during the TRDL PoC.

The goal was not to design a complete production platform. I wanted to keep the solution simple, explain the trade-offs and make it easy for another engineer to follow.

## 1. AWS and Amazon EKS

**Decision:** Use AWS and Amazon EKS.

I chose AWS because the Sinch team has said that it mainly works with AWS. EKS also gives me a chance to demonstrate Kubernetes in an AWS environment, including its integration with IAM, VPC networking and ECR.

The cluster uses a managed node group with two worker nodes across two Availability Zones. This provides a basic level of infrastructure separation, although it does not guarantee high availability.

The downside is cost. EKS has a control-plane charge, and the worker nodes and supporting resources cost extra. I kept the cluster small and documented the infrastructure setup and cleanup considerations.

## 2. A small stateless application

**Decision:** Use a small Python HTTP application.

The service only needs to return `42`, so I did not see a reason to add a database or other backend service. I kept the code easy to read and added health endpoints for Kubernetes.

The application exposes:

- `GET /` – returns `42`.
- `GET /health/live` – checks whether the application is alive.
- `GET /health/ready` – checks whether the application is ready to receive traffic.

This keeps the focus on the platform and deployment rather than application complexity.

## 3. Docker and Amazon ECR

**Decision:** Package the application with Docker and store the image in Amazon ECR.

The same image can be used locally and in EKS. The application runs as a non-root user, and the image uses a version tag based on the Git commit SHA.

I prefer this to using `latest`, because it makes it clearer which version is deployed and makes rollbacks easier to understand.

I also added Trivy to scan the container image for HIGH and CRITICAL vulnerabilities before it is pushed to ECR.

During local testing, the scan identified two HIGH vulnerabilities in the Debian `zlib1g` package. I updated the Dockerfile to apply available OS package updates during the image build. A subsequent scan reported no HIGH or CRITICAL vulnerabilities.

The scan is part of the application CI workflow, so an image with matching vulnerabilities will fail the pipeline rather than being pushed to ECR.

## 4. Terraform for infrastructure

**Decision:** Use Terraform for the AWS resources.

Terraform manages the network, EKS cluster, worker nodes, IAM resources and ECR repository.

This keeps infrastructure changes in code and makes them easier to review and repeat. I avoided creating lots of small modules just for the sake of it; the configuration should be understandable for a project of this size.

Terraform state is stored remotely in Amazon S3. The state bucket has versioning enabled, and Terraform uses native S3 state locking.

The bucket is created through a separate bootstrap configuration, while the main Terraform configuration uses it as its backend. State files and local Terraform files are not committed to Git.

The Terraform GitHub Actions workflow validates the configuration and runs a plan. It does not automatically apply infrastructure changes.

## 5. Kubernetes deployment and service access

**Decision:** Use a Kubernetes Deployment with three replicas and a Service of type `ClusterIP`.

I initially considered using a `LoadBalancer` Service with a Network Load Balancer for external access. I kept the final implementation simpler and used `ClusterIP` instead.

The application was deployed and tested