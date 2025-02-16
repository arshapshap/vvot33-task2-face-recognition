variable "cloud_id" {
  description = "Yandex Cloud ID"
  type        = string
}
variable "folder_id" {
  description = "Folder ID"
  type        = string
}
variable "tg_bot_key" {
  description = "Telegram bot key"
  type        = string
}
variable "service_account_id" {
  description = "Service account ID"
  type        = string
}
variable "db_name" {
  description = "Database name"
  type        = string
}
variable "table_user_states_name" {
  description = "User states table name in database"
  type        = string
}
variable "table_faces_name" {
  description = "Faces table name in database"
  type        = string
}
variable "bucket_photos_name" {
  description = "Photos bucket name"
  type        = string
}
variable "bucket_faces_name" {
  description = "Faces bucket name"
  type        = string
}
variable "queue_tasks_name" {
  description = "Tasks message queue name"
  type        = string
}
variable "trigger_photo_name" {
  description = "Photo trigger name"
  type        = string
}
variable "trigger_task_name" {
  description = "Task trigger name"
  type        = string
}
variable "function_telegram_bot_name" {
  description = "Telegram bot function name"
  type        = string
}
variable "function_face_detection_name" {
  description = "Face detection function name"
  type        = string
}
variable "function_face_cut_name" {
  description = "Face cut function name"
  type        = string
}
variable "function_face_image_api_name" {
  description = "Face image api function name"
  type        = string
}
variable "api_gateway_name" {
  description = "Faces API gateway name"
  type        = string
}