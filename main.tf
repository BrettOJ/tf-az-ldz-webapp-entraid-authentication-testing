
terraform {
  required_version = ">= 1.9.7"
}
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.9.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = ">= 3.0.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.5.0"
    }
  }
}

provider "azurerm" {
  storage_use_azuread = false
  use_msi             = false
  tenant_id           = "f3c9952d-3ea5-4539-bd9a-7e1093f8a1b6" #konjur tenant id
  subscription_id     = "95328200-66a3-438f-9641-aeeb101e5e37"
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

provider "azuread" {
  tenant_id = "f3c9952d-3ea5-4539-bd9a-7e1093f8a1b6"
}

# Resource Group
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
  tags     = local.tags
}

# Create Entra ID Group for authorized users
resource "azuread_group" "webapp_users" {
  display_name     = var.entra_group_name
  description      = "Group for users authorized to access the web application"
  owners           = [data.azurerm_client_config.current.object_id]
  security_enabled = true

  # Optional: Add members to the group
  # members = [
  #   "user-object-id-1",
  #   "user-object-id-2"
  # ]
}

# Create Azure AD Application Registration
resource "azuread_application" "webapp" {
  display_name            = var.app_registration_name
  description             = "Application registration for web app with Entra ID authentication"
  owners                  = [data.azurerm_client_config.current.object_id]
  sign_in_audience        = "AzureADMyOrg"
  group_membership_claims = ["SecurityGroup"]

  # Required resource access for Microsoft Graph
  required_resource_access {
    resource_app_id = "00000003-0000-0000-c000-000000000000" # Microsoft Graph

    resource_access {
      id   = "e1fe6dd8-ba31-4d61-89e7-88639da4683d" # User.Read
      type = "Scope"
    }

    resource_access {
      id   = "5f8c59db-677d-42c8-9acd-d6b652414e9d" # Group.Read.All
      type = "Scope"
    }
  }

  # Web application configuration
  web {
    redirect_uris = [
      "https://${var.web_app_name}.azurewebsites.net/.auth/login/aad/callback"
    ]

    implicit_grant {
      access_token_issuance_enabled = false
      id_token_issuance_enabled     = true
    }
  }

  # Optional claims for group membership
  optional_claims {
    id_token {
      name = "groups"
    }
    access_token {
      name = "groups"
    }
  }
}

# Create Service Principal
resource "azuread_service_principal" "webapp" {
  client_id                    = azuread_application.webapp.client_id
  app_role_assignment_required = false
  owners                       = [data.azurerm_client_config.current.object_id]

  tags = ["webapp", "authentication", "terraform"]
}

# Create Application Password (Client Secret)
resource "azuread_application_password" "webapp" {
  application_id = azuread_application.webapp.id
  display_name   = "WebApp Client Secret"
  
  # Set expiration to 2 years
  end_date = timeadd(timestamp(), "17520h") # 2 years in hours
}

# App Service Plan
resource "azurerm_service_plan" "main" {
  name                = var.app_service_plan_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  os_type             = "Linux"
  sku_name            = var.app_service_plan_sku
  tags                = local.tags
}

# Linux Web App
resource "azurerm_linux_web_app" "main" {
  name                = var.web_app_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_service_plan.main.location
  service_plan_id     = azurerm_service_plan.main.id
  tags                = local.tags

  site_config {
    always_on = false

    application_stack {
      node_version = "18-lts"
    }

    # Enable HTTPS only
    ftps_state = "Disabled"
  }

  # Configure Entra ID Authentication
  auth_settings_v2 {
    auth_enabled                     = true
    require_authentication           = true
    unauthenticated_action          = "RedirectToLoginPage"
    default_provider                = "azureactivedirectory"
    excluded_paths                  = []
    require_https                   = true
    runtime_version                 = "~1"
    forward_proxy_convention        = "NoProxy"

    login {
      token_store_enabled               = true
      preserve_url_fragments_for_logins = false
      allowed_external_redirect_urls    = []
      cookie_expiration_convention      = "FixedTime"
      cookie_expiration_time            = "08:00:00"
      validate_nonce                    = true
    }

    active_directory_v2 {
      client_id                    = azuread_application.webapp.client_id
      tenant_auth_endpoint         = "https://login.microsoftonline.com/${data.azurerm_client_config.current.tenant_id}/v2.0"
      client_secret_setting_name   = "MICROSOFT_PROVIDER_AUTHENTICATION_SECRET"
      jwt_allowed_groups           = []
      jwt_allowed_client_applications = []
      www_authentication_disabled  = false
      allowed_groups               = [azuread_group.webapp_users.object_id]
      allowed_identities           = []
      allowed_applications         = []
      login_parameters             = {}
      allowed_audiences            = ["api://${azuread_application.webapp.client_id}"]
    }
  }

  # Application settings
  app_settings = {
    "MICROSOFT_PROVIDER_AUTHENTICATION_SECRET" = azuread_application_password.webapp.value
    "WEBSITE_AUTH_AAD_ACL"                     = jsonencode([{
      groupObjectId = azuread_group.webapp_users.object_id
      accessType    = "allow"
    }])
    
    # Additional security settings
    "WEBSITE_LOAD_CERTIFICATES"          = "*"
    "WEBSITE_RUN_FROM_PACKAGE"           = "1"
  }

  # Connection strings (if needed for database connections)
  # connection_string {
  #   name  = "DefaultConnection"
  #   type  = "SQLAzure"
  #   value = "connection-string-here"
  # }

  https_only = true

  identity {
    type = "SystemAssigned"
  }

  logs {
    detailed_error_messages = true
    failed_request_tracing  = true

    application_logs {
      file_system_level = "Information"
    }

    http_logs {
      file_system {
        retention_in_days = 7
        retention_in_mb   = 35
      }
    }
  }
}

# Optional: Custom domain and SSL certificate
# resource "azurerm_app_service_custom_hostname_binding" "main" {
#   hostname            = "your-custom-domain.com"
#   app_service_name    = azurerm_linux_web_app.main.name
#   resource_group_name = azurerm_resource_group.main.name
# }

# Optional: Application Insights for monitoring
/*resource "azurerm_application_insights" "main" {
  name                = "appi-${var.web_app_name}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  application_type    = "web"
  workspace_id        = "/subscriptions/95328200-66a3-438f-9641-aeeb101e5e37/resourceGroups/ai_appi-webapp-entraid-demo-dev-p8zyo6v8_02e149ca-f49b-4bc7-8bf0-d73bc403d372_managed/providers/Microsoft.OperationalInsights/workspaces/managed-appi-webapp-entraid-demo-dev-p8zyo6v8-ws"
  tags                = local.tags
}
*/
# Update Web App with Application Insights
/*resource "azurerm_linux_web_app_slot" "staging" {
  name           = "staging"
  app_service_id = azurerm_linux_web_app.main.id
  tags           = local.tags

  site_config {
    always_on = false

    application_stack {
      node_version = "18-lts"
    }
  }

  app_settings = {
    "APPINSIGHTS_INSTRUMENTATIONKEY"        = azurerm_application_insights.main.instrumentation_key
    "APPLICATIONINSIGHTS_CONNECTION_STRING" = azurerm_application_insights.main.connection_string
  }
}*/



