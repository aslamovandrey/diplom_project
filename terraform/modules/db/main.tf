data "yandex_compute_image" "ubuntu" {
  family = "ubuntu-2004-lts"
}

resource "yandex_compute_instance" "postgres-master" {
  name        = "postgres-master"
  platform_id = "standard-v3"
  zone        = var.default_zone

  resources {
    cores  = 2
    memory = 4
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      size     = 20
    }
  }

  network_interface {
    subnet_id = var.private_subnet_id
    nat       = false # В приватной сети без публичного IP
  }

  metadata = {
    ssh-keys = "ubuntu:${file(var.public_ssh_key_path)}"
  }
}

resource "yandex_compute_instance" "postgres-replica" { # ... аналогичная конфигурация для replica
  name        = "postgres-replica"
  platform_id = "standard-v3"
  zone        = var.default_zone

  resources {
    cores  = 2
    memory = 4
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      size     = 20
    }
  }

  network_interface {
    subnet_id = var.private_subnet_id
    nat       = false # В приватной сети без публичного IP
  }

  metadata = {
    ssh-keys = "ubuntu:${file(var.public_ssh_key_path)}"
  }
}