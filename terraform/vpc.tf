data "yandex_vpc_network" "default" {
  folder_id = var.folder_id
  name      = "default"
}

resource "yandex_vpc_subnet" "k8s-subnet" {
  folder_id      = var.folder_id
  v4_cidr_blocks = ["10.1.0.0/24"]
  zone           = var.cloud_zone
  network_id     = data.yandex_vpc_network.default.id
}