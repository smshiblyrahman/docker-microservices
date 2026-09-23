variable "prefix" {
  description = "Resource prefix for naming convention"
  type        = string
  default     = "secops"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "prod"
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "switzerlandnorth"
}

variable "resource_group_name" {
  description = "Resource Group Name"
  type        = string
  default     = "rg-secops-keyvault-prod"
}

variable "tags" {
  description = "Tags applied to all infrastructure"
  type        = map(string)
  default = {
    Project     = "KeyVaultHardening"
    Environment = "Production"
    ManagedBy   = "Terraform"
    Compliance  = "ZeroTrust"
  }
}
