variable "prefix" {
  description = "Prefijo para los recursos"
  type        = string
  default     = "microstore"
  
  validation {
    condition     = length(var.prefix) <= 10 && can(regex("^[a-z0-9]+$", var.prefix))
    error_message = "El prefijo debe tener máximo 10 caracteres y solo contener letras minúsculas y números."
  }
}

variable "environment" {
  description = "Entorno de despliegue"
  type        = string
  default     = "dev"
  
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "El entorno debe ser uno de: dev, staging, prod."
  }
}

variable "resource_group_name" {
  description = "Nombre del Resource Group"
  type        = string
  default     = "rg-microstore-dev"
}

variable "location" {
  description = "Región de Azure"
  type        = string
  default     = "eastus2"
  
  validation {
    condition = contains([
      "East US", "eastus2", "East US 2", "West US", "West US 2", "West US 3",
      "Central US", "South Central US", "West Central US", "North Central US",
      "West Europe", "North Europe", "UK South", "France Central"
    ], var.location)
    error_message = "La región debe ser una región válida de Azure."
  }
}

variable "aks_cluster_name" {
  description = "Nombre del cluster AKS"
  type        = string
  default     = "aks-microstore-cluster"
}

variable "kubernetes_version" {
  description = "Versión de Kubernetes"
  type        = string
  default     = "1.33.0"
}

variable "node_count" {
  description = "Número de nodos en el pool por defecto"
  type        = number
  default     = 2
  
  validation {
    condition     = var.node_count >= 1 && var.node_count <= 10
    error_message = "El número de nodos debe estar entre 1 y 10."
  }
}

variable "vm_size" {
  description = "Tamaño de las VMs para los nodos"
  type        = string
  default     = "Standard_B2s"
  
  validation {
    condition = contains([
      "Standard_B2s", "Standard_B4ms", "Standard_DS2_v2", 
      "Standard_DS3_v2", "Standard_D2s_v3", "Standard_D4s_v3"
    ], var.vm_size)
    error_message = "El tamaño de VM debe ser uno de los tipos soportados."
  }
}

variable "enable_auto_scaling" {
  description = "Habilitar auto-scaling en el cluster"
  type        = bool
  default     = true
}

variable "min_node_count" {
  description = "Número mínimo de nodos para auto-scaling"
  type        = number
  default     = 1
}

variable "max_node_count" {
  description = "Número máximo de nodos para auto-scaling"
  type        = number
  default     = 5
}
