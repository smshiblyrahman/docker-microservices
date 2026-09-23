terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.90"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.47"
    }
  }
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = false
      recover_soft_deleted_key_vaults = true
    }
  }
}

data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

# Virtual Network & Subnets for Network Isolation
resource "azurerm_virtual_network" "vnet" {
  name                = "${var.prefix}-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = var.tags
}

resource "azurerm_subnet" "aks_subnet" {
  name                 = "aks-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_subnet" "pe_subnet" {
  name                                          = "private-endpoints-subnet"
  resource_group_name                           = azurerm_resource_group.rg.name
  virtual_network_name                          = azurerm_virtual_network.vnet.name
  address_prefixes                              = ["10.0.2.0/24"]
  private_endpoint_network_policies_enabled     = true
}

# NSG on AKS Subnet restricting egress to Azure Key Vault & internal
resource "azurerm_network_security_group" "aks_nsg" {
  name                = "${var.prefix}-aks-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "Allow-HTTPS-Outbound"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "10.0.1.0/24"
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "Deny-Internet-Direct-Database"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["5432", "3306", "1433"]
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  tags = var.tags
}

resource "azurerm_subnet_network_security_group_association" "aks_assoc" {
  subnet_id                 = azurerm_subnet.aks_subnet.id
  network_security_group_id = azurerm_network_security_group.aks_nsg.id
}

# Hardened Azure Key Vault
resource "azurerm_key_vault" "kv" {
  name                        = "${var.prefix}-kv-${var.environment}"
  location                    = azurerm_resource_group.rg.location
  resource_group_name         = azurerm_resource_group.rg.name
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  sku_name                    = "standard"

  # AC-1: Soft-delete & Purge Protection
  soft_delete_retention_days  = 90
  purge_protection_enabled    = true

  # AC-1: RBAC authorization enabled
  enable_rbac_authorization   = true

  # AC-1: Public network access disabled
  public_network_access_enabled = false

  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
  }

  tags = var.tags
}

# Private DNS Zone for Key Vault
resource "azurerm_private_dns_zone" "vault_dns" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = azurerm_resource_group.rg.name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "vnet_link" {
  name                  = "${var.prefix}-vnet-link"
  resource_group_name   = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.vault_dns.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
}

# AC-2: Private Endpoint for Azure Key Vault
resource "azurerm_private_endpoint" "kv_pe" {
  name                = "${var.prefix}-kv-pe"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet_id           = azurerm_subnet.pe_subnet.id

  private_service_connection {
    name                           = "${var.prefix}-kv-psc"
    private_connection_resource_id = azurerm_key_vault.kv.id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "vault-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.vault_dns.id]
  }

  tags = var.tags
}

# User Assigned Managed Identity for AKS Workload Identity
resource "azurerm_user_assigned_identity" "workload_identity" {
  name                = "${var.prefix}-aks-workload-id"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  tags                = var.tags
}

# AC-1: Role Assignment: Key Vault Secrets User (Least Privilege)
resource "azurerm_role_assignment" "kv_secrets_user" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.workload_identity.principal_id
}

# Sample Secrets with automated rotation policy metadata
resource "azurerm_key_vault_secret" "db_password" {
  name         = "db-password"
  value        = "InitialDbPassword2026!#"
  key_vault_id = azurerm_key_vault.kv.id

  # Required for lifecycle management
  content_type = "text/plain"

  tags = {
    RotationIntervalDays = "60"
    Owner                = "database-team"
    Consumer             = "secure-vault-app"
  }

  depends_on = [azurerm_role_assignment.kv_secrets_user]
}

resource "azurerm_key_vault_secret" "api_key" {
  name         = "api-key"
  value        = "api-prod-live-token-secret-994"
  key_vault_id = azurerm_key_vault.kv.id

  tags = {
    RotationIntervalDays = "90"
    Owner                = "secops"
    Consumer             = "secure-vault-app"
  }

  depends_on = [azurerm_role_assignment.kv_secrets_user]
}
