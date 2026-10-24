resource "google_container_cluster" "gitops" {
  name     = var.cluster_name
  location = var.zone

  network    = google_compute_network.gitops.id
  subnetwork = google_compute_subnetwork.gitops.id

  networking_mode = "VPC_NATIVE"

  ip_allocation_policy {
    cluster_secondary_range_name = "gitops-pods"
  }

  remove_default_node_pool = true
  initial_node_count       = 1

  release_channel {
    channel = "REGULAR"
  }

  deletion_protection = false
}
