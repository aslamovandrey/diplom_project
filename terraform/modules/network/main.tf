resource "yandex_vpc_network" "app-network" {
  name = var.network_name
}

resource "yandex_vpc_subnet" "public-subnet" {
  name           = "public-subnet"
  zone           = var.default_zone
  network_id     = yandex_vpc_network.app-network.id
  v4_cidr_blocks = ["192.168.10.0/24"]
}

resource "yandex_vpc_subnet" "private-subnet" {
  name           = "private-subnet"
  zone           = var.default_zone
  network_id     = yandex_vpc_network.app-network.id
  v4_cidr_blocks = ["192.168.20.0/24"]
  route_table_id = yandex_vpc_route_table.nat-route.id
}

# NAT для доступа из приватной сети в интернет
resource "yandex_vpc_gateway" "nat-gateway" {
  name = "nat-gateway"
  shared_egress_gateway {}
}

resource "yandex_vpc_route_table" "nat-route" {
  network_id = yandex_vpc_network.app-network.id
  route {
    destination_prefix = "0.0.0.0/0"
    next_hop_address   = yandex_vpc_gateway.nat-gateway.shared_egress_gateway.0.address
  }
}