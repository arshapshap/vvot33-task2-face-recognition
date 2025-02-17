resource "archive_file" "zip-face-image-api" {
  type        = "zip"
  source_dir  = "face_image_api"
  output_path = "face_image_api.zip"
}

resource "yandex_function" "face-image-api" {
  name                  = var.function_face_image_api_name
  runtime               = "python312"
  entrypoint            = "index.handler"
  memory                = 128
  execution_timeout     = 10
  service_account_id    = var.service_account_id
  user_hash             = "sha256:${archive_file.zip-face-image-api.output_base64sha256}"
  environment = {
    PHOTOS_BUCKET         = yandex_storage_bucket.photos.bucket
    FACES_BUCKET          = yandex_storage_bucket.faces.bucket
    AWS_ACCESS_KEY_ID     = yandex_iam_service_account_static_access_key.sa-static-key.access_key
    AWS_SECRET_ACCESS_KEY = yandex_iam_service_account_static_access_key.sa-static-key.secret_key
  }
  content {
    zip_filename = "face_image_api.zip"
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
    mode = "ro"
    object_storage {
      bucket = yandex_storage_bucket.faces.bucket
    }
  }
  depends_on = [archive_file.zip-face-image-api]
}

resource "yandex_api_gateway" "faces-api-gateway" {
  name = var.api_gateway_name
  spec = <<-EOT
    openapi: 3.0.0
    info:
      title: Faces API
      version: "1.0.0"
    paths:
      /:
        get:
          parameters:
            - name: face
              in: query
              required: false
              schema:
                type: string
            - name: photo
              in: query
              required: false
              schema:
                type: string
          x-yc-apigateway-integration:
            type: cloud_functions
            function_id: ${yandex_function.face-image-api.id}
            service_account_id: "${var.service_account_id}"
  EOT
}