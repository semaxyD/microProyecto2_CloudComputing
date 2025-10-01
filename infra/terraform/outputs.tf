output "resource_group_name" {
  description = "Nombre del Resource Group creado"
  value       = azurerm_resource_group.rg.name
}

output "resource_group_location" {
  description = "Ubicación del Resource Group"
  value       = azurerm_resource_group.rg.location
}

output "aks_cluster_name" {
  description = "Nombre del cluster AKS"
  value       = azurerm_kubernetes_cluster.aks.name
}

output "aks_cluster_id" {
  description = "ID del cluster AKS"
  value       = azurerm_kubernetes_cluster.aks.id
}

output "aks_fqdn" {
  description = "FQDN del cluster AKS"
  value       = azurerm_kubernetes_cluster.aks.fqdn
}

output "aks_node_resource_group" {
  description = "Resource Group de los nodos AKS"
  value       = azurerm_kubernetes_cluster.aks.node_resource_group
}

output "acr_name" {
  description = "Nombre del Azure Container Registry"
  value       = azurerm_container_registry.acr.name
}

output "acr_login_server" {
  description = "URL del servidor de login del ACR"
  value       = azurerm_container_registry.acr.login_server
}

output "acr_admin_username" {
  description = "Usuario administrador del ACR"
  value       = azurerm_container_registry.acr.admin_username
  sensitive   = true
}

output "acr_admin_password" {
  description = "Contraseña del administrador del ACR"
  value       = azurerm_container_registry.acr.admin_password
  sensitive   = true
}

output "log_analytics_workspace_id" {
  description = "ID del workspace de Log Analytics"
  value       = azurerm_log_analytics_workspace.law.id
}

output "log_analytics_workspace_name" {
  description = "Nombre del workspace de Log Analytics"
  value       = azurerm_log_analytics_workspace.law.name
}

output "kube_config" {
  description = "Configuración de kubectl para conectar al cluster"
  value       = azurerm_kubernetes_cluster.aks.kube_config_raw
  sensitive   = true
}

output "client_certificate" {
  description = "Certificado del cliente para autenticación"
  value       = azurerm_kubernetes_cluster.aks.kube_config[0].client_certificate
  sensitive   = true
}

output "client_key" {
  description = "Clave privada del cliente"
  value       = azurerm_kubernetes_cluster.aks.kube_config[0].client_key
  sensitive   = true
}

output "cluster_ca_certificate" {
  description = "Certificado CA del cluster"
  value       = azurerm_kubernetes_cluster.aks.kube_config[0].cluster_ca_certificate
  sensitive   = true
}

output "host" {
  description = "Endpoint del cluster Kubernetes"
  value       = azurerm_kubernetes_cluster.aks.kube_config[0].host
  sensitive   = true
}

# Comandos útiles para después del despliegue
output "kubectl_config_command" {
  description = "Comando para configurar kubectl"
  value       = "az aks get-credentials --resource-group ${azurerm_resource_group.rg.name} --name ${azurerm_kubernetes_cluster.aks.name}"
}

output "acr_login_command" {
  description = "Comando para hacer login al ACR"
  value       = "az acr login --name ${azurerm_container_registry.acr.name}"
}

output "docker_tag_example" {
  description = "Ejemplo de cómo tagear imágenes para el ACR"
  value       = "docker tag microstore-users:latest ${azurerm_container_registry.acr.login_server}/microstore-users:latest"
}
