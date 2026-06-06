variable "cloud_id" {
  type = string
}

variable "folder_id" {
  type = string
}

variable "sa_id" {
  type    = string
  default = "ajetkfecfttsqkhc02n9"
}

variable "node_service_account_id" {
  type    = string
  default = "aje7kqjn1605lsrbcda9"
}

variable "sa_key_file" {
  type = string
}

variable "cloud_zone" {
  type = string
  default = "ru-central1-a"
}

variable "cloud_zone_geo" {
  type = string
  default = "ru-central1-d"
}