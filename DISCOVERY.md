# TRDL -- Discovery and Initial Plan

**Purpose:** Platform Engineering qualification assignment\
**Cloud:** AWS\
**Container platform:** Amazon EKS\
**Infrastructure as Code:** Terraform\
**CI/CD:** GitHub Actions

## 1. What I understand from the assignment

TRDL is a very small web service. When someone sends a `GET` request to
it, it should return `42`.

The application itself is not complicated. The interesting part of this
exercise is how to package it, deploy it to Kubernetes, make the
deployment repeatable, and show that the service can recover from some
common failures.

This is a proof of concept, not a production service. I will keep the
solution reasonably small and explain what would need to change before
using it for a real service with a strict availability target.

## 2. What I plan to build

My plan is to use AWS EKS because the role is mainly AWS-focused and
Kubernetes is an important part of the work.

The application will be a small Python HTTP service. I will package it
as a Docker image and store the image in Amazon ECR. Terraform will
create the AWS infrastructure, and GitHub Actions will run tests, build
the image and deploy it to EKS.

At a high level, a request will follow this path:

``` text
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

I will start with three application replicas. Where the budget and AWS
region allow it, the worker nodes will be spread across two Availability
Zones. The Kubernetes configuration will also include health checks and
resource requests and limits.

## 3. Assumptions

There are a few things the assignment does not specify, so I will make
the following assumptions for the PoC:

-   AWS is the cloud provider.
-   The service will be reachable over HTTP using the load balancer
    address. I will not set up a custom domain or TLS certificate for
    this exercise.
-   The application does not need a database, persistent storage or any
    other external service.
-   Three replicas are enough to demonstrate basic workload resilience.
-   GitHub is where the source code will live.
-   GitHub Actions will use AWS OIDC to access AWS, rather than storing
    permanent AWS access keys.
-   The AWS region, node size and other environment-specific values will
    be configurable in Terraform.

I will check current AWS pricing before creating resources. EKS, EC2,
load balancers, NAT gateways and public IP addresses can all cost money.
I will keep the environment small and include instructions for removing
it when testing is finished.

For networking, I would prefer private worker nodes. A NAT gateway adds
cost, though, so I will check whether that is reasonable for this
short-lived PoC. If I use a cheaper setup, I will document the security
trade-off rather than presenting it as a production design.

## 4. Main components and why I chose them

  -----------------------------------------------------------------------
  Component                           Plan
  ----------------------------------- -----------------------------------
  AWS                                 Cloud platform for the exercise and
                                      relevant to the role.

  Amazon EKS                          Managed Kubernetes service.

  Python                              Keep the application small and easy
                                      to understand.

  Docker                              Package the application in a
                                      repeatable way.

  Amazon ECR                          Store the container image in AWS.

  Terraform                           Create and manage the AWS
                                      infrastructure as code.

  GitHub Actions                      Run tests and automate image build
                                      and deployment.

  AWS Network Load Balancer           Provide an external address for the
                                      service.
  -----------------------------------------------------------------------

I am not planning to add a service mesh, database, message broker or a
large monitoring stack. They would add complexity without helping much
with this particular application.

## 5. Reliability considerations

The assignment mentions a strict availability target, but a short PoC
cannot prove that the service will achieve several nines of uptime. It
can show some of the design choices that would help.

For this version I plan to include:

-   Three application replicas.
-   Readiness and liveness probes.
-   Resource requests and limits.
-   Pod distribution across nodes and, where possible, Availability
    Zones.
-   A PodDisruptionBudget for voluntary disruptions.
-   Graceful shutdown.
-   A deployment check and a simple HTTP smoke test after deployment.

These measures help with some failures, but they do not cover
everything. For example, a PodDisruptionBudget does not protect against
an unexpected node or Availability Zone failure. A single-region PoC
also has regional failure risks.

Before making any availability promise in production, I would want the
team to agree on what is measured, the target, the measurement period,
and who is responsible for responding to incidents.

## 6. Build, test and deployment plan

For a pull request, GitHub Actions should:

1.  Install the application dependencies.
2.  Run the unit tests.
3.  Check the Terraform configuration.
4.  Validate the Kubernetes manifests.
5.  Build the Docker image.
6.  Run a container scan if time allows.

For deployment from the main branch (or a manual workflow), the pipeline
should:

1.  Build the image and tag it with the Git commit SHA.
2.  Authenticate to AWS using GitHub OIDC.
3.  Push the image to ECR.
4.  Update the Kubernetes Deployment.
5.  Wait for the rollout to finish.
6.  Send a request to the service and check that it returns `42`.

Using the commit SHA as the image tag makes it easier to see which
source revision is running. I will avoid using `latest` as the
deployment version.

## 7. Testing

I plan to cover a few simple cases:

-   `GET /` returns HTTP 200 and the body `42`.
-   The health endpoints return the expected status.
-   An unknown path returns HTTP 404.
-   The container starts using the documented configuration.
-   After deployment, an external request to the load balancer returns
    `42`.

The tests should be useful without requiring an AWS account. The
application and container should be possible to run locally.

## 8. Work estimate

The estimates are approximate. AWS account setup and EKS provisioning
may take longer than expected, so I have kept some time for review and
troubleshooting.

  Task                                                      Estimate
  ------------------------------------------------ -----------------
  Read the requirements and decide on the design              45 min
  Build the HTTP service and unit tests                       45 min
  Create the Docker image and test it locally                 30 min
  Write and validate Kubernetes manifests                       1 hr
  Create AWS infrastructure with Terraform                      2 hr
  Set up the CI workflow                                      45 min
  Add image publishing and deployment workflow                  1 hr
  Deploy to EKS and test the endpoint                           1 hr
  Review reliability and security basics                      45 min
  Finish the documentation and repository review                1 hr
  **Total**                                          **9 hr 30 min**

If something takes longer, I will focus on getting the application,
container, Kubernetes configuration and deployment instructions into a
good state before adding optional features.

## 9. Things to be careful about

A few things could take more time or need a decision:

-   **AWS cost:** EKS and supporting resources are not free. I will
    check the expected cost and remove the resources after the exercise.
-   **Networking:** The cheaper networking option may not be suitable
    for production. I will document what I choose.
-   **Availability:** Three pods do not automatically mean high
    availability. Node placement and failure scenarios matter too.
-   **Credentials:** No AWS keys or other secrets should be committed to
    Git.
-   **Terraform state:** State can contain sensitive information, so it
    should not be stored in the repository.
-   **Image versions:** Deploy a specific image tag, not a moving
    `latest` tag.

## 10. When I would consider it ready

I would consider the PoC complete when:

-   The application tests pass.
-   The Docker image builds.
-   Terraform can validate and produce a plan.
-   The Kubernetes manifests can be validated.
-   The service can be deployed to EKS.
-   A request to the external endpoint returns `42`.
-   The GitHub Actions workflow runs the checks and can deploy the
    image.
-   The README explains how to set it up, test it and clean up the AWS
    resources.

## 11. What I would add before production

The PoC is only a starting point. Before using this as a production
service, I would want to work through:

-   An agreed availability target and clear service-level indicators.
-   More complete monitoring, alerting, logs and operational dashboards.
-   TLS, DNS and appropriate edge protection.
-   Capacity and load testing.
-   Failure testing across nodes and Availability Zones.
-   A deployment and rollback approach agreed by the team.
-   Security review, image scanning and access policies.
-   Documented incident response and recovery procedures.
-   Cost monitoring and ownership.

The main aim is to show a working, repeatable deployment and to be
honest about what it does and does not prove.
