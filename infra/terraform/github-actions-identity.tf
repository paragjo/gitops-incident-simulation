# Existing GitHub Actions Workload Identity Federation resources.
# These resources will be imported into the existing remote Terraform state.

data "google_project" "current" {
  project_id = var.project_id
}

resource "google_iam_workload_identity_pool" "github_actions" {
  project                   = data.google_project.current.number
  workload_identity_pool_id = "github-actions"
  display_name              = "GitHub Actions"
}

resource "google_iam_workload_identity_pool_provider" "github" {
  project                            = data.google_project.current.number
  workload_identity_pool_id          = google_iam_workload_identity_pool.github_actions.workload_identity_pool_id
  workload_identity_pool_provider_id = "github"
  display_name                       = "GitHub Actions GitHub OIDC"

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.repository" = "assertion.repository"
    "attribute.ref"        = "assertion.ref"
    "attribute.actor"      = "assertion.actor"
  }

  attribute_condition = "assertion.repository == 'paragjo/gitops-incident-simulation' && assertion.ref == 'refs/heads/main'"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

resource "google_service_account" "github_actions_gke_lifecycle" {
  project      = var.project_id
  account_id   = "github-actions-gke-lifecycle"
  display_name = "GitHub Actions GKE Lifecycle"
}

resource "google_service_account_iam_member" "github_actions_trust" {
  service_account_id = google_service_account.github_actions_gke_lifecycle.name
  role               = "roles/iam.workloadIdentityUser"

  member = "principalSet://iam.googleapis.com/projects/${data.google_project.current.number}/locations/global/workloadIdentityPools/github-actions/attribute.repository/paragjo/gitops-incident-simulation"
}

resource "google_project_iam_member" "github_actions_container_admin" {
  project = var.project_id
  role    = "roles/container.admin"
  member  = google_service_account.github_actions_gke_lifecycle.member
}

resource "google_project_iam_member" "github_actions_network_admin" {
  project = var.project_id
  role    = "roles/compute.networkAdmin"
  member  = google_service_account.github_actions_gke_lifecycle.member
}

resource "google_storage_bucket_iam_member" "github_actions_state" {
  bucket = "paragjo-gitops-tfstate"
  role   = "roles/storage.objectAdmin"
  member = google_service_account.github_actions_gke_lifecycle.member
}
