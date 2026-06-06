resource "yandex_container_registry" "ajax_registry" {

  name = "ajax-registry"
}

resource "yandex_container_registry_iam_binding" "k8s_pull" {

  registry_id = yandex_container_registry.ajax_registry.id

  role = "container-registry.images.puller"

  members = [
    "serviceAccount:${var.node_service_account_id}"
  ]
}