# Common data sources and locals

# Get current client configuration
data "azurerm_client_config" "current" {}

locals {
  tags = {
    environment = "test"
    project     = "my-project"
    owner       = "my-owner"
  }
}