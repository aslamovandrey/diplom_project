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

# Облачная сеть
resource "yandex_vpc_network" "messenger-network" {
  name = "messenger-network"
}

# Публичная подсеть (для бастиона) - зона A
resource "yandex_vpc_subnet" "public" {
  name           = "public-subnet"
  zone           = "ru-central1-d"
  network_id     = yandex_vpc_network.messenger-network.id
  v4_cidr_blocks = ["10.3.0.0/24"]
}

# NAT шлюзы для каждой приватной подсети (доступ в интернет)
resource "yandex_vpc_gateway" "nat_gateway_a" {
  name = "nat-gateway-zone-a"
  shared_egress_gateway {}
}

# Таблицы маршрутов для приватных подсетей через NAT шлюзы
resource "yandex_vpc_route_table" "private_route_a" {
  name       = "private-route-table-zone-a"
  network_id = yandex_vpc_network.messenger-network.id

  static_route {
    destination_prefix = "0.0.0.0/0"
    gateway_id         = yandex_vpc_gateway.nat_gateway_a.id
  }
}

# Привязываем таблицы маршрутов к подсетям
resource "yandex_vpc_subnet" "master-subnet" {
  name           = "master-subnet"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.messenger-network.id
  v4_cidr_blocks = ["10.1.0.0/24"]
  route_table_id = yandex_vpc_route_table.private_route_a.id
}

# ========================
# Группы безопасности
# ========================

# Создание группы безопасности
resource "yandex_vpc_security_group" "postfres-sg" {
  name        = "postfres-sg"
  description = "Security group for postfres"
  network_id  = yandex_vpc_network.messenger-network.id

  # Правило для Jenkins
  ingress {
    protocol    = "TCP"
    description = "Jenkins"
    port        = 8080
    v4_cidr_blocks = ["185.170.55.250/32"] # В учебных целях открываем всем. В проде - ограничить по IP.
  }

  # Правило для SSH
  ingress {
    protocol    = "TCP"
    description = "SSH"
    port        = 22
    v4_cidr_blocks = ["185.170.55.250/32"] # В учебных целях открываем всем. В проде - ограничить по IP.
  }

  # Правило для приложения
  ingress {
    protocol    = "TCP"
    description = "App"
    port        = 5432

    v4_cidr_blocks = [
      "10.4.0.0/24", # Kubernetes
      "10.3.0.0/24",
      "10.112.0.0/16" # CIDR Pod'ов
  ]
  }

  # Правило для Patroni REST API
  ingress {
    protocol    = "TCP"
    description = "Patroni_API"
    port        = 8008
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  # Правило для etcd (клиент)
  ingress {
    protocol    = "TCP"
    description = "etcd_c"
    port        = 2379
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  # Правило для etcd (peer)
  ingress {
    protocol    = "TCP"
    description = "etcd_p"
    port        = 2380
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  # Разрешаем ICMP (ping) для диагностики
  ingress {
    protocol          = "ICMP"
    description       = "Allow ICMP for diagnostics"
    predefined_target = "self_security_group"  # Это разрешает пинговать друг друга
  }

  # Разрешаем весь TCP/UDP трафик внутри группы (для PostgreSQL, Patroni API и т.д.)
  ingress {
    protocol          = "TCP"
    description       = "Allow all TCP traffic within the security group"
    predefined_target = "self_security_group"
    from_port         = 0
    to_port           = 65535
  }

  ingress {
    protocol          = "UDP"
    description       = "Allow all UDP traffic within the security group"
    predefined_target = "self_security_group"
    from_port         = 0
    to_port           = 65535
  }

  # Исходящий трафик (обычно разрешаем весь)
  egress {
    protocol       = "ANY"
    description    = "Allow all outgoing traffic"
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 0
    to_port        = 65535
  }

  # Разрешаем весь исходящий трафик
  egress {
    protocol       = "ANY"
    description    = "Allow all egress"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

data "yandex_compute_image" "ubuntu" {
  family = "ubuntu-2204-lts"
}

resource "yandex_compute_instance" "postgres-master" {
  name        = "postgres-master"
  platform_id = "standard-v3"
  zone        = var.cloud_zone

  resources {
    cores  = 2
    memory = 4
    core_fraction = 50
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      size     = 20
      type     = "network-hdd"
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.master-subnet.id
    nat       = false # В приватной сети без публичного IP
    ip_address = "10.1.0.11"

    security_group_ids = [
      yandex_vpc_security_group.postfres-sg.id,
    ]
  }

  metadata = {
    user-data = <<-EOF
      #cloud-config
      users:
        - name: andrew
          groups: sudo
          shell: /bin/bash
          sudo: 'ALL=(ALL) NOPASSWD:ALL'
          ssh_authorized_keys:
            - "${file("~/.ssh/id_rsa.pub")}"  # Путь к публичному ключу
    EOF
  }
}

resource "yandex_compute_instance" "arbitr" { # ... минимальная конфигурация для arbitr
  name        = "arbitr"
  platform_id = "standard-v3"
  zone        = var.cloud_zone_geo

  resources {
    cores  = 2
    memory = 2
    core_fraction = 20
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      size     = 15
      type     = "network-hdd"
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.public.id
    nat        = true # Публичный IP
    ip_address = "10.3.0.13"
    
    security_group_ids = [
      yandex_vpc_security_group.postfres-sg.id,
      # можно добавить несколько групп:
      # yandex_vpc_security_group.ssh_sg.id,
      # yandex_vpc_security_group.monitoring_sg.id,
    ]
  }

  metadata = {
    user-data = <<-EOF
      #cloud-config
      users:
        - name: andrew
          groups: sudo
          shell: /bin/bash
          sudo: 'ALL=(ALL) NOPASSWD:ALL'
          ssh_authorized_keys:
            - "${file("~/.ssh/id_rsa.pub")}"  # Путь к публичному ключу
    EOF
  }
}