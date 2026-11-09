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

The application was deployed and tested through Kubernetes port forwarding rather than a public endpoint. This was a scope decision for the PoC.

The Deployment includes:

- Three application replicas.
- Readiness and liveness probes.
- Resource requests and limits.
- A rolling update strategy with `maxSurge: 1` and `maxUnavailable: 0`.

The EKS worker nodes are deployed across two Availability Zones.

A PodDisruptionBudget and explicit pod topology spread constraints were not included in this version. These would be useful improvements to consider for a production deployment.

These settings provide a reasonable starting point for resilience, but they do not guarantee a particular uptime target. A node or Availability Zone failure can still affect the service.

## 6. GitHub Actions and AWS authentication

**Decision:** Use GitHub Actions for testing, image publishing and deployment. Use AWS OIDC for authentication.

The application workflow runs the following checks:

- Python unit tests.
- Kubernetes manifest validation using Kubeconform.
- Docker image build.
- Trivy vulnerability scanning for HIGH and CRITICAL vulnerabilities.

These checks run for pull requests and pushes to `main`.

For a push to `main`, after successful checks, the workflow authenticates to AWS, pushes the image to ECR and updates the EKS Deployment. It then verifies the deployment rollout and application health.

Kubeconform validates all YAML manifests in the Kubernetes directory against the Kubernetes 1.35 schemas. This helps catch unsupported or incorrect fields before deployment.

I do not store permanent AWS access keys in GitHub. The OIDC role trust policy is restricted to the repository and the `main` branch. Kubernetes RBAC grants deployment permissions within the `trdl` namespace.

The Terraform workflow is separate from the application workflow. It validates Terraform configuration and runs a plan, but does not automatically apply changes.

For a real production setup, I would also expect protected environments and approval rules before deployment.

## 7. Keep monitoring simple for the PoC

**Decision:** Use application health endpoints, Kubernetes probes, logs and a deployment smoke test.

A full monitoring stack would be more work than this application needs. The PoC should show that the service starts, becomes ready and responds correctly.

The deployment workflow checks the rollout status and calls the readiness endpoint after deployment. This gives a basic confirmation that the application is running.

For production, I would add service-level dashboards, alerting, centralised logs and a clear on-call process. I would also agree how availability is measured before discussing an SLA.

## 8. Be clear about the availability claim

**Decision:** Do not claim that this PoC achieves several nines of availability.

Three replicas and multiple Availability Zones are useful design choices, but they are not proof of long-term uptime.

Availability also depends on cluster capacity, network design, AWS services, deployment process, monitoring and the team's response to incidents.

The final network uses public and private subnets across two Availability Zones. Worker nodes run in private subnets, with a single NAT Gateway providing outbound internet access.

The single NAT Gateway is a cost-conscious choice, but it introduces a potential availability limitation. It is not equivalent to a highly available multi-AZ NAT design.

For production, I would first agree on the SLI, SLO and SLA, then test the failure scenarios and collect evidence over time.

## 9. Cost

**Decision:** Keep the AWS environment small.

EKS, EC2, NAT Gateway, storage and public IP addresses can all add cost.

I used two public and two private subnets across two Availability Zones. The worker nodes run in private subnets, and a single NAT Gateway provides outbound internet access.

Using one NAT Gateway keeps the PoC cost lower than deploying one per Availability Zone, but it introduces a potential availability limitation. A production environment with stricter availability requirements would need a different approach.

------------------------------------------------------------------------

## Summary

The final solution uses AWS, EKS, Python, Docker, ECR, Terraform and GitHub Actions.

It also includes Trivy for container vulnerability scanning, Kubeconform for Kubernetes manifest validation, S3 for Terraform remote state and GitHub OIDC for AWS authentication.

The main focus was to deliver a working and repeatable deployment without adding tools that do not solve a real problem in this exercise.

The PoC demonstrates the main parts of a small platform delivery workflow, but it is not a production-ready service. The remaining improvements, particularly around availability, monitoring, network resilience and operational controls, would need to be considered before using it for a real production workload.