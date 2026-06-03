# AWS ECS Lab — Spring Boot

A minimal Spring Boot 3 (Java 21) web app that renders a page with:

- **Full name:** Alfred Dey
- **Lab name:** AWS ECS Lab

Built for deploying a container to Amazon ECS.

## Tech stack

- Spring Boot 3.4.1 (Web + Thymeleaf + Actuator)
- Java 21, Maven
- Multi-stage Dockerfile (non-root runtime)

## Run locally

```bash
mvn spring-boot:run
# or
mvn clean package && java -jar target/ecs-lab-0.0.1-SNAPSHOT.jar
```

Then open http://localhost:8080/

Health endpoint (used by ECS / ALB): http://localhost:8080/actuator/health

## Build & run with Docker

```bash
docker build -t ecs-lab .
docker run --rm -p 8080:8080 ecs-lab
```

## CI/CD — GitHub Actions → ECR → CodePipeline (blue/green)

Infrastructure is provisioned by `../aws-ecs/ecs-cicd.yaml` (Fargate behind an
ALB, ECR, GitHub OIDC, EventBridge-driven CodePipeline, CodeDeploy blue/green).

Deployment flow:

```
git push main
  → GitHub Actions (.github/workflows/deploy.yml)
      • assumes the GitHubActionsRole via OIDC (no static keys)
      • builds the image, pushes :<git-sha> and :latest to ECR
  → ECR PUSH of :latest fires EventBridge rule (EcrPushRule)
  → CodePipeline: ECR source → CodeBuild renders taskdef/appspec → CodeDeployToECS
  → CodeDeploy blue/green shift on the ALB
```

The workflow only pushes to ECR; the pipeline is triggered by the ECR event, so
the OIDC role needs nothing beyond ECR push permissions.

### Required stack alignment

Deploy `ecs-cicd.yaml` with parameters that match this repo:

- `GitHubRepo=aws-ecs-app` (and `GitHubOrg=alfreddey`, `GitHubBranch=main`) so the
  OIDC trust policy accepts tokens from this repo.
- The container listens on **port 80**, matching the template's default
  `ContainerPort=80`. (The image runs as root to bind the privileged port; set
  `SERVER_PORT` to change it.)

### Required GitHub config (Settings → Secrets and variables → Actions)

| Kind | Name | Value |
|------|------|-------|
| Secret | `AWS_GHA_ROLE_ARN` | The `GitHubActionsRoleArn` stack output (`arn:aws:iam::<acct>:role/<stack>-gha-ecr-push`) |
| Variable | `AWS_REGION` | Region the stack is deployed in, e.g. `eu-west-1` |
| Variable | `ECR_REPOSITORY` | ECR repo name = `<stack-name>-ecs-cicd-app` (the `${StackName}-${ServiceName}`) |

The ALB target group health-checks the container; the app responds 200 on `/`
and exposes `GET /actuator/health` as well.

### Manual one-off push (without GitHub Actions)

```bash
aws ecr get-login-password --region <region> \
  | docker login --username AWS --password-stdin <acct>.dkr.ecr.<region>.amazonaws.com
docker build -t <acct>.dkr.ecr.<region>.amazonaws.com/<stack>-ecs-cicd-app:latest .
docker push <acct>.dkr.ecr.<region>.amazonaws.com/<stack>-ecs-cicd-app:latest
# the :latest push triggers CodePipeline automatically
```

## Project layout

```
src/main/java/com/example/ecslab/
  EcsLabApplication.java   # Spring Boot entry point
  HomeController.java      # serves "/" with name + lab name
src/main/resources/
  templates/index.html     # Thymeleaf page
  application.properties    # port + actuator health config
src/test/java/.../HomeControllerTest.java
Dockerfile
```
