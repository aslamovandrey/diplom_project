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