resource "google_container_node_pool" "gitops" {
  name     = "gitops-node-pool"
  location = "asia-south1-a"
  cluster  = google_container_cluster.gitops.name

  node_count = 1

  node_config {
    machine_type = "e2-medium"
    spot         = true

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }
}
