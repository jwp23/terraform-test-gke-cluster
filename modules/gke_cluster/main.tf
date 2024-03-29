locals {
  disable_legacy_endpoints = true

  node_pool_oauth_scopes = [
    "https://www.googleapis.com/auth/compute",
    "https://www.googleapis.com/auth/devstorage.read_write",
    "https://www.googleapis.com/auth/projecthosting",
    "https://www.googleapis.com/auth/logging.write",
    "https://www.googleapis.com/auth/monitoring",
  ]
}

// enable the kubernetes engine service
resource "google_project_service" "gke_service" {
  project = "${var.project}"
  service = "container.googleapis.com"

  disable_dependent_services = true
}

resource "google_container_cluster" "private-gke" {
  provider = "google-beta"

  name       = "${var.cluster_name}"
  depends_on = ["google_project_service.gke_service"]

  project                   = "${var.project}"
  network                   = "${var.network_name}"
  subnetwork                = "${var.subnet_name}"
  min_master_version        = "${var.gke_version}"
  location                  = "${var.location}"
  default_max_pods_per_node = "${var.max_pods_per_node}"

  # Enable the new Stackdriver Kubernetes Monitoring/Logging features
  monitoring_service = "monitoring.googleapis.com/kubernetes"
  logging_service    = "logging.googleapis.com/kubernetes"

  # We can't create a cluster with no node pool defined, but we want to only use
  # separately managed node pools. So we create the smallest possible default
  # node pool and immediately delete it.
  remove_default_node_pool = true

  initial_node_count = 1

  # We need to configure the service account for the initial default pool.
  # We need to remove it after the cluster is created because it'll trigger
  # a destroy and rebuild if we leave it.
  node_config {
    service_account = "${google_service_account.gke_node.email}"
    tags            = "${var.gke_node_tags}"
  }

  addons_config {
    horizontal_pod_autoscaling {
      disabled = "${var.disable_horizontal_pod_autoscaling}"
    }
  }

  ip_allocation_policy {
    cluster_secondary_range_name  = "${var.pods_secondary_range_name}"
    services_secondary_range_name = "${var.services_secondary_range_name}"
  }

  private_cluster_config {
    enable_private_nodes   = true
    master_ipv4_cidr_block = "${var.master_cidr_block}"
  }

  master_authorized_networks_config {
    cidr_blocks = "${var.master_authorized_network}"
  }
}

resource "google_container_node_pool" "private-gke-node-pool-primary" {
  provider = "google-beta"
  project  = "${var.project}"

  name     = "node-pool-primary"
  location = "${var.location}"
  cluster  = "${google_container_cluster.private-gke.name}"

  # in multi-zonal clusters initial_node_count is the number of nodes per zone
  initial_node_count = "${var.primary_initial_node_count}"
  max_pods_per_node  = "${var.max_pods_per_node}"

  // nodes configutation
  node_config {
    service_account = "${google_service_account.gke_node.email}"

    oauth_scopes = "${local.node_pool_oauth_scopes}"

    metadata {
      disable-legacy-endpoints = "${local.disable_legacy_endpoints}"
    }

    machine_type = "${var.gke_nodes_machine_type}"
    disk_type    = "${var.gke_nodes_disk_type}"
    disk_size_gb = "${var.gke_nodes_disk_size_gb}"
    tags         = "${var.gke_node_tags}"
  }

  autoscaling {
    max_node_count = "${var.primary_max_node_count}"
    min_node_count = "${var.primary_min_node_count}"
  }
}

// This node pool is used when we upgrade the cluster or need a second node pool
// for some other reason.
resource "google_container_node_pool" "private-gke-node-pool-secondary" {
  provider = "google-beta"
  project  = "${var.project}"

  name     = "node-pool-secondary"
  location = "${var.location}"
  cluster  = "${google_container_cluster.private-gke.name}"

  # in multi-zonal clusters initial_node_count is the number of nodes per zone
  initial_node_count = "${var.secondary_initial_node_count}"
  max_pods_per_node  = "${var.max_pods_per_node}"

  // nodes configutation
  node_config {
    service_account = "${google_service_account.gke_node.email}"

    oauth_scopes = "${local.node_pool_oauth_scopes}"

    metadata {
      disable-legacy-endpoints = "${local.disable_legacy_endpoints}"
    }

    machine_type = "${var.gke_nodes_machine_type}"
    disk_type    = "${var.gke_nodes_disk_type}"
    disk_size_gb = "${var.gke_nodes_disk_size_gb}"
    tags         = "${var.gke_node_tags}"
  }

  autoscaling {
    max_node_count = "${var.secondary_max_node_count}"
    min_node_count = "${var.secondary_min_node_count}"
  }
}

// gke nodes service account
resource "google_service_account" "gke_node" {
  project      = "${var.project}"
  account_id   = "${var.cluster_service_acct_id}"
  display_name = "Gke node service account for ${var.cluster_name}"
}

resource "google_project_iam_member" "gke_node" {
  count   = "${length(var.gke_node_list_of_roles)}"
  project = "${var.project}"
  role    = "roles/${var.gke_node_list_of_roles[count.index]}"
  member  = "serviceAccount:${google_service_account.gke_node.email}"
}
