variable "cluster_config_file" {
  type        = string
  description = "Cluster config file for Kubernetes cluster."
}

variable "releases_namespace" {
  type        = string
  description = "Name of the existing namespace where the Helm Releases will be deployed."
}

variable "cluster_ingress_hostname" {
  type        = string
  description = "Ingress hostname of the IKS cluster."
}

variable "cluster_type" {
  type        = string
  description = "The cluster type (openshift or ocp3 or ocp4 or kubernetes)"
}

variable "tool_config_maps" {
  type = list(string)
  description = "The list of config maps containing connectivity information for tools"
  default = []
}

variable "tls_secret_name" {
  type        = string
  description = "The name of the secret containing the tls certificate values"
  default     = ""
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

variable "ibmcloud_api_key" {
  type        = string
  description = "The IBM Cloud api token"
}

variable "cluster_name" {
  type        = string
  description = "The Name of the cluster"
}

variable "cos_instance_id" {
  type        = string
  description = "The Object Storage instance id"
}

variable "cos_instance_name" {
  type        = string
  description = "The Object Storage instance name"
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
