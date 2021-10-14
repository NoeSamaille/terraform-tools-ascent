
# Resource Group Variables
variable "resource_group_name" {
  type        = string
  description = "Existing resource group where the IKS cluster will be provisioned."
}

variable "ibmcloud_api_key" {
  type        = string
  description = "The api key for IBM Cloud access"
}

variable "region" {
  type        = string
  description = "Region for VLANs defined in private_vlan_number and public_vlan_number."
}

variable "namespace" {
  type        = string
  description = "Namespace for tools"
}

variable "cluster_name" {
  type        = string
  description = "The name of the cluster"
  default     = ""
}

variable "cluster_type" {
  type        = string
  description = "The type of cluster that should be created (openshift or kubernetes)"
}

variable "cluster_exists" {
  type        = string
  description = "Flag indicating if the cluster already exists (true or false)"
  default     = "true"
}

variable "name_prefix" {
  type        = string
  description = "Prefix name that should be used for the cluster and services. If not provided then resource_group_name will be used"
  default     = ""
}

variable "vpc_cluster" {
  type        = bool
  description = "Flag indicating that this is a vpc cluster"
  default     = false
}

variable "gitops_dir" {
  type        = string
  description = "Directory where the gitops repo content should be written"
  default     = ""
}

variable "mode" {
  type        = string
  description = "The mode of operation for the module (setup)"
  default     = ""
}

variable "cos_instance_id" {
  type        = string
  description = "The Object Storage instance id"
  default     = ""
}

variable "cos_instance_name" {
  type        = string
  description = "The Object Storage instance name"
  default     = ""
}

variable "cos_bucket_cross_region_location" {
  type        = string
  description = "Cross-regional bucket location. Supported values are us, eu, and ap."
  default     = "eu"
}

variable "cos_bucket_storage_class" {
  type        = string
  description = "The storage class that you want to use for the bucket. Supported values are standard, vault, cold, flex, and smart."
  default     = "standard"
}

variable "cos_provision" {
  type        = bool
  description = "Flag indicating that cos instance should be provisioned"
  default     = true
}

variable "cos_resource_location" {
  type        = string
  description = "Geographic location of the resource (e.g. us-south, us-east)"
  default     = "global"
}

variable "login_user" {
  type        = string
  description = "The username to log in to openshift"
  default     = ""
}

variable "login_password" {
  type        = string
  description = "The password to log in to openshift"
  default     = ""
}

variable "login_token" {
  type        = string
  description = "The token to log in to openshift"
  default     = ""
}

variable "server_url" {
  type        = string
  description = "The url to the server"
}