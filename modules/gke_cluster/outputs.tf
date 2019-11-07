output "cluster_name" {
  value = "${google_container_cluster.private-gke.name}"
}

output "location" {
  value = "${var.location}"
}

output "project" {
  value = "${var.project}"
}
