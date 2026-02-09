terraform {
  required_providers {
    proxmox = {
      source = "telmate/proxmox"
      version = "3.0.2-rc07" # Ou la version que tu as installée
    }
  }
}

provider "proxmox" {
  pm_api_url      = var.pm_api_url
  pm_user         = var.pm_user
  pm_password     = var.pm_password
  pm_tls_insecure = true
}

resource "proxmox_vm_qemu" "simulateur_vm" {
  count = var.vm_count

  target_node = var.target_node
  clone       = var.template_name
# On force le mode Full Clone pour avoir un disque autonome
  boot = "order=scsi0"
  full_clone  = true

  # On définit l'ordre de boot : Disque d'abord, réseau ensuite
  

  vmid = tonumber("${var.pool_id}0${count.index + 1}")
  name = "Noeud${var.pool_id}simulateur${format("%02d", count.index + 1)}"
  description = "Pool: PTF ${var.pool_id}"

  network {
    id = 0
    model  = "virtio"
    bridge = "vmbr0"
  }

  # --- CONFIGURATION DISQUE (Obligatoire pour éviter le 'Unused') ---
  disk {
    slot    = "scsi0"
    # METS ICI LA TAILLE EXACTE DE TON TEMPLATE (ex: "32G" ou "20G")
    size    = "4G" 
    type    = "disk"
    storage = "local-lvm"
  }

  disk {
    slot    = "ide2"
    type    = "cloudinit"
    storage = "local-lvm"
  }
  
# --- LE SECRET EST ICI (Console Série) ---
  # Sans ça, Cloud-Init attend un écran qui n'existe pas et ne met pas l'IP.
  serial {
    id   = 0
    type = "socket"
  }

  # --- CONFIGURATION RÉSEAU ET CLOUD-INIT ---
  os_type = "cloud-init"
  cpu { 
    cores = 1 
    sockets = 1 
  }
  memory  = 2048
  scsihw  = "virtio-scsi-pci"

  # C'est ici que l'IP est définie. 
  # Terraform va générer un petit lecteur CD attaché à la VM avec ce fichier.
  ipconfig0 = "ip=172.16.${var.pool_id}.${count.index + 1}/24,gw=172.16.${var.pool_id}.254"
  
  ciuser    = "user"
  sshkeys   = file("~/.ssh/id_rsa_terraform.pub")
}
