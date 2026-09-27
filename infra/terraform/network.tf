resource "google_compute_network" "gitops" {
  name                    = "gitops-gke-network"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "gitops" {
  name          = "gitops-gke-subnet"
  ip_cidr_range = "10.10.0.0/24"
  region        = "asia-south1"
  network       = google_compute_network.gitops.id

  secondary_ip_range {
    range_name    = "gitops-pods"
    ip_cidr_range = "10.20.0.0/20"
  }
}
