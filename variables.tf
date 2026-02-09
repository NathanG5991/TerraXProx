variable "pm_api_url" {
  description = "URL de l'API Proxmox (ex: https://192.168.1.1:8006/api2/json)"
  type        = string
}

variable "pm_user" {
  description = "Utilisateur API (ex: root@pam)"
  type        = string
}

variable "pm_password" {
  description = "Mot de passe API"
  type        = string
  sensitive   = true
}

variable "target_node" {
  description = "Nom du noeud Proxmox (ex: pve)"
  type        = string
  default     = "pve"
}

variable "template_name" {
  description = "Nom du template VM à cloner"
  type        = string
  default     = "Template"
}

# --- TES VARIABLES SPÉCIFIQUES ---

variable "pool_id" {
  description = "Numéro du Pool (Le 'XX')"
  type        = number
  default     = 10
}

variable "vm_count" {
  description = "Nombre de machines à déployer"
  type        = number
  default     = 3
}
