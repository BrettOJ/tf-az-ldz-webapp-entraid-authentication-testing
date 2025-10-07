# Variables for Azure Web App with Entra ID Authentication

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  default     = "rg-webapp-entraid-demo"
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "Southeast Asia"
}

variable "app_service_plan_name" {
  description = "Name of the App Service Plan"
  type        = string
  default     = "asp-webapp-entraid-demo"
}

variable "web_app_name" {
  description = "Name of the Web App (must be globally unique)"
  type        = string
  default     = "webapp-entraid-demo"
}

variable "app_registration_name" {
  description = "Name of the Azure AD App Registration"
  type        = string
  default     = "webapp-entraid-demo-app"
}

variable "entra_group_name" {
  description = "Name of the Entra ID group for authorized users"
  type        = string
  default     = "webapp-users-group"
}

variable "app_service_plan_sku" {
  description = "SKU for the App Service Plan"
  type        = string
  default     = "F1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default = {
    Environment = "dev"
    Project     = "webapp-entraid-demo"
    ManagedBy   = "terraform"
  }
}