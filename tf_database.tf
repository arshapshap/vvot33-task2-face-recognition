resource "yandex_ydb_database_serverless" "db-photo-face" {
  name                = var.db_name
  deletion_protection = false

  serverless_database {
    enable_throttling_rcu_limit = false
    provisioned_rcu_limit       = 10
    storage_size_limit          = 50
    throttling_rcu_limit        = 0
  }
}


resource "yandex_ydb_table" "user_states" {
  path              = "user_states"
  connection_string = yandex_ydb_database_serverless.db-photo-face.ydb_full_endpoint

  column {
    name     = "chat_id"
    type     = "String"
    not_null = true
  }

  column {
    name     = "state"
    type     = "String"
    not_null = true
  }

  column {
    name     = "last_face_key"
    type     = "String"
    not_null = false
  }

  primary_key = ["chat_id"]
}


resource "yandex_ydb_table" "faces" {
  path              = "faces"
  connection_string = yandex_ydb_database_serverless.db-photo-face.ydb_full_endpoint

  column {
    name     = "face_key"
    type     = "String"
    not_null = true
  }

  column {
    name     = "name"
    type     = "String"
    not_null = false
  }

  primary_key = ["face_key"]
}