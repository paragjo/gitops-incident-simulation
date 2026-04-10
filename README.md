# 🚀 GitOps-Based Incident Simulation & Monitoring System

## 📌 Overview

A production-inspired Kubernetes platform that demonstrates **GitOps workflows, failure engineering, and observability** by intentionally injecting failures and monitoring system behavior in real time.

This project simulates real-world incidents (memory leaks, crash loops, resource exhaustion) and validates detection using a full observability stack.

---

## 🎯 Key Highlights

* ⚙️ **GitOps-driven deployments** using declarative configuration
* 💥 **Failure simulation system** (memory leak, crashloop, CPU spike)
* 📊 **End-to-end observability**

  * Metrics → Prometheus
  * Dashboards → Grafana
  * Logs → Loki
  * Alerts → Alertmanager
* ☁️ **Infrastructure as Code (Terraform)** for cloud provisioning
* 🌍 **Multi-environment setup** (Dev / Staging / Prod)
* 🔁 **Automated CI/CD pipelines**

---

## 🏗️ Architecture

```
                +----------------------+
                |      Git Repo        |
                | (Single Source of Truth)
                +----------+-----------+
                           |
                           v
                   +--------------+
                   |   ArgoCD     |
                   | (GitOps Sync)|
                   +------+-------+
                          |
                          v
                +--------------------+
                | Kubernetes Cluster |
                | (GKE / EKS)        |
                +--------------------+
                  |       |        |
                  v       v        v
              App Pods  Chaos   Monitoring
                         |        |
                         v        v
                   Failures   Metrics/Logs
                                |
                                v
                         Grafana Dashboards
```

---

## 🧪 Failure Scenarios

| Scenario    | Description                         | Expected Outcome          |
| ----------- | ----------------------------------- | ------------------------- |
| Memory Leak | Gradual memory consumption increase | Pod restart (OOMKilled)   |
| CrashLoop   | App crashes repeatedly              | CrashLoopBackOff state    |
| CPU Spike   | Sudden CPU usage surge              | High CPU alerts triggered |

---

## 📂 Repository Structure

```
gitops-incident-simulation/
├── infra/              # Terraform (cloud + cluster)
├── gitops/             # Kubernetes manifests (GitOps)
├── app/                # Microservice code
├── chaos/              # Failure simulation
├── observability/      # Prometheus, Grafana, Loki
├── ci-cd/              # GitLab pipelines
└── docs/               # Architecture & scenarios
```

---

## ⚙️ Tech Stack

* **Cloud**: GCP (GKE) / AWS (EKS)
* **Infrastructure**: Terraform
* **Container Orchestration**: Kubernetes
* **GitOps**: ArgoCD
* **CI/CD**: GitLab CI
* **Monitoring**: Prometheus + Grafana
* **Logging**: Loki
* **Alerting**: Alertmanager

---

## 🚦 Project Phases

* [x] Kubernetes app deployment
* [x] Failure simulation (memory leak, crashloop)
* [ ] GitOps implementation (ArgoCD)
* [ ] Observability stack (Prometheus, Grafana, Loki)
* [ ] Terraform-based cloud provisioning
* [ ] Multi-environment setup

---

## 📸 Demo (To Be Added)

* Grafana dashboards screenshots
* Alert triggers
* CrashLoop / OOMKilled scenarios

---

## 💡 Why This Project Matters

Modern systems are not just about deployment — they are about **resilience and observability**.

This project demonstrates:

* How failures occur in distributed systems
* How to detect them using real-world monitoring tools
* How GitOps ensures consistent and automated recovery

---

## 👨‍💻 Author

**Parag** – Cloud DevOps Engineer
Specializing in Kubernetes, Terraform, and Observability
