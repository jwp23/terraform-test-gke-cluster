locals {
  org_id       = "${var.org_id}"
  app          = "gke"
  folder_name  = "test-gke"
  project_name = "test-gke"

  root_id         = "organizations/${local.org_id}"
  billing_account = "${var.billing_account}"

  region = "us-west2"
}

data "google_container_engine_versions" "gke_versions" {
  project  = "${module.app_project.project_id}"
  location = "${local.region}"
}

module "test_cluster" {
  source                        = "./modules/gke_cluster"
  project                       = "${module.app_project.project_id}"
  location                      = "${local.region}"
  network_name                  = "${module.vpc.network_name}"
  subnet_name                   = "${module.vpc.subnets_names[0]}"
  cluster_service_acct_id       = "gke-service-account"
  pods_secondary_range_name     = "pods"
  services_secondary_range_name = "services"
  gke_nodes_machine_type        = "n1-standard-1"
  max_pods_per_node             = 110
  gke_nodes_disk_size_gb        = 10
  primary_initial_node_count    = 1
  master_cidr_block             = "172.16.0.16/28"
  cluster_name                  = "gke-private-cluster"
  gke_node_tags                 = ["test", "gke"]
  enable_autoscaling            = true
  primary_max_node_count        = 3
  primary_min_node_count        = 1
  secondary_max_node_count      = 3
  secondary_min_node_count      = 0

  master_authorized_network = [
    {
      display_name = "all_access"
      cidr_block   = "0.0.0.0/0"
    },
  ]

  gke_node_list_of_roles = ["monitoring.editor", "logging.logWriter"]
  gke_version            = "${data.google_container_engine_versions.gke_versions.latest_master_version}"
}
