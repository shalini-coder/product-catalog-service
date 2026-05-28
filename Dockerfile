# ── Build stage ───────────────────────────────────────────────────────────────
# Uses official Maven + Temurin 21 image so no wrapper script is needed.
FROM maven:3.9-eclipse-temurin-21-alpine AS builder

WORKDIR /workspace

# Cache the dependency layer separately so rebuilds skip this when pom.xml is unchanged
COPY pom.xml .
RUN --mount=type=cache,target=/root/.m2 \
    mvn -q dependency:go-offline -DskipTests

COPY src src

RUN --mount=type=cache,target=/root/.m2 \
    mvn -q package -Dmaven.test.skip=true && \
    mkdir -p target/extracted && \
    java -Djarmode=layertools -jar target/*.jar extract --destination target/extracted

# ── Runtime stage ─────────────────────────────────────────────────────────────
FROM eclipse-temurin:21-jre-alpine

RUN addgroup --system spring && adduser --system spring --ingroup spring
USER spring:spring

WORKDIR /app

COPY --from=builder /workspace/target/extracted/dependencies/          ./
COPY --from=builder /workspace/target/extracted/spring-boot-loader/    ./
COPY --from=builder /workspace/target/extracted/snapshot-dependencies/ ./
COPY --from=builder /workspace/target/extracted/application/           ./

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=40s --retries=3 \
  CMD wget -qO- http://localhost:8080/actuator/health || exit 1

ENTRYPOINT ["java", "org.springframework.boot.loader.launch.JarLauncher"]
