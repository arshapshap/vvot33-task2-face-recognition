resource "yandex_iam_service_account_static_access_key" "sa-static-key" {
  service_account_id = var.service_account_id
  description        = "static access key for object storage"
}

resource "yandex_storage_bucket" "photos" {
  bucket = "${var.prefix}-photos"
  acl    = "private"
}

# resource "yandex_storage_bucket" "faces" {
#   bucket = "${var.prefix}-faces"
#   acl    = "private"
# }

resource "yandex_message_queue" "tasks" {
  name              = "${var.prefix}-tasks"
  access_key        = yandex_iam_service_account_static_access_key.sa-static-key.access_key
  secret_key        = yandex_iam_service_account_static_access_key.sa-static-key.secret_key
}

resource "yandex_function_trigger" "photo-trigger" {
  name = "${var.prefix}-photo"
  object_storage {
    bucket_id       = yandex_storage_bucket.photos.id
    create          = true
    batch_cutoff    = 2
  }
  function {
    id                  = yandex_function.face-detection.id
    service_account_id  = var.service_account_id
  }
}

# resource "yandex_function_trigger" "task-trigger" {
#   name = "${var.prefix}-task"
#   message_queue {
#     queue_id   = yandex_message_queue.tasks.arn
#     batch_size = 1
#   }
#   function {
#     id = yandex_function.face-cut.id
#   }
# }

# resource "yandex_api_gateway" "apigw" {
#   name = "${var.prefix}-apigw"
#   spec = <<-EOT
#     openapi: 3.0.0
#     info:
#       title: Faces API
#     paths:
#       /:
#         get:
#           parameters:
#             - name: face
#               in: query
#               required: true
#           x-yc-apigateway-integration:
#             type: object_storage
#             bucket: ${yandex_storage_bucket.faces.bucket}
#             object: "{face}"
#             presigned_redirect: true
#   EOT
# }

resource "archive_file" "zip-source-detection" {
  type          = "zip"
  source_dir    = "source_detection"
  output_path   = "source_detection.zip"
}

# resource "archive_file" "zip-source-cut" {
#   type          = "zip"
#   source_dir    = "source_cut"
#   output_path   = "source_cut.zip"
# }

resource "yandex_function" "face-detection" {
  name                  = "${var.prefix}-face-detection"
  runtime               = "python312"
  entrypoint            = "index.handler"
  user_hash             = "sha256:${filemd5("source_detection.zip")}"
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
    zip_filename = "source_detection.zip"
  }
  mounts {
    name = "${var.prefix}-photos"
    mode = "ro"
    object_storage {
      bucket = yandex_storage_bucket.photos.bucket
    }
  }
  depends_on = [archive_file.zip-source-detection]
}

# resource "yandex_function" "face-cut" {
#   name              = "${var.prefix}-face-cut"
#   runtime           = "python313"
#   entrypoint        = "index.handler"
#   memory            = 512
#   execution_timeout = 20
#   environment = {
#     FACES_BUCKET = yandex_storage_bucket.faces.bucket
#   }
#   content {
#     zip_filename = "source_cut.zip"
#   }
# }