module "bootstrap" {
  activate_apis = [
    # Required by the bootstrap module https://github.com/terraform-google-modules/terraform-google-bootstrap?tab=readme-ov-file#apis
    "cloudresourcemanager.googleapis.com",
    "cloudbilling.googleapis.com",
    "iam.googleapis.com",
    "storage-api.googleapis.com",
    "serviceusage.googleapis.com",

    # Required by the project factory module used in other repos to bootstrap new GCP projects
    # https://github.com/terraform-google-modules/terraform-google-project-factory?tab=readme-ov-file#apis
    "admin.googleapis.com",

    # Used by many projects from us
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "pubsub.googleapis.com"
  ]
  billing_account      = var.billing_account
  create_terraform_sa  = true
  default_region       = var.region
  force_destroy        = true
  grant_billing_user   = true
  group_billing_admins = var.group_billing_admins
  group_org_admins     = var.group_org_admins
  org_admins_org_iam_permissions = [
    "roles/billing.user",
    "roles/resourcemanager.organizationAdmin"
  ]
  org_id               = var.org_id
  project_prefix       = var.project_name
  random_suffix        = true
  sa_org_iam_permissions = [
    "roles/billing.user",                      # Required for associating the billing account with a project
    "roles/iam.securityAdmin",
    "roles/iam.serviceAccountAdmin",
    "roles/logging.configWriter",
    "roles/orgpolicy.policyAdmin",
    "roles/resourcemanager.folderAdmin",
    "roles/resourcemanager.projectCreator",     # Required for creating GCP projects within the organization.
    "roles/resourcemanager.organizationViewer", # Required for looking up the domain name associated with the GCP organization ID.
    "roles/run.admin"                           # Necessary to i.e. give a local project service account permissions to invoke a cloud function

    # "roles/compute.networkAdmin",            # (when using a shared VPC) - Required for managing shared VPC subnetwork IAM policies.
    # "roles/compute.xpnAdmin",                # (when using a shared VPC) - Required for associating the target project with the host VPC.
    # "roles/resourcemanager.projectIamAdmin"  # (when using a shared VPC) - Required for managing shared VPC project IAM policies.
    # "roles/browser"                          # (when using a shared VPC) - Required for enumerating shared VPC resources.
  ]
  source               = "git::https://github.com/terraform-google-modules/terraform-google-bootstrap.git?ref=177e6be173eb8451155a133f7c6a591215130aab" # commit hash of v8.0.0
  tf_service_account_id = "org-terraform"
  tf_service_account_name = "CFT Organization Terraform Account"
}