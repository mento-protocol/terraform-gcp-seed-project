# Terraform Google Cloud Seed Project

This repo houses the Terraform code for our Terraform Google Cloud Seed Project. It's based on the official [Terraform Google Bootstrap Module](https://registry.terraform.io/modules/terraform-google-modules/bootstrap/google/latest) maintained by Google, HashiCorp, and the Cloud Foundation.

The main benefits we get from this shared seed project are:

- Centralized Terraform State Management: Manage the Terraform state of all our GCP projects in one place, ensuring consistency and preventing conflicts.
- Shared Service Account: Use a single service account to provision resources across all our GCP projects.

## Prerequisites

### Permissions

In order to deploy this project, you will need the following permissions in our Google Cloud Organization:

- `roles/resourcemanager.organizationAdmin` on the top-level GCP Organization
- `roles/orgpolicy.policyAdmin` on the top-level GCP Organization
- `roles/billing.admin` on the billing account connected to the project
- Additionally, the gcloud user account running `terraform apply` should be a member of the group provided in `group_org_admins` variable, otherwise they will loose `roles/resourcemanager.projectCreator` access. Additional members can be added by using the `org_project_creators` input into the bootstrap module in `main.tf`.

### Local Requirements

1. Install the `gcloud` CLI

   ```sh
   # For macOS
   brew install google-cloud-sdk

   # For other systems, see https://cloud.google.com/sdk/docs/install
   ```

1. Install trunk (one linter to rule them all)

   ```sh
   # For macOS
   brew install trunk-io

   # For other systems, see https://docs.trunk.io/check/usage
   ```

   Optionally, you can also install the [Trunk VS Code Extension](https://marketplace.visualstudio.com/items?itemName=Trunk.io)

1. Install `jq` (used in a few shell scripts)

   ```sh
   # On macOS
   brew install jq

   # For other systems, see https://jqlang.github.io/jq/
   ```

1. Install Terraform

   ```sh
   # On macOS
   brew tap hashicorp/tap
   brew install hashicorp/tap/terraform

   # For other systems, see https://developer.hashicorp.com/terraform/install
   ```

### Setup Instructions

1. Clone the repo:

   ```sh
   git clone https://github.com/mento-protocol/terraform-gcp-seed-project.git
   cd terraform-gcp-seed-project
   ```

1. Configure `terraform.tfvars` (this is like a `.env` for Terraform):

   ```sh
   touch terraform.tfvars
   # This file is `.gitignore`d to avoid accidentally leaking sensitive data
   ```

   Then set the required values in your terraform.tfvars:

   ```hcl
   # Get it via `gcloud organizations list`
   org_id = "<org-id>"

   # Get it via `gcloud billing accounts list` (pick the GmbH account)
   billing_account = "<billing-account>"

   # Get it via `gcloud organizations get-iam-policy <our-org-id> --format=json | jq -r '.bindings[] | select(.role | startswith("roles/resourcemanager.organizationAdmin"))  | .members[] | select(startswith("group:")) | sub("^group:"; "")'`
   group_org_admins = "<org-admin-group>"

   # Get it via `gcloud organizations get-iam-policy <our-org-id> --format=json | jq -r '.bindings[] | select(.role | startswith("roles/billing.admin"))  | .members[] | select(startswith("group:")) | sub("^group:"; "")'`
   group_billing_admins = "billing-adming-group"
   ```

1. Initialize Terraform: Initialize the Terraform working directory and install required providers

   ```sh
   terraform init
   ```

## Deploying & Updating the Seed Project

It's plain old Terraform, the process is:

1. Make the desired changes to your `*.tf` files
1. Run `terraform plan` to see a dry run of the expected changes
1. Run `terraform apply` to deploy the changes to Google Cloud

<!-- markdownlint-disable MD036 -->

**🚨 Be careful to not accidentally delete or otherwise change the terraform state bucket created by the bootstrap module as this houses state from all our GCP projects 🚨**

<!-- markdownlint-enable MD036 -->

## Service Account Impersonation

Instead of having to figure out and manage individual permissions for everyone, Devs can just impersonate a shared service account and not suffer through any "works on my machine" problems locally.

### The advantages of impersonation

Impersonation does not require any service account keys to be generated or distributed (i.e. in form of `credentials.json` files). While Terraform does support the use of service account keys, generating and distributing those keys introduces some security risks that are minimized with impersonation. Instead of administrators creating, tracking, and rotating keys, the access to the service account is centralized to its corresponding IAM policy. By using impersonation, the code becomes portable and usable by anyone on the project with the Service Account Token Creator role, which can be easily granted and revoked by an administrator.

For more details about the SA impersonation approach see this blog post: [**"Using Google Cloud Service Account impersonation in your Terraform code"**](https://cloud.google.com/blog/topics/developers-practitioners/using-google-cloud-service-account-impersonation-your-terraform-code)

### How to impersonate the service account in other projects

There are two approaches.

1. Setting a local Env Var

   <!-- markdownlint-disable MD034 -->

   If you set the following env var in your local shell, all `terraform` commands will be executed with the service account's permissions (and not your own <name@mentolabs.xyz> gcloud user account).
   <!-- markdownlint-enable MD034 -->

   ```sh
   # You can find the service account email via:
   # `terraform state show "module.bootstrap.google_service_account.org_terraform[0]" | grep email`
   export GOOGLE_IMPERSONATE_SERVICE_ACCOUNT=<terraform-service-account-email>
   ```

   It’s a quick and easy way to run Terraform as a service account, but you’ll have to remember to set that variable each time you restart your terminal session.

2. Provider Config

   Alternatively, you can add some extra configuration to your project's terraform files like:

   ```hcl
   provider "google" {
       project          = YOUR_PROJECT_ID
       access_token     = data.google_service_account_access_token.default.access_token
       request_timeout  = "60s"
   }
   ```

   There's a few other things to set, consult the following blog post for step-by-step instructions: [**"Using Google Cloud Service Account impersonation in your Terraform code"**](https://cloud.google.com/blog/topics/developers-practitioners/using-google-cloud-service-account-impersonation-your-terraform-code)

### Using the shared Terraform State Bucket

We should store all Terraform state configuration in this seed project. To be able to access the bucket containing
the Terraform state files, set the following in your Terraform backend configuration:

```hcl
terraform {
    backend "gcs" {
        # Find it via `terraform state show module.bootstrap.google_storage_bucket.org_terraform_state | grep name`
        bucket                      = "<gcp-seed-project-bucket-name>"

        # Find it via `terraform state show "module.bootstrap.google_service_account.org_terraform[0]" | grep email`
        impersonate_service_account = "<terraform-service-account>"
    }
}
```
