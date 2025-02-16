terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
}

provider "yandex" {
  zone                     = "ru-central1-a"
  service_account_key_file = pathexpand("~/.yc-keys/key.json")
  cloud_id                 = var.cloud_id
  folder_id                = var.folder_id
}