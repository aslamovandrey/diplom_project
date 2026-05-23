data "yandex_iam_service_account" "current_user" {
  service_account_id = jsondecode(file(var.sa_key_file)).service_account_id
}

output "current_sa_name" {
  value = data.yandex_iam_service_account.current_user.name
}