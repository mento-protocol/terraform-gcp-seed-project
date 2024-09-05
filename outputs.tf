output "project_id" {
  value = module.bootstrap.seed_project_id
}

output "terraform_sa_email" {
  description = "Email for privileged service account for Terraform."
  value = module.bootstrap.terraform_sa_email
}

output "terraform_sa_name" {
  description = "Fully qualified name for privileged service account for Terraform."
  value = module.bootstrap.terraform_sa_name
}

output "gcs_bucket_tfstate" {
  description = "Bucket used for storing terraform state for foundations pipelines in seed project."
  value = module.bootstrap.gcs_bucket_tfstate
}

output "notification_function_url" {
  description = "The URL of the notification function"
  value       = google_cloudfunctions_function.notification_function.https_trigger_url
}

output "discord_notification_channel_id" {
  description = "The ID of the Discord notification channel"
  value       = google_monitoring_notification_channel.discord_channel.id
}