
# 🔐 Bootstrap Guide: Google Cloud IAM and Workload Identity Federation

This guide explains how to configure Google Cloud infrastructure, Terraform remote state, Workload Identity Federation (WIF), and GitHub Actions for the GitOps Incident Simulation project.

The setup separates persistent bootstrap resources from the GKE infrastructure that can be created and destroyed through the lifecycle workflows.

> **Important:** Review every command and permission before running it. Replace example values with your own project, repository, and resource names. Do not commit credentials, Terraform state files, or SMTP passwords to Git.

## 🎯 What you'll configure

- A Google Cloud Storage (GCS) bucket for Terraform remote state.
- A Workload Identity Federation pool and GitHub OIDC provider.
- A dedicated Google Cloud service account for GitHub Actions.
- IAM permissions for infrastructure lifecycle operations and remote state.
- A protected GitHub Environment for manual Start and Stop workflows.
- GitHub repository variables and secrets required by the workflows.

## 🏗️ Understand the resource lifecycle

| Resource | Lifecycle |
|---|---|
| GCS Terraform state bucket | Persistent; not removed by the Stop workflow |
| WIF pool and GitHub OIDC provider | Persistent bootstrap resources |
| GitHub Actions service account and its IAM bindings | Persistent bootstrap resources |
| GKE cluster | Created by Start; destroyed by Stop |
| GKE node pool | Created by Start; destroyed by Stop |
| VPC and subnet managed by Terraform | Created by Start; destroyed by Stop |
| Terraform state objects | Updated by Terraform; retained according to backend and bucket retention settings |

The lifecycle workflows manage runtime infrastructure. They do not automatically create or delete every bootstrap resource described in this guide.

## 🧰 Prerequisites

Before starting, make sure you have:

- A Google Cloud project with billing enabled.
- Permission to enable APIs, create service accounts, configure IAM, create WIF resources, and manage the required infrastructure.
- A GitHub repository containing this project.
- Terraform installed locally for initial configuration and validation.
- The Google Cloud CLI (`gcloud`) installed and authenticated locally.
- Permission to configure GitHub repository variables, secrets, and Environments.

Use a dedicated project for experimentation where practical. Understand the cost of GKE nodes, networking, persistent storage, and any monitoring components before provisioning resources.

## 📝 1. Define your project values

Choose the values that match your environment.

| Setting | Example |
|---|---|
| Google Cloud project ID | `YOUR_GCP_PROJECT_ID` |
| GitHub repository | `YOUR_GITHUB_OWNER/YOUR_REPOSITORY` |
| GCP region | `asia-south1` |
| GKE zone | `asia-south1-a` |
| GKE cluster name | `gitops-gke` |
| Terraform state bucket | `YOUR_UNIQUE_TFSTATE_BUCKET` |
| WIF pool ID | `github-actions` |
| WIF provider ID | `github` |
| GitHub Actions service account | `github-actions-gke-lifecycle` |

Use the **project ID**, not the project display name, wherever a command requests a project ID. GCS bucket names must be globally unique.

Set the project for your local Google Cloud CLI session:

```bash
gcloud config set project YOUR_GCP_PROJECT_ID
```

Confirm the selected project:

```bash
gcloud config get-value project
```

Do not proceed if the selected project is incorrect.

## ☁️ 2. Enable required Google Cloud APIs

Enable the APIs required by the infrastructure and identity setup. The exact list depends on the Terraform resources and services used by your project.

For this project, the core APIs include:

```bash
gcloud services enable \
  compute.googleapis.com \
  container.googleapis.com \
  iam.googleapis.com \
  cloudresourcemanager.googleapis.com \
  sts.googleapis.com \
  iamcredentials.googleapis.com \
  storage.googleapis.com \
  --project=YOUR_GCP_PROJECT_ID
```

Some environments may require additional APIs. If Terraform reports that an API is disabled, verify the resource's requirements before enabling it.

## ☁️ 3. Create a protected GCS bucket for Terraform state

Terraform remote state is kept separately from the disposable GKE infrastructure. This allows lifecycle workflows to create and destroy the cluster without relying on a local state file.

Create a globally unique bucket in your chosen location:

```bash
gcloud storage buckets create gs://YOUR_UNIQUE_TFSTATE_BUCKET \
  --project=YOUR_GCP_PROJECT_ID \
  --location=ASIA-SOUTH1 \
  --uniform-bucket-level-access \
  --public-access-prevention
```

Enable object versioning:

```bash
gcloud storage buckets update gs://YOUR_UNIQUE_TFSTATE_BUCKET \
  --versioning
```

Consider configuring a suitable soft-delete policy and reviewing its cost and retention implications. The bucket should not be publicly accessible.

### Configure the Terraform backend

The project's Terraform backend is configured in `infra/terraform/backend.tf`.

The configuration should use the bucket you created and a project-specific prefix, for example:

```hcl
terraform {
  backend "gcs" {
    bucket = "YOUR_UNIQUE_TFSTATE_BUCKET"
    prefix = "gitops-incident-simulation/terraform"
  }
}
```

If the repository already contains a backend configuration, update its values rather than creating a duplicate backend block.

Initialize Terraform from the Terraform directory:

```bash
terraform -chdir=infra/terraform init
```

If you are migrating from local state, back up the existing state first and follow Terraform's state-migration prompts carefully. Do not delete local state or overwrite remote state until you have confirmed that the migration completed successfully.

**Security note:** Terraform state can contain sensitive values. Restrict access to the bucket, protect its contents, and do not upload state files to GitHub.

## 🔑 4. Configure Workload Identity Federation

GitHub Actions can obtain short-lived Google Cloud credentials using GitHub's OIDC tokens and Workload Identity Federation. This avoids storing a long-lived service-account JSON key in GitHub.

The trust chain is:

1. GitHub Actions requests an OIDC token.
2. Google Cloud validates the token through the configured WIF provider.
3. The provider's attribute condition restricts which GitHub repository and ref can authenticate.
4. The workflow impersonates the dedicated service account.
5. The service account uses its granted IAM permissions to perform the required operations.

### Create a WIF pool

Use a pool ID that matches the provider configuration expected by your project:

```bash
gcloud iam workload-identity-pools create github-actions \
  --project=YOUR_GCP_PROJECT_ID \
  --location=global \
  --display-name="GitHub Actions"
```

If the pool already exists, inspect it rather than attempting to create it again.

### Create the GitHub OIDC provider

The GitHub OIDC issuer is:

```text
https://token.actions.githubusercontent.com
```


The provider maps the GitHub claims used by the attribute condition. This example restricts authentication to the specified repository's `main` branch.

Create the provider with the supported `gcloud` flags:

```bash
gcloud iam workload-identity-pools providers create-oidc github \
  --project=YOUR_GCP_PROJECT_ID \
  --location=global \
  --workload-identity-pool=github-actions \
  --display-name="GitHub Actions OIDC" \
  --issuer-uri="https://token.actions.githubusercontent.com" \
  --attribute-mapping="google.subject=assertion.sub,attribute.repository=assertion.repository,attribute.ref=assertion.ref" \
  --attribute-condition="assertion.repository == 'YOUR_GITHUB_OWNER/YOUR_REPOSITORY' && assertion.ref == 'refs/heads/main'"
```

Replace `YOUR_GCP_PROJECT_ID` and `YOUR_GITHUB_OWNER/YOUR_REPOSITORY` with your actual values before running the command.

The condition restricts authentication to the specified repository's `main` branch. Keep the pool ID (`github-actions`) and provider ID (`github`) consistent with the resource name configured in GitHub Actions. If the provider already exists, inspect its configuration rather than attempting to create it again.


## 👤 5. Create a dedicated service account

Create a service account specifically for the lifecycle workflows:

```bash
gcloud iam service-accounts create github-actions-gke-lifecycle \
  --project=YOUR_GCP_PROJECT_ID \
  --display-name="GitHub Actions GKE Lifecycle"
```

Its email will have this format:

```text
github-actions-gke-lifecycle@YOUR_GCP_PROJECT_ID.iam.gserviceaccount.com
```

Use this identity only for the operations it needs to perform. Avoid using a personal account or a broadly privileged default service account for CI/CD.

### Allow the repository to impersonate the service account

Obtain your Google Cloud project number:

```bash
gcloud projects describe YOUR_GCP_PROJECT_ID \
  --format="value(projectNumber)"
```

Use that project number to construct the WIF principal set for the repository:

```text
principalSet://iam.googleapis.com/projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/github-actions/attribute.repository/YOUR_GITHUB_OWNER/YOUR_REPOSITORY
```

Grant the WIF principal permission to impersonate the dedicated service account:

```bash
gcloud iam service-accounts add-iam-policy-binding \
  github-actions-gke-lifecycle@YOUR_GCP_PROJECT_ID.iam.gserviceaccount.com \
  --project=YOUR_GCP_PROJECT_ID \
  --role=roles/iam.workloadIdentityUser \
  --member="principalSet://iam.googleapis.com/projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/github-actions/attribute.repository/YOUR_GITHUB_OWNER/YOUR_REPOSITORY"
```

Replace every placeholder with the actual value. The project number in the principal set is the **project number associated with the WIF pool**, not the project ID.

Some workflows or Terraform configurations may also require `roles/iam.serviceAccountUser` on the service account for service-account attachment or related operations. Grant it only when the workflow's actual operations require it; it is not a substitute for the WIF impersonation binding.

## 🛡️ 6. Grant IAM permissions carefully

The service account needs permissions to manage the Terraform resources and access the remote state bucket.

Typical permission areas include:

- GKE cluster and node-pool management.
- VPC and subnet management.
- Reading project and service configuration.
- Reading and writing Terraform state objects in the dedicated GCS bucket.
- Any additional operations explicitly required by the Terraform configuration.

A broad project role such as `roles/container.admin` may be convenient for a learning project, but it does not automatically grant all permissions required for networking, IAM, or storage operations. Conversely, project-level administrative roles can be more powerful than necessary.

For remote state, a bucket-scoped role such as `roles/storage.objectAdmin` may be used when the workflow needs to read, create, update, and delete Terraform state objects. Keep bucket access scoped to the state bucket rather than granting it across the entire project.

Before granting permissions:

1. Review the resources in `infra/terraform/`.
2. Inspect the operations performed by the Start and Stop workflows.
3. Grant the minimum practical permissions at the narrowest supported scope.
4. Test the workflow and add narrowly scoped permissions only when a genuine permission error demonstrates the need.

Do not blindly copy IAM bindings from another project. The exact permissions depend on the resource configuration, the workflow's operations, and your organization's security requirements.

## ⚙️ 7. Configure the GitHub Environment

The lifecycle workflows use a GitHub Environment named:

```text
gke-lifecycle
```

In your GitHub repository, open **Settings → Environments** and create or configure this environment.

Recommended settings:

- Require approval before a lifecycle workflow proceeds, where supported by your GitHub plan and repository settings.
- Restrict deployment branches to `main` if that matches your workflow design.
- Review who can approve a run.
- Keep Start and Stop operations manual rather than running them automatically on every push.

The Environment name must match the name referenced in both lifecycle workflow files.

### Configure repository variables

Open **Settings → Secrets and variables → Actions → Variables** and create the variables referenced by the workflow YAML files.

For this project, the infrastructure variables include:

| Variable | Purpose |
|---|---|
| `GCP_PROJECT_ID` | Google Cloud project ID |
| `GCP_REGION` | GKE region |
| `GCP_ZONE` | GKE zone |
| `GCP_CLUSTER_NAME` | GKE cluster name |
| `GCP_WIF_PROVIDER` | Full WIF provider resource name |
| `GCP_SERVICE_ACCOUNT` | Service-account email |

**Important:** Use `GCP_CLUSTER_NAME` for the GitHub variable and workflow environment. The lifecycle scripts use this name and pass the selected cluster name to Terraform through `TF_VAR_cluster_name`.

For this repository, the two WIF values follow these formats:
- `GCP_WIF_PROVIDER`: `projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/github-actions/providers/github`
- `GCP_SERVICE_ACCOUNT`: `github-actions-gke-lifecycle@YOUR_GCP_PROJECT_ID.iam.gserviceaccount.com`

Use the actual project number and project ID when configuring your GitHub Environment.

### Configure secrets

Store sensitive values, such as the Grafana SMTP password, in GitHub Secrets or the protected GitHub Environment where the workflow expects them.

For this project, the infrastructure secrets include:

| Secret | Purpose |
|---|---|
| `GRAFANA_SMTP_USERNAME` | Gmail account used for Grafana alert email |
| `GRAFANA_SMTP_PASSWORD` |	Gmail app password used for SMTP authentication |

Check the Start workflow and its scripts to determine the exact secret names and prompting behavior. Do not place passwords, SMTP credentials, service-account keys, or other secrets in repository variables, source files, or committed workflow YAML.

**Do not create or upload a service-account JSON key for WIF authentication.**

## 🚦 8. Understand the Start and Stop workflows

### Start workflow

The manual Start workflow:

1. Authenticates to Google Cloud through GitHub OIDC and WIF.
2. Initializes Terraform with the GCS backend.
3. Provisions the Terraform-managed runtime infrastructure.
4. Configures the Kubernetes and GitOps platform using the project scripts.
5. Applies the configured GitOps and observability resources.

The workflow does not necessarily wait for every Argo CD application to become healthy. After Start completes, verify cluster access, Argo CD application status, and monitoring components separately.

### Stop workflow

The manual Stop workflow destroys the Terraform-managed runtime infrastructure.

In this project, the managed resources include the GKE cluster, node pool, VPC, and subnet. After Stop, verify that the intended runtime resources are absent and that the Terraform remote state no longer lists managed runtime resources.

The Stop workflow is **not** intended to delete the GCS state bucket, WIF pool/provider, service account, or bootstrap IAM bindings.

Before using Stop, confirm that no other workloads or resources depend on the infrastructure being destroyed. Review the Terraform plan and understand the impact before approving destructive operations.

## 🔍 9. Validate the setup safely

Before running the Start workflow:

1. Confirm the correct GCP project, region, zone, and cluster name.
2. Verify that the GCS state bucket exists and is not public.
3. Verify the WIF pool and provider are active.
4. Confirm the provider's repository/ref condition matches your repository and intended branch.
5. Confirm the service account's WIF impersonation binding and required resource permissions.
6. Check that the workflow's WIF provider and service-account inputs match the configured Google Cloud resources.
7. Verify that `gke-lifecycle` exists and its approval settings are correct.
8. Review the Terraform configuration and expected cloud costs.
9. Validate Terraform configuration locally before provisioning infrastructure.

For example:

```bash
terraform -chdir=infra/terraform fmt -check
terraform -chdir=infra/terraform validate
```

These commands validate formatting and configuration; they do not prove that Google Cloud IAM, GitHub OIDC trust, or resource permissions are correct.

Start the lifecycle workflow only when you are ready to create the infrastructure and accept its costs. After testing, run Stop and verify the intended resources were removed.

## 💰 10. Cost and security considerations

- GKE and its worker nodes can incur costs while running.
- Stop runtime infrastructure when it is not needed.
- The GCS state bucket and retained objects may continue to incur small storage costs.
- Review monitoring resource requests, load balancers, disks, and network resources when estimating total cost.
- Use WIF instead of long-lived service-account keys.
- Restrict the WIF provider to the intended repository and refs.
- Avoid granting broad project-wide roles unless they are justified.
- Keep Terraform state and application secrets out of Git.
- Never delete the remote state bucket while Terraform still depends on it.
- Treat Stop as a destructive infrastructure operation and review its scope before execution.

## 🧹 11. Cleanup boundaries

When you finish testing, use the Stop workflow to remove the Terraform-managed runtime resources.

Keep the bootstrap resources if you intend to run the project again:

- GCS Terraform state bucket.
- WIF pool and provider.
- Dedicated service account.
- Required IAM bindings.

If you later decide to retire the project completely, first confirm that the runtime infrastructure is gone and that you no longer need the remote state or recovery history. Then remove bootstrap resources deliberately, following your organization's retention and access policies.

## 📚 Related project documentation

- [Project overview and architecture](../README.md)
- [Terraform configuration](../infra/terraform/)
- [GitHub Actions workflows](../.github/workflows/)
- [Lifecycle helper scripts](../scripts/)

---

**Remember:** This guide documents the setup pattern, not a universal IAM policy. Verify the actual workflow inputs, Terraform resources, and permissions for your own environment before provisioning infrastructure.
