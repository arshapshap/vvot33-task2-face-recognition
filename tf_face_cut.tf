resource "yandex_storage_bucket" "faces" {
  bucket = var.bucket_faces_name
  acl    = "private"
}

resource "yandex_function_trigger" "task-trigger" {
  name = var.trigger_task_name
  message_queue {
    queue_id        = yandex_message_queue.tasks.arn
    batch_cutoff    = 5
    batch_size      = 5
    service_account_id  = var.service_account_id
  }
  function {
    id                  = yandex_function.face-cut.id
    service_account_id  = var.service_account_id
  }
}

resource "archive_file" "zip-face-cut" {
  type          = "zip"
  source_dir    = "face_cut"
  output_path   = "face_cut.zip"
}

resource "yandex_function" "face-cut" {
  name                  = var.function_face_cut_name
  runtime               = "python312"
  entrypoint            = "index.handler"
  user_hash             = "sha256:${filemd5("face_cut.zip")}"
  memory                = 512
  execution_timeout     = 20
  service_account_id    = var.service_account_id
  environment = {
    PHOTOS_BUCKET   = yandex_storage_bucket.photos.bucket
    FACES_BUCKET    = yandex_storage_bucket.faces.bucket
    YDB_URL         = "grpcs://${yandex_ydb_database_serverless.db-photo-face.ydb_api_endpoint}"
    YDB_DATABASE    = yandex_ydb_database_serverless.db-photo-face.database_path
  }
  content {
    zip_filename = "face_cut.zip"
  }
  mounts {
    name = var.bucket_photos_name
    mode = "ro"
    object_storage {
      bucket = yandex_storage_bucket.photos.bucket
    }
  }
  mounts {
    name = var.bucket_faces_name
    mode = "rw"
    object_storage {
      bucket = yandex_storage_bucket.faces.bucket
    }
  }
  depends_on = [archive_file.zip-face-cut]
}