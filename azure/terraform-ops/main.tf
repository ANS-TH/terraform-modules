###########
# Azure AD
###########

resource "azuread_application" "main" {
  display_name = var.application_name
  owners       = [data.azurerm_client_config.current.object_id]

  required_resource_access {
    resource_app_id = data.azuread_application_published_app_ids.well_known.result.MicrosoftGraph

    dynamic "resource_access" {
      for_each = local.msgraph_roles
      iterator = scope

      content {
        id   = azuread_service_principal.msgraph.app_role_ids[scope.value]
        type = "Role"
      }
    }
  }
}

resource "azuread_service_principal" "main" {
  application_id = azuread_application.main.application_id
  description    = "Service principal used for Terraform tasks."

  app_role_assignment_required = false
  tags                         = ["Terraform"]
}

resource "azuread_group" "main" {
  display_name     = var.group_name
  description      = var.group_description
  security_enabled = true
}

resource "azurerm_role_assignment" "main_owner" {
  for_each = var.managed_scopes

  description          = "Allow group ${azuread_group.main.object_id} to own scope ${each.value}."
  principal_id         = azuread_group.main.object_id
  scope                = each.value
  role_definition_name = "Owner"

  skip_service_principal_aad_check = false
}

resource "azuread_group_member" "main_users_sp" {
  group_object_id  = azuread_group.main.id
  member_object_id = azuread_service_principal.main.object_id
}

resource "azuread_group_member" "main_current_user" {
  group_object_id  = azuread_group.main.id
  member_object_id = data.azurerm_client_config.current.object_id
}

resource "azuread_group_member" "main_users" {
  for_each = var.terraform_group_member_ids

  group_object_id  = azuread_group.main.id
  member_object_id = each.value
}

######################
# Resource Management
######################

resource "azurerm_role_assignment" "resource_group_contributor" {
  description          = "Provide group ${azuread_group.main.object_id} contributor access to this resource scope."
  principal_id         = azuread_group.main.object_id
  scope                = "${data.azurerm_subscription.current.id}/resourceGroups/${var.resource_group_name}"
  role_definition_name = "Contributor"

  skip_service_principal_aad_check = false
}

##########
# Storage
##########

#tfsec:ignore:azure-storage-queue-services-logging-enabled
resource "azurerm_storage_account" "main" {
  name                = var.storage_account_name
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags

  account_tier             = "Standard"
  account_replication_type = "GRS"

  min_tls_version = "TLS1_2"

  shared_access_key_enabled = var.enable_shared_access_key

  blob_properties {
    delete_retention_policy {
      days = 7
    }
  }
}

#tfsec:ignore:azure-storage-default-action-deny
resource "azurerm_storage_account_network_rules" "main" {
  storage_account_id = azurerm_storage_account.main.id

  default_action = local.default_acl_action
  bypass         = ["AzureServices", "Logging", "Metrics"]

  ip_rules                   = var.allowed_ips
  virtual_network_subnet_ids = var.allowed_subnet_ids
}

resource "azurerm_role_assignment" "main_group_blob_owner" {
  description          = "Provide group ${azuread_group.main.object_id} Storage Blob Data Owner access to ${azurerm_storage_account.main.name}."
  principal_id         = azuread_group.main.object_id
  scope                = azurerm_storage_account.main.id
  role_definition_name = "Storage Blob Data Owner"

  skip_service_principal_aad_check = false
}

resource "azurerm_storage_container" "main_state" {
  name                 = "tfstate"
  storage_account_name = azurerm_storage_account.main.name

  container_access_type = "private"

  depends_on = [azurerm_storage_account_network_rules.main, azurerm_role_assignment.main_group_blob_owner]
}

#tfsec:ignore:azure-keyvault-specify-network-acl tfsec:ignore:azure-keyvault-no-purge
resource "azurerm_key_vault" "main" {
  name                = var.key_vault_name
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags

  tenant_id = coalesce(var.managed_tenant_id, data.azurerm_client_config.current.tenant_id)
  sku_name  = "standard"

  purge_protection_enabled = var.enable_purge_protection

  network_acls {
    default_action = local.default_acl_action
    bypass         = "AzureServices"

    ip_rules                   = var.allowed_ips
    virtual_network_subnet_ids = var.allowed_subnet_ids
  }
}

resource "azurerm_role_assignment" "main_kv_admin" {
  description          = "Provide group ${azuread_group.main.object_id} Key Vault Administrator access to ${azurerm_key_vault.main.name}."
  principal_id         = azuread_group.main.object_id
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Administrator"

  skip_service_principal_aad_check = false
}

resource "azurerm_key_vault_access_policy" "main_admin" {
  key_vault_id = azurerm_key_vault.main.id

  tenant_id = azurerm_key_vault.main.tenant_id
  object_id = azuread_group.main.object_id

  certificate_permissions = [
    "Backup", "Create", "Delete", "DeleteIssuers",
    "Get", "GetIssuers", "Import", "List",
    "ListIssuers", "ManageContacts", "ManageIssuers", "Purge",
    "Recover", "Restore", "SetIssuers", "Update"
  ]

  key_permissions = [
    "Backup", "Create", "Decrypt", "Delete",
    "Encrypt", "Get", "Import", "List",
    "Purge", "Recover", "Restore", "Sign",
    "UnwrapKey", "Update", "Verify", "WrapKey"
  ]

  secret_permissions = [
    "Backup", "Delete", "Get", "List",
    "Purge", "Recover", "Restore", "Set"
  ]

  storage_permissions = [
    "Backup", "Delete", "DeleteSAS", "Get",
    "GetSAS", "List", "ListSAS", "Purge",
    "Recover", "RegenerateKey", "Restore", "Set",
    "SetSAS", "Update"
  ]
}
