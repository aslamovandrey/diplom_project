# Аккаунт для управления ресурсами (мастер-нода)
resource "yandex_iam_service_account" "k8s-sa" {
  name      = "k8s-manager"
  folder_id = var.folder_id
}

# Права для управления кластером
resource "yandex_resourcemanager_folder_iam_member" "k8s-agent" {
  folder_id = var.folder_id
  role      = "k8s.clusters.agent"
  member    = "serviceAccount:${yandex_iam_service_account.k8s-sa.id}"
}

locals {
  k8s_manager_roles = [
    "editor",
    "k8s.clusters.agent",
    "vpc.publicAdmin",
    "container-registry.images.puller",
    "container-registry.images.pusher",
    "load-balancer.admin"
  ]
}

resource "yandex_resourcemanager_folder_iam_member" "k8s_manager_roles" {
  for_each = toset(local.k8s_manager_roles)

  folder_id = var.folder_id
  role      = each.value
  member    = "serviceAccount:${yandex_iam_service_account.k8s-sa.id}"
}

locals {
  node_roles = [
    "container-registry.images.puller"
  ]
}

resource "yandex_resourcemanager_folder_iam_member" "node_roles" {
  for_each = toset(local.node_roles)

  folder_id = var.folder_id
  role      = each.value
  member    = "serviceAccount:${yandex_iam_service_account.node-sa.id}"
}

# Права для управления сетью
resource "yandex_resourcemanager_folder_iam_member" "vpc-admin" {
  folder_id = var.folder_id
  role      = "vpc.publicAdmin"
  member    = "serviceAccount:${yandex_iam_service_account.k8s-sa.id}"
}

# Аккаунт для узлов (скачивание образов)
resource "yandex_iam_service_account" "node-sa" {
  name      = "k8s-node-sa"
  folder_id = var.folder_id
}

resource "yandex_resourcemanager_folder_iam_member" "images-puller" {
  folder_id = var.folder_id
  role      = "container-registry.images.puller"
  member    = "serviceAccount:${yandex_iam_service_account.node-sa.id}"
}