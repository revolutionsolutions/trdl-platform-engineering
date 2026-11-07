# TRDL -- Architecture Decisions

This document captures the main choices I plan to make for the TRDL PoC.
The goal is not to design a complete production platform. I want to keep
the solution simple, explain the trade-offs and make it easy for another
engineer to follow.

## 1. AWS and Amazon EKS

**Decision:** Use AWS and Amazon EKS.

I chose AWS because the Sinch team has said that it mainly works with
AWS. EKS also gives me a chance to demonstrate Kubernetes in an AWS
environment, including its integration with IAM, VPC networking and ECR.

The downside is cost. EKS has a control-plane charge, and the worker
nodes and supporting resources cost extra. I will keep the cluster small
and make sure the cleanup instructions are clear.

## 2. A small stateless application

**Decision:** Use a small Python HTTP application.

The service only needs to return `42`, so I do not see a reason to add a
database or other backend service. I will keep the code easy to read and
add a couple of health endpoints for Kubernetes.

This keeps the focus on the platform and deployment rather than
application complexity.

## 3. Docker and Amazon ECR

**Decision:** Package the application with Docker and store the image in
Amazon ECR.

The same image can be used locally and in EKS. I will run the
application as a non-root user and use a version tag based on the Git
commit SHA.

I prefer this to using `latest`, because it makes it clearer which
version is deployed and makes rollbacks easier to understand.

## 4. Terraform for infrastructure

**Decision:** Use Terraform for the AWS resources.

Terraform will manage the network, EKS cluster, worker nodes, IAM
resources and ECR repository.

This keeps infrastructure changes in code and makes them easier to
review and repeat. I will avoid creating lots of small modules just for
the sake of it; the configuration should be understandable for a project
of this size.

Terraform state needs to be protected and should not be committed to
Git. I will document the state setup and any bootstrap steps needed
before running the main configuration.

## 5. Kubernetes deployment and service access

**Decision:** Use a Kubernetes Deployment with three replicas and a
Service of type `LoadBalancer`.

The AWS integration will create a Network Load Balancer for external
access.

The Deployment will include readiness and liveness probes, resource
requests and limits, and pod distribution rules. I will also add a
PodDisruptionBudget to help with planned maintenance.

These settings improve resilience, but they do not guarantee a
particular uptime target. A node or Availability Zone failure can still
affect the service, especially with a small cluster.

## 6. GitHub Actions and AWS authentication

**Decision:** Use GitHub Actions for testing, image publishing and
deployment. Use AWS OIDC for authentication.

The pull-request workflow will run tests and validate the Docker,
Terraform and Kubernetes configuration. The deployment workflow will
build an image, push it to ECR and update the EKS Deployment.

I do not want to store permanent AWS access keys in GitHub. The OIDC
role will be limited to the repository and the branch or environment
that is allowed to deploy.

For a real production setup, I would also expect protected environments
and approval rules before deployment.

## 7. Keep monitoring simple for the PoC

**Decision:** Use application health endpoints, Kubernetes probes, logs
and a deployment smoke test.

A full monitoring stack would be more work than this application needs.
The PoC should show that the service starts, becomes ready and responds
correctly.

For production, I would add service-level dashboards, alerting,
centralised logs and a clear on-call process. I would also agree how
availability is measured before discussing an SLA.

## 8. Be clear about the availability claim

**Decision:** Do not claim that this PoC achieves several nines of
availability.

Three replicas and multiple Availability Zones are useful design
choices, but they are not proof of long-term uptime. Availability also
depends on the load balancer, cluster capacity, AWS services, deployment
process, monitoring and the team's response to incidents.

For production, I would first agree on the SLI, SLO and SLA, then test
the failure scenarios and collect evidence over time.

## 9. Cost and cleanup

**Decision:** Keep the AWS environment small and remove it when the
exercise is finished.

I will check the current regional pricing before deployment. EKS, EC2,
the load balancer, NAT gateway, storage and public IP addresses can all
add cost.

I would prefer private worker nodes, but a NAT gateway can be a
noticeable cost for a short-lived PoC. I will make the final choice
based on the budget and document any compromise. The deployment guide
will include the steps to destroy the environment and remove any
remaining resources.

------------------------------------------------------------------------

## Summary

The choices are AWS, EKS, Python, Docker, ECR, Terraform and GitHub
Actions. They are enough to demonstrate the main parts of a small
platform delivery workflow without adding tools that do not solve a real
problem in this exercise.

The most important point is to keep the PoC repeatable and
understandable, and to be clear about the extra work needed before it
could become a production service.
