# Ascent terraform module

Installs the ASCENT tool into the cluster.

## Software dependencies

The module depends on the following software components:
- MongoDB
- Ascent Backend-For-Frontend
- Ascent UI
- IBM Cloud Object Storage

### Command-line tools

- terraform - `>= v0.13.0`
- kubectl

### Terraform providers

- IBM Cloud provider `>= 1.22.0`
- Helm provider `>= 1.1.1` (provided by Terraform)

## Module dependencies

This module makes use of the output from other modules:

- Cluster - github.com/cloud-native-toolkit/terraform-k8s-ocp-cluster
- Namespace - github.com/cloud-native-toolkit/terraform-k8s-namespace
- IBM Cloud Object Storage - github.com/cloud-native-toolkit/terraform-ibm-object-storage

## Example usage

```hcl-terraform
module "dev_tools_ascent" {
  source = "github.com/ibm-garage-cloud/terraform-tools-ascent.git"

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
```

