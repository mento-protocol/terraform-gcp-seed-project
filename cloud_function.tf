# Cloud Function resource
resource "google_cloudfunctions_function" "notification_function" {
  name        = "notification-function"
  description = "Function to handle custom notifications"
  runtime     = "nodejs14"

  available_memory_mb   = 256
  source_archive_bucket = google_storage_bucket.function_bucket.name
  source_archive_object = google_storage_bucket_object.function_zip.name
  trigger_http          = true
  entry_point           = "handleNotification"
  https_trigger_security_level = "SECURE_ALWAYS"
  ingress_settings      = "ALLOW_INTERNAL_ONLY"

  environment_variables = {
    PROJECT_ID = var.project_name
  }
}

# IAM binding for the function
resource "google_cloudfunctions_function_iam_member" "invoker" {
  project        = google_cloudfunctions_function.notification_function.project
  region         = google_cloudfunctions_function.notification_function.region
  cloud_function = google_cloudfunctions_function.notification_function.name

  role   = "roles/cloudfunctions.invoker"
  member = "serviceAccount:your-service-account@your-project.iam.gserviceaccount.com"
}
# Cloud Storage bucket for the function source code
resource "google_storage_bucket" "function_bucket" {
  name     = "${var.project_name}-function-bucket"
  location = var.region
  public_access_prevention = "enforced"
  uniform_bucket_level_access = true

  logging {
    log_bucket = google_storage_bucket.logging_bucket.name
  }
  versioning {
    enabled = true
  }

}

# Create a separate bucket for logs
resource "google_storage_bucket" "logging_bucket" {
  name     = "${var.project_name}-logging-bucket"
  location = var.region
  public_access_prevention = "enforced"
  uniform_bucket_level_access = true

  logging {
    log_bucket = google_storage_bucket.logging_bucket.name
  }
  versioning {
    enabled = true
  }
}
# Cloud Storage bucket object (the function source code)
resource "google_storage_bucket_object" "function_zip" {
  name   = "function-source.zip"
  bucket = google_storage_bucket.function_bucket.name
  source = "./function-source.zip"  # You'll need to create this zip file
}

# Custom notification channel
resource "google_monitoring_notification_channel" "custom_channel" {
  display_name = "Custom Notification Channel"
  type         = "webhook_tokenauth"
  
  labels = {
    url = google_cloudfunctions_function.notification_function.https_trigger_url
  }

  user_labels = {
    email_type = "custom"
  }
}
