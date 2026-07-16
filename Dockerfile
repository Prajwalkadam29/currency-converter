# Stage 1: Build the application using Maven
FROM maven:3.9.6-eclipse-temurin-21 AS build
WORKDIR /app
# Copy only the pom.xml first to cache dependencies
COPY pom.xml .
# Download dependencies (improves build speed for subsequent builds)
RUN mvn dependency:go-offline
# Copy the source code
COPY src ./src
# Build the JAR file, skipping tests for speed
RUN mvn clean package -DskipTests

# Stage 2: Run the application using a lightweight JRE
FROM eclipse-temurin:21-jre
WORKDIR /app
# Copy the built JAR from the 'build' stage
COPY --from=build /app/target/currency-converter-0.0.1-SNAPSHOT.jar app.jar
# Expose the port configured in application.properties
EXPOSE 8080
# Run the application
ENTRYPOINT ["java", "-jar", "app.jar"]