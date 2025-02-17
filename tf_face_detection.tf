resource "yandex_iam_service_account_static_access_key" "sa-static-key" {
  service_account_id = var.service_account_id
  description        = "static access key for object storage"
}

resource "yandex_storage_bucket" "photos" {
  bucket = var.bucket_photos_name
  acl    = "private"
}

resource "yandex_message_queue" "tasks" {
  name              = var.queue_tasks_name
  access_key        = yandex_iam_service_account_static_access_key.sa-static-key.access_key
  secret_key        = yandex_iam_service_account_static_access_key.sa-static-key.secret_key
}

resource "yandex_function_trigger" "photo-trigger" {
  name = var.trigger_photo_name
  object_storage {
    bucket_id       = yandex_storage_bucket.photos.id
    create          = true
    batch_cutoff    = 0
    batch_size      = 1
  }
  function {
    id                  = yandex_function.face-detection.id
    service_account_id  = var.service_account_id
  }
}

resource "archive_file" "zip-face-detection" {
  type          = "zip"
  source_dir    = "face_detection"
  output_path   = "face_detection.zip"
}

resource "yandex_function" "face-detection" {
  name                  = var.function_face_detection_name
  runtime               = "python312"
  entrypoint            = "index.handler"
  user_hash             = "sha256:${archive_file.zip-face-detection.output_base64sha256}"
  memory                = 512
  execution_timeout     = 20
  service_account_id    = var.service_account_id
  environment = {
    PHOTOS_BUCKET           = yandex_storage_bucket.photos.bucket
    QUEUE_URL               = yandex_message_queue.tasks.id
    AWS_ACCESS_KEY_ID       = yandex_iam_service_account_static_access_key.sa-static-key.access_key
    AWS_SECRET_ACCESS_KEY   = yandex_iam_service_account_static_access_key.sa-static-key.secret_key
  }
  content {
    zip_filename = "face_detection.zip"
  }
  mounts {
    name = var.bucket_photos_name
    mode = "ro"
    object_storage {
      bucket = yandex_storage_bucket.photos.bucket
    }
  }
  depends_on = [archive_file.zip-face-detection]
}