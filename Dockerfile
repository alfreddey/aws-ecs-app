# ---- Build stage ----
FROM maven:3.9-eclipse-temurin-21 AS build
WORKDIR /app

# Cache dependencies first
COPY pom.xml .
RUN mvn -B -q dependency:go-offline

# Build the application
COPY src ./src
RUN mvn -B -q clean package -DskipTests

# ---- Runtime stage ----
FROM eclipse-temurin:21-jre-jammy
WORKDIR /app

COPY --from=build /app/target/ecs-lab-0.0.1-SNAPSHOT.jar app.jar

# The ECS task definition / ALB target group use ContainerPort 80, so the
# app binds :80. Port 80 is privileged, so the container runs as root (the
# default) to bind it. Override SERVER_PORT to change the listen port.
ENV SERVER_PORT=80
EXPOSE 80

# ECS task definition / ALB target group should health-check GET /actuator/health
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
