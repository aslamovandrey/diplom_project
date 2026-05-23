terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
  required_version = ">= 0.13"
}

provider "yandex" {
  zone                     = var.cloud_zone  #"ru-central1-a" # Зона доступности по умолчанию
  cloud_id                 = var.cloud_id
  folder_id                = var.folder_id
  service_account_key_file = var.sa_key_file
}

# ============================================
# KUBERNETES CLUSTER MODULE
# ============================================

# sg

resource "yandex_vpc_security_group" "k8s-main-sg" {
  name       = "k8s-security-group"
  folder_id  = var.folder_id
  network_id = data.yandex_vpc_network.default.id

  # Разрешаем доступ к API Kubernetes (kubectl) только с вашего IP
  ingress {
    protocol       = "TCP"
    description    = "Allow kubectl access from my IP"
    v4_cidr_blocks = ["185.170.55.225/32"] # Замените на ваш реальный IP
    port           = 6443
  }
  # Разрешаем доступ к API Kubernetes (kubectl) только с вашего IP по 443
  ingress {
    protocol       = "TCP"
    description    = "Allow kubectl access from my IP 443"
    v4_cidr_blocks = ["185.170.55.225/32"] # Замените на ваш реальный IP
    port           = 443
  }
  # Разрешаем SSH доступ (если нужен)
  ingress {
    protocol       = "TCP"
    description    = "Allow SSH"
    v4_cidr_blocks = ["185.170.55.225/32"]
    port           = 22
  }

  # Обязательное правило для работы внутри кластера (между узлами и мастером)
  ingress {
    protocol          = "ANY"
    description       = "Self-referencing rule for cluster communication"
    v4_cidr_blocks = ["10.1.0.0/24"]
#    predefined_target = "self_assign"
    from_port         = 0
    to_port           = 65535
  }

  # Разрешаем весь исходящий трафик (чтобы узлы могли качать обновления/образы)
  egress {
    protocol       = "ANY"
    description    = "Allow all outbound traffic"
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 0
    to_port        = 65535
  }
}

# kuber
resource "yandex_kubernetes_cluster" "k8s-cluster" {
  name        = "messenger-k8s-cluster"
  node_service_account_id = yandex_iam_service_account.node-sa.id
  service_account_id = yandex_iam_service_account.k8s-sa.id
  network_id = data.yandex_vpc_network.default.id
  folder_id = var.folder_id

  master {
    version = "1.33"
    public_ip = true
    zonal {
      zone      = yandex_vpc_subnet.k8s-subnet.zone
      subnet_id = yandex_vpc_subnet.k8s-subnet.id
    }
    # ПРИВЯЗКА ГРУППЫ БЕЗОПАСНОСТИ
    security_group_ids = [yandex_vpc_security_group.k8s-main-sg.id]
  }

  depends_on = [
    yandex_resourcemanager_folder_iam_member.k8s-agent,
    yandex_resourcemanager_folder_iam_member.vpc-admin
  ]
}

# node-group 
resource "yandex_kubernetes_node_group" "k8s-node-group" {
  cluster_id = yandex_kubernetes_cluster.k8s-cluster.id
  name       = "main-node-group"
  version    = "1.28"

  instance_template {
    platform_id = "standard-v3"
    network_interface {
      nat        = true
      subnet_ids = [yandex_vpc_subnet.k8s-subnet.id]
      security_group_ids = [yandex_vpc_security_group.k8s-main-sg.id]
    }

    resources {
      cores         = 2
      memory        = 8
      core_fraction = 50
    }

    boot_disk {
      type = "network-ssd"
      size = 32
    }
  }

  scale_policy {
    fixed_scale {
      size = 2
    }
  }

  allocation_policy {
    location {
      zone = var.cloud_zone
    }
  }
}