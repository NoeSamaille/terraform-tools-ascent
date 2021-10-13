provider "helm" {
  kubernetes {
    config_path = var.cluster_config_file
  }
}
provider "ibm" {
  ibmcloud_api_key = var.ibmcloud_api_key
}