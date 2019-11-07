module "vpc" {
  source       = "github.com/terraform-google-modules/terraform-google-network.git?ref=v0.8.0"
  project_id   = "${module.app_project.project_id}"
  network_name = "vpc"
  routing_mode = "GLOBAL"

  subnets = [
    {
      subnet_name           = "subnet-01"
      subnet_ip             = "192.168.0.0/20"
      subnet_region         = "us-west2"
      subnet_private_access = true
      subnet_flow_logs      = true
    },
  ]

  secondary_ranges = {
    subnet-01 = [
      {
        range_name    = "pods"
        ip_cidr_range = "10.4.0.0/14"
      },
      {
        range_name    = "services"
        ip_cidr_range = "10.0.32.0/20"
      },
    ]
  }
}
