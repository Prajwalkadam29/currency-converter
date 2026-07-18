# Phase 3: Observability & Monitoring Architecture

This directory contains the configuration and operational runbook for the comprehensive observability stack monitoring the **Currency Converter GitOps Pipeline**.

A true DevSecOps platform requires deep visibility into both the Continuous Integration engine (Jenkins) and the runtime deployment environment (Amazon EKS). This stack implements industry-standard tools to achieve full-stack observability.

---

## Architecture Overview

Our observability strategy is divided into three core pillars:

### 1. Infrastructure & CI Monitoring (Jenkins EC2)

* **AWS CloudWatch:** Monitors basic EC2 hardware metrics (CPU credit usage, disk I/O, network throughput).

* **Jenkins Prometheus Plugin:** Exposes internal CI metrics (build queue depth, executor status, job durations) via an unauthenticated `/prometheus/` endpoint.


### 2. Cluster & Application Monitoring (EKS)

* **Prometheus:** The central time-series database. Scrapes metrics from Kubernetes nodes (`node-exporter`), cluster state (`kube-state-metrics`), and our external Jenkins server.

* **Grafana:** Provides the visualization layer with pre-configured dashboards mapping CPU/Memory consumption against requested limits across the `dev`, `staging`, and `prod` namespaces.


### 3. Runtime Self-Healing (Kubernetes Probes)

* Liveness & Readiness Probes: The Currency Converter application exposes a `/health` endpoint. Kubernetes actively polls this to dynamically route traffic away from failing pods and automatically restart deadlocked containers.

---

## Deployment Instructions

### 1. Configure the Jenkins CI Server
Before deploying the cluster monitoring, Jenkins must be configured to expose its metrics.

1. Log into Jenkins as an Administrator.
2. Navigate to **Manage Jenkins -> Plugins -> Available Plugins**.
3. Search for and install the **Prometheus metrics** plugin.
4. Restart Jenkins.
5. Verify metrics are being published by visiting: `http://<JENKINS_IP>:8080/prometheus/`


### 2. Deploy the Kube-Prometheus-Stack to EKS
We utilize the community-standard `kube-prometheus-stack` Helm chart to deploy Prometheus and Grafana simultaneously.

1. Add the Prometheus community Helm repository:

    ```bash
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo update
    ```

2. Install the stack into a dedicated `monitoring` namespace, passing our custom `values.yaml` to ensure it scrapes the Jenkins server:

    ```bash
    helm install observability prometheus-community/kube-prometheus-stack \
      --namespace monitoring \
      --create-namespace \
      -f prometheus-grafana-values.yaml
    ```


### 3. Accessing the Dashboards

To maintain a secure cluster perimeter without exposing a public Ingress for the monitoring tools, we utilize secure `kubectl` port-forwarding to access the dashboards.

**1. Access Grafana:**

    ```bash
    kubectl port-forward svc/observability-grafana 3000:80 -n monitoring --address 0.0.0.0
    ```

Open `http://localhost:3000` in your browser. (Default login: `admin` / `admin`).


**2. Access Prometheus (Direct Querying):**

```bash
kubectl port-forward svc/observability-kube-prometheus-prometheus 9090:9090 -n monitoring --address 0.0.0.0
```

---

## Validating Application Health Probes

The Currency Converter application uses Kubernetes health probes. To verify these are functioning correctly, you can describe a running pod in any environment:

    ```bash
    kubectl describe pod -l app=currency-converter-app -n currency-converter-app-dev
    ```

You should see output confirming the probes are active and passing:

```terminaloutput
Liveness:   http-get http://:8080/health delay=30s timeout=1s period=15s #success=1 #failure=3
Readiness:  http-get http://:8080/health delay=15s timeout=1s period=10s #success=1 #failure=3
```

---

## Trade-offs & Future Improvements

1. **Local Persistent Volumes:** Currently, Prometheus uses ephemeral pod storage. In a real production environment, this Helm chart should be configured to use AWS EBS CSI volumes for long-term metric retention.

2. **Alertmanager Integration:** While Prometheus is collecting data, Alertmanager is not currently hooked into Slack or PagerDuty. A production-ready iteration would configure alerting rules (e.g., `JenkinsQueueTooLong`, `PodCrashLooping`) to proactively page the SRE team.

---
