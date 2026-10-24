resource "google_container_node_pool" "gitops" {
  name     = "gitops-node-pool"
  location = var.zone
  cluster  = google_container_cluster.gitops.name

  autoscaling {
    min_node_count = 1
    max_node_count = 2
  }

  node_config {
    machine_type = "e2-standard-2"
    spot         = true

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }
}
