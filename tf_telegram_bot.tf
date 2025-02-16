resource "archive_file" "zip-source-bot" {
  type          = "zip"
  source_dir    = "source_bot"
  output_path   = "source_bot.zip"
}

resource "yandex_function" "telegram-bot" {
  name               = "vvot33-task2-telegram-bot"
  runtime            = "python312"
  entrypoint         = "index.handler"
  memory             = 128
  execution_timeout  = 20
  user_hash          = "sha256:${filemd5("source_bot.zip")}"
  service_account_id = var.service_account_id

  environment = {
    TELEGRAM_BOT_TOKEN  = var.tg_bot_key
    YDB_URL             = "grpcs://${yandex_ydb_database_serverless.db-photo-face.ydb_api_endpoint}"
    YDB_DATABASE        = yandex_ydb_database_serverless.db-photo-face.database_path
  }

  content {
    zip_filename = "source_bot.zip"
  }

  depends_on = [archive_file.zip-source-bot, yandex_ydb_database_serverless.db-photo-face]
}

resource "yandex_api_gateway" "tg-api-gateway" {
  name = "telegram-webhook"
  spec = <<-EOT
    openapi: 3.0.0
    info:
      title: Telegram Webhook
      version: 1.0.0
    paths:
      /telegram-bot:
        post:
          x-yc-apigateway-integration:
            type: cloud_functions
            function_id: ${yandex_function.telegram-bot.id}
            service_account_id: ${var.service_account_id}
  EOT
  depends_on = [yandex_function.telegram-bot]
}

resource "null_resource" "telegram_webhook" {
  provisioner "local-exec" {
    command = "curl -X POST https://api.telegram.org/bot${var.tg_bot_key}/setWebhook?url=${yandex_api_gateway.tg-api-gateway.domain}/telegram-bot"
  }

  depends_on = [yandex_api_gateway.tg-api-gateway]
}