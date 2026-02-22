terraform {
  required_providers {
    proxmox = {
      source = "registry.terraform.io/telmate/proxmox"
      version = "3.0.2-rc07" # Ou la version que tu as installée
    }
    local = {
      source  = "registry.terraform.io/hashicorp/local"
      version = "2.5.1"
    }
    null = {
      source  = "registry.terraform.io/hashicorp/null"
      version = "3.2.2"
    }
  }
}

provider "proxmox" {
  pm_api_url      = var.pm_api_url
  pm_user         = var.pm_user
  pm_password     = var.pm_password
  pm_tls_insecure = true
}

locals {
  # Génère une liste d'IPs en fonction de var.vm_count
  # Ex: ["172.16.20.1", "172.16.20.2"]
  vm_ips = [for i in range(var.vm_count) : "172.16.${var.pool_id}.${i + 1}"]
  proxmox_host = split(":", split("//", var.pm_api_url)[1])[0]
}

resource "proxmox_vm_qemu" "simulateur_vm" {
  count = var.vm_count
  target_node = var.target_node
  clone       = var.template_name
  boot = "order=scsi0"
  full_clone  = true
  depends_on = [null_resource.setup_proxmox_bridges]
  vmid = tonumber("${var.pool_id}0${count.index + 1}")
  name = "Noeud${var.pool_id}simulateur${format("%02d", count.index + 1)}"
  description = "Pool: PTF ${var.pool_id}"
  nameserver   = var.dns_server_ip
  searchdomain = "ptf${var.pool_id}.local"
  network {
    id     = 0
    model  = "virtio"
    bridge = "vmbr0"
  }
  dynamic "network" {
    for_each = var.bridge_suffixes
    content {
      id     = network.key + 1
      model  = "virtio"
      bridge = "vmbr${var.pool_id}${network.value}"
    }
  }
  disk {
    slot    = "scsi0"
    size    = "4G" 
    type    = "disk"
    storage = "local-lvm"
  }

  disk {
    slot    = "ide2"
    type    = "cloudinit"
    storage = "local-lvm"
  }
  serial {
    id   = 0
    type = "socket"
  }
  os_type = "cloud-init"
  cpu { 
    cores = 1 
    sockets = 1 
  }
  memory  = 2048
  scsihw  = "virtio-scsi-pci"
  ipconfig0 = "ip=${local.vm_ips[count.index]}/24,gw=172.16.${var.pool_id}.254"
  ciuser    = "user"
  sshkeys   = file("~/.ssh/id_rsa_terraform.pub")
}
output "infos_vms" {
  description = "Noms et adresses IP des VMs déployées"
  value = [
    for i, vm in proxmox_vm_qemu.simulateur_vm : {
      hostname = vm.name
      ip       = local.vm_ips[i]
    }
  ]
}

resource "local_file" "zone_dns_temporaire" {
  filename = "${path.module}/db.ptf${var.pool_id}.local"

  content = <<-EOT
$TTL 86400
@   IN  SOA ns1.ptf${var.pool_id}.local. admin.ptf${var.pool_id}.local. (
        2024010101 ; Serial
        3600       ; Refresh
        1800       ; Retry
        604800     ; Expire
        86400 )    ; Minimum TTL

    IN  NS  ns1.ptf${var.pool_id}.local.
ns1 IN  A   172.16.${var.pool_id}.254

; --- Machines Proxmox générées par OpenTofu ---
%{ for i, ip in local.vm_ips ~}
Noeud${var.pool_id}simulateur${format("%02d", i + 1)} IN A ${ip}
%{ endfor ~}
EOT
}

resource "null_resource" "push_vers_dns_distant" {
  
  triggers = {
    fichier_modifie = local_file.zone_dns_temporaire.id
    zone_name       = "ptf${var.pool_id}.local"
    zone_file       = "/etc/bind/db.ptf${var.pool_id}.local"
    dns_ip          = var.dns_server_ip
  }

  provisioner "local-exec" {
    command = <<-EOT
      scp -o StrictHostKeyChecking=no ${local_file.zone_dns_temporaire.filename} root@${self.triggers.dns_ip}:${self.triggers.zone_file}
      
      ssh -o StrictHostKeyChecking=no root@${self.triggers.dns_ip} '
        if ! grep -q "zone \"${self.triggers.zone_name}\"" /etc/bind/named.conf.local; then
          echo "" >> /etc/bind/named.conf.local
          echo "zone \"${self.triggers.zone_name}\" {" >> /etc/bind/named.conf.local
          echo "    type master;" >> /etc/bind/named.conf.local
          echo "    file \"${self.triggers.zone_file}\";" >> /etc/bind/named.conf.local
          echo "};" >> /etc/bind/named.conf.local
        fi
        systemctl reload bind9
      '
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      ssh -o StrictHostKeyChecking=no root@${self.triggers.dns_ip} '
        rm -f ${self.triggers.zone_file}
        sed -i "/zone \"${self.triggers.zone_name}\"/,+4d" /etc/bind/named.conf.local
        systemctl reload bind9
      '
    EOT
  }
}

resource "null_resource" "setup_proxmox_bridges" {
  for_each = toset(var.bridge_suffixes)

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]

    command = <<-EOT
      sleep $((RANDOM % 5))

      ssh -o StrictHostKeyChecking=no -o BatchMode=yes -T root@${local.proxmox_host} <<EOF
        BNAME="vmbr${var.pool_id}${each.value}"
        NODE="${var.target_node}"
        if ip link show "\$BNAME" > /dev/null 2>&1; then
          echo "Le bridge \$BNAME est déjà actif."
          exit 0
        fi
        echo "Tentative de configuration de \$BNAME..."
        pvesh create /nodes/\$NODE/network --iface "\$BNAME" --type bridge --autostart 1 || true
        if ! ifup "\$BNAME" 2>/dev/null; then
          echo "Application de la configuration réseau globale..."
          pvesh set /nodes/\$NODE/network
          ifup "\$BNAME" || true
        fi
EOF
    EOT
  }
}
