module "cos" {
  source = "github.com/cloud-native-toolkit/terraform-ibm-object-storage.git"

  resource_group_name = var.resource_group_name
  name_prefix         = var.name_prefix
  provision           = var.cos_provision
  resource_location   = var.cos_resource_location
  ibmcloud_api_key = var.ibmcloud_api_key
}