# TRDL -- Discovery and Initial Plan

**Purpose:** Platform Engineering qualification assignment  
**Cloud:** AWS  
**Container platform:** Amazon EKS  
**Infrastructure as Code:** Terraform  
**CI/CD:** GitHub Actions

## 1. What I understand from the assignment

TRDL is a small web service. When someone sends a `GET` request to it, it should return `42`.

The application itself is not complicated. The interesting part of this exercise is how to package it, deploy it to Kubernetes, make the deployment repeatable, and show that the service can recover from some common failures.

This is a proof of concept, not a production service. I will keep the solution reasonably small and explain what would need to change before using it for a real service with a strict availability target.

## 2. What I plan to build

My plan is to use AWS EKS because the role is mainly AWS-focused and Kubernetes is an important part of the work.

The application will be a small Python HTTP service. I will package it as a Docker image and store the image in Amazon ECR. Terraform will create the AWS infrastructure, and GitHub Actions will run tests, build the image and deploy it to EKS.

At a high level, the initial design considered this request path:

```text
Client / curl
    |
AWS Network Load Balancer
    |
Kubernetes Service
    |
TRDL pods
    |
HTTP 200 – 42
```

I will start with three application replicas. Where the budget and AWS region allow it, the worker nodes will be spread across two Availability Zones. The Kubernetes configuration will also include health checks and resource requests and limits.

**Implementation outcome:** I kept the Kubernetes Service as `ClusterIP` instead of adding a Network Load Balancer. This was a scope decision for the PoC. The application was deployed and tested through Kubernetes port forwarding rather than a public endpoint. The EKS worker nodes were provisioned across two Availability Zones.

## 3. Assumptions

There are a few things the assignment does not specify, so I will make the following assumptions for the PoC:

- AWS is the cloud provider.
- The initial design considers HTTP access through a load balancer. A custom domain and TLS certificate are outside the scope of this exercise.
- The application does not need a database, persistent storage or any other external service.
- Three replicas are enough to demonstrate basic workload resilience.
- GitHub is where the source code will live.
- GitHub Actions will use AWS OIDC to access AWS, rather than storing permanent AWS access keys.
- The AWS region, node size and other environment-specific values will be configurable in Terraform.

I will check current AWS pricing before creating resources. EKS, EC2, load balancers, NAT gateways and public IP addresses can all cost money. I will keep the environment small and include instructions for removing it when testing is finished.

For networking, I would prefer private worker nodes. A NAT gateway adds cost, though, so I will check whether that is reasonable for this short-lived PoC. If I use a cheaper setup, I will document the security trade-off rather than presenting it as a production design.

**Implementation outcome:** The final network uses public and private subnets across two Availability Zones. The EKS worker nodes run in private subnets. A single NAT Gateway provides outbound internet access for the private network. This is a cost-conscious choice, but it introduces a potential availability limitation because the NAT Gateway is deployed in one Availability Zone.

## 4. Main components and why I chose them

| Component | Plan |
|---|---|
| AWS | Cloud platform for the exercise and relevant to the role. |
| Amazon EKS | Managed Kubernetes service. |
| Python | Keep the application small and easy to understand. |
| Docker | Package the application in a repeatable way. |
| Amazon ECR | Store the container image in AWS. |
| Terraform | Create and manage the AWS infrastructure as code. |
| GitHub Actions | Run tests and automate image build and deployment. |
| AWS Network Load Balancer | Considered initially for external service access, but not included in the final PoC. |
| Kubeconform | Validate Kubernetes manifests against Kubernetes schemas. |
| Trivy | Scan container images for known vulnerabilities. |
| Amazon S3 | Store Terraform remote state with versioning and native state locking. |

I am not planning to add a service mesh, database, message broker or a large monitoring stack. They would add complexity without helping much with this particular application.

## 5. Reliability considerations

The assignment mentions a strict availability target, but a short PoC cannot prove that the service will achieve several nines of uptime. It can show some of the design choices that would help.

For this version I plan to include:

- Three application replicas.
- Readiness and liveness probes.
- Resource requests and limits.
- Worker nodes across two Availability Zones.
- A deployment check and a simple HTTP smoke test after deployment.

These measures help with some failures, but they do not cover everything. For example, a PodDisruptionBudget does not protect against an unexpected node or Availability Zone failure. A single-region PoC also has regional failure risks.

**Implementation outcome:** The final Kubernetes deployment includes three application replicas, readiness and liveness probes, and resource requests and limits. The EKS managed node group spans two Availability Zones.

A PodDisruptionBudget and explicit graceful shutdown handling were not included in this version. Pod-level topology spread constraints were also not added. These remain possible improvements for a production deployment.

Before making any availability promise in production, I would want the team to agree on what is measured, the target, the measurement period, and who is responsible for responding to incidents.

## 6. Build, test and deployment plan

The application and infrastructure use separate GitHub Actions workflows.

### Application workflow

The application workflow is defined in:

```text
.github/workflows/app-ci-cd.yml
```

For pull requests and pushes to `main`, the workflow runs the following checks:

1. Install the application dependencies.
2. Run the Python unit tests.
3. Validate all Kubernetes YAML manifests using Kubeconform.
4. Build the Docker image.
5. Scan the image using Trivy for HIGH and CRITICAL vulnerabilities.

For a push to `main`, after the checks pass, the workflow continues with:

1. Authenticate to AWS using GitHub OIDC.
2. Push the scanned image to Amazon ECR.
3. Update the Kubernetes Deployment with the new image.
4. Wait for the deployment rollout to finish.
5. Check the application health endpoint.

The deployment uses the Git commit SHA as the image tag, making it easier to identify which source revision is running. I avoid using `latest` as the deployment version.

### Terraform workflow

The Terraform workflow is defined in:

```text
.github/workflows/terraform-ci.yml
```

The workflow validates the Terraform configuration and runs a Terraform plan on pushes to `main`. Validation also runs for pull requests.

Terraform state is stored remotely in Amazon S3. The state bucket has versioning enabled, and Terraform uses native S3 state locking.

The workflow does not automatically apply infrastructure changes. This keeps infrastructure changes separate from application deployment.

## 7. Testing

I plan to cover a few simple cases:

- `GET /` returns HTTP 200 and the body `42`.
- The health endpoints return the expected status.
- An unknown path returns HTTP 404.
- The container starts using the documented configuration.
- Kubernetes manifests pass schema validation.
- The Docker image is scanned for known vulnerabilities.
- After deployment, the application responds successfully through Kubernetes port forwarding.

The tests should be useful without requiring an AWS account. The application and container should be possible to run locally.

**Implementation outcome:** The Python unit tests pass, the Kubernetes manifests have been validated with Kubeconform, and the Docker image passed the local Trivy scan with no HIGH or CRITICAL vulnerabilities at the time of testing.

The application was deployed to EKS and tested through port forwarding. The main endpoint returned `42`, and both health endpoints returned their expected responses.

## 8. Work estimate

The estimates are approximate. AWS account setup and EKS provisioning may take longer than expected, so I have kept some time for review and troubleshooting.

| Task | Estimate |
|---|---:|
| Read the requirements and decide on the design | 45 min |
| Build the HTTP service and unit tests | 45 min |
| Create the Docker image and test it locally | 30 min |
| Write and validate Kubernetes manifests | 1 hr |
| Create AWS infrastructure with Terraform | 2 hr |
| Set up the CI workflow | 45 min |
| Add image publishing and deployment workflow | 1 hr |
| Deploy to EKS and test the endpoint | 1 hr |
| Review reliability and security basics | 45 min |
| Finish the documentation and repository review | 1 hr |
| **Initial estimate** | **9 hr 30 min** |

This was the initial estimate before implementation. Additional work was needed during the assessment for troubleshooting, Terraform remote state, IAM permissions, container vulnerability scanning and Kubernetes manifest validation.

If something takes longer, I will focus on getting the application, container, Kubernetes configuration and deployment instructions into a good state before adding optional features.

## 9. Things to be careful about

A few things could take more time or need a decision:

- **AWS cost:** EKS and supporting resources are not free. I will check the expected cost and remove the resources after the exercise.
- **Networking:** The cheaper networking option may not be suitable for production. I will document what I choose.
- **Availability:** Three pods do not automatically mean high availability. Node placement and failure scenarios matter too.
- **Credentials:** No AWS keys or other secrets should be committed to Git.
- **Terraform state:** State can contain sensitive information, so it should not be stored in the repository.
- **Image versions:** Deploy a specific image tag, not a moving `latest` tag.
- **Container vulnerabilities:** Base images and application dependencies can contain known vulnerabilities. Scanning should be part of the build process.
- **Kubernetes manifests:** YAML syntax alone does not guarantee that a manifest is valid for the target Kubernetes API version. Schema validation helps catch unsupported or incorrect fields.

## 10. When I would consider it ready

I would consider the PoC complete when:

- The application unit tests pass.
- The Docker image builds successfully.
- Trivy reports no HIGH or CRITICAL vulnerabilities in the image at the time of scanning.
- Terraform can validate and produce a plan.
- The Kubernetes manifests pass Kubeconform validation.
- The service can be deployed to EKS.
- The main endpoint returns `42` through Kubernetes port forwarding.
- The health endpoints return their expected responses.
- GitHub Actions runs the application checks and can deploy the image from `main`.
- Terraform CI validates and plans infrastructure changes.
- The README explains how to set up, test and understand the project.

## 11. What I would add before production

The PoC is only a starting point. Before using this as a production service, I would want to work through:

- An agreed availability target and clear service-level indicators.
- More complete monitoring, alerting, logs and operational dashboards.
- TLS, DNS and appropriate edge protection.
- Capacity and load testing.
- Failure testing across nodes and Availability Zones.
- A deployment and rollback approach agreed by the team.
- A PodDisruptionBudget and explicit graceful shutdown handling.
- Pod topology spread constraints where appropriate.
- A more complete security review, vulnerability management process and access policies.
- Documented incident response and recovery procedures.
- Cost monitoring and ownership.
- A more resilient network design, including reviewing the single NAT Gateway dependency.

The main aim is to show a working, repeatable deployment and to be honest about what it does and does not prove.