# Currency Converter API

A lightweight, cloud-native Currency Converter built with **Java 21** and **Spring Boot 4**. It features a responsive UI rendered via Thymeleaf and fetches live exchange rates from an external provider (ExchangeRate-API).

Designed for modern DevOps workflows, this application uses a multi-stage Docker build.

## Tech Stack
* **Backend:** Java 21, Spring Boot 4.0.7
* **Frontend:** HTML5, Modern CSS, Thymeleaf
* **Build Tool:** Maven
* **Testing:** JUnit 5, Mockito (Spring WebMvcTest)
* **Containerization:** Docker (Multi-stage build)

## 📋 Prerequisites
* Java 21 installed locally (for local compilation)
* Maven 3.9+
* Docker
* An API key from [ExchangeRate-API](https://www.exchangerate-api.com/)

## ⚙️ Configuration
The application relies on environment variables for secure configuration.

| Environment Variable | Description | Default / Fallback |
|----------------------|-------------|--------------------|
| `CURRENCY_API_KEY`   | **Required**. Your external API key. | `mock-key-for-local` |

## 💻 Local Development

1. **Clone the repository:**
   ```bash
   git clone https://github.com/Prajwalkadam29/currency-converter.git
   cd currency-converter
   ```

2. **Run Tests**

The test suite uses `@MockitoBean` to mock external API calls, ensuring tests run instantly without requiring network access.

```bash
mvn clean test
```

3. **Run locally:**

```bash
export CURRENCY_API_KEY="your_real_api_key_here"
mvn spring-boot:run
```

The application will be available at `http://localhost:8080`


## 🐳 Docker Deployment

This project uses a multi-stage Dockerfile. It compiles the code in a Maven container and packages the final artifact into a lightweight Eclipse Temurin JRE container.

1. **Build the image:**

```bash
docker build -t currency-converter:latest .
```

2. **Run the container:**

```bash
docker run -p 8080:8080 -e CURRENCY_API_KEY="your_real_api_key_here" currency-converter:latest
```

---

## End-to-End DevSecOps Pipeline

Beyond the application itself, this project is backed by a complete DevSecOps pipeline covering infrastructure, CI/CD, and observability. Each phase is documented in its own location:

### Phase 1: Infrastructure Setup
Terraform code provisioning the VPC, EKS cluster, Jenkins/SonarQube EC2 instance, ECR repository, and IRSA roles.
- 📁 [`/terraform`](https://github.com/Prajwalkadam29/currency-converter/tree/main/terraform)

### Phase 2: CI/CD Setup & Multi-Environment Deployment
- **CI on Jenkins** — pipeline logic, security gates (secrets scan, SAST, SCA, image scan), and image signing.
  
    📁 [jenkins-shared-library](https://github.com/Prajwalkadam29/jenkins-shared-library)
- **CD via GitOps** — Argo CD ApplicationSet and environment-specific manifests for dev/staging/prod.
  
    📁 [gitops-config-cc-app](https://github.com/Prajwalkadam29/gitops-config-cc-app/)

### Phase 3: Monitoring & Observability
Prometheus, Grafana, and health-check configuration for the CI pipeline and the EKS cluster.
- 📁 [`/observability`](https://github.com/Prajwalkadam29/currency-converter/tree/main/observability)