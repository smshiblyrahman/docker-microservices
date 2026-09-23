output "key_vault_id" {
  description = "Resource ID of hardened Azure Key Vault"
  value       = azurerm_key_vault.kv.id
}

output "key_vault_uri" {
  description = "Vault URI"
  value       = azurerm_key_vault.kv.vault_uri
}

output "private_endpoint_ip" {
  description = "Key Vault Private Endpoint IP"
  value       = azurerm_private_endpoint.kv_pe.private_service_connection[0].private_ip_address
}

output "workload_identity_client_id" {
  description = "Client ID for AKS Workload Identity ServiceAccount"
  value       = azurerm_user_assigned_identity.workload_identity.client_id
}
