resource "google_folder" "app" {
  parent       = "${local.root_id}"
  display_name = "${local.app}"
}

module "app_project" {
  source            = "github.com/terraform-google-modules/terraform-google-project-factory.git?ref=v2.4.1"
  random_project_id = true
  name              = "${local.project_name}"
  org_id            = "${local.org_id}"
  folder_id         = "${google_folder.app.id}"
  billing_account   = "${local.billing_account}"

  activate_apis = [
    "container.googleapis.com",
    "logging.googleapis.com",
  ]
}
