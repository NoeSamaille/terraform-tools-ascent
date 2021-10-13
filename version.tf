terraform {
  required_providers {
    helm = {
      version = ">= 1.1.1"
    }
    ibm = {
      source = "ibm-cloud/ibm"
      version = ">= 1.22.0"
    }
  }
  required_version = ">= 0.13.0"
}
