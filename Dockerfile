# ==========================================
# Stage 1: Build the Application
# ==========================================
FROM eclipse-temurin:21-jdk-alpine AS builder
WORKDIR /app

# Copy wrapper and pom.xml first to cache dependencies (improves build speed)
COPY mvnw .
COPY .mvn .mvn
COPY pom.xml .
RUN ./mvnw dependency:go-offline

# Copy source and build
COPY src src
RUN ./mvnw clean package -DskipTests

# ==========================================
# Stage 2: Minimal Secure Runtime Environment
# ==========================================
FROM eclipse-temurin:21-jre-alpine
WORKDIR /app

# Create a non-root user and group
RUN addgroup -S spring && adduser -S spring -G spring

# Copy the built artifact from the builder stage
COPY --from=builder /app/target/*.jar app.jar

# Change ownership to the non-root user
RUN chown -R spring:spring /app

# Switch to the non-root user (Kyverno compliance)
USER spring

EXPOSE 8080

ENTRYPOINT ["java", "-jar", "app.jar"]