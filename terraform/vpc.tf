data "yandex_vpc_network" "default" {
  folder_id = var.folder_id
  name      = "default"
}