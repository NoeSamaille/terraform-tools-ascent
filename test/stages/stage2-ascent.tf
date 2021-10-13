module "dev_tools_ascent" {
  source = "./module"

  cluster_config_file       = module.dev_cluster.config_file_path
  releases_namespace        = module.dev_tools_namespace.name
  cluster_ingress_hostname  = module.dev_cluster.ingress_hostname
  ibmcloud_api_key          = var.ibmcloud_api_key
  cluster_name              = module.dev_cluster.name
  cluster_type              = module.dev_cluster.type_code
  cos_instance_id           = module.cos.id
  cos_instance_name         = module.cos.name
  cos_bucket_storage_class  = var.cos_bucket_storage_class
  cos_bucket_cross_region_location  = var.cos_bucket_cross_region_location
}
