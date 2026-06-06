# ============================================
# KUBERNETES CLUSTER MODULE
# ============================================

resource "yandex_vpc_subnet" "k8s-subnet" {
  folder_id      = var.folder_id
  v4_cidr_blocks = ["10.4.0.0/24"]
  zone           = var.cloud_zone
  network_id     = yandex_vpc_network.messenger-network.id
}

resource "yandex_vpc_security_group" "k8s-main-sg" {
  name       = "k8s-security-group"
  folder_id  = var.folder_id
  network_id = yandex_vpc_network.messenger-network.id

  ingress {
    protocol       = "TCP"
    port           = 22
    v4_cidr_blocks = ["185.170.55.250/32"]
  }

  ingress {
    protocol       = "TCP"
    port           = 6443
    v4_cidr_blocks = ["185.170.55.250/32"]
  }

  ingress {
    protocol       = "TCP"
    port           = 80
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol       = "TCP"
    port           = 443
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol       = "TCP"
    from_port      = 30000
    to_port        = 32767
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol       = "ANY"
    from_port      = 0
    to_port        = 65535
    v4_cidr_blocks = ["10.4.0.0/24"]
  }

  # Health checks
  ingress {
    protocol       = "TCP"
    port           = 10256
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol       = "ANY"
    from_port      = 0
    to_port        = 65535
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

# kuber
resource "yandex_kubernetes_cluster" "k8s-cluster" {
  name        = "messenger-k8s-cluster"
  node_service_account_id = yandex_iam_service_account.node-sa.id
  service_account_id = yandex_iam_service_account.k8s-sa.id
  network_id = yandex_vpc_network.messenger-network.id
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
  version    = "1.33"

  instance_template {
    platform_id = "standard-v3"
    network_interface {
      nat        = true
      subnet_ids = [yandex_vpc_subnet.k8s-subnet.id]
      security_group_ids = [yandex_vpc_security_group.k8s-main-sg.id]
    }

    resources {
      cores         = 2
      memory        = 4
      core_fraction = 50
    }

    boot_disk {
      type = "network-ssd"
      size = 32
    }
  }

  scale_policy {
    fixed_scale {
      size = 1
    }
  }

  allocation_policy {
    location {
      zone = var.cloud_zone
    }
  }
}
