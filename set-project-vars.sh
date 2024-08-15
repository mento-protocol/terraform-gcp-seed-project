#!/bin/bash
set -e          # Fail on any error
set -o pipefail # Ensure piped commands propagate exit codes properly
set -u          # Treat unset variables as an error when substituting

check_gcloud_login() {
    echo "🌀 Checking gcloud login..."
    # Check if there's an active account
    if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
        echo "No active Google Cloud account found. Initiating login..."
        gcloud auth login
        echo "✅ Successfully logged in to gcloud"
    else
        echo "ℹ️  Already logged in to Google Cloud."
    fi
    printf "\n"

    echo "🌀 Checking gcloud application-default credentials..."
    if ! gcloud auth application-default print-access-token &>/dev/null; then
        echo "No valid application-default credentials found. Initiating login..."
        gcloud auth application-default login
        echo "✅ Successfully logged in to gcloud"
    else
        echo "ℹ️  Already logged in with valid application-default credentials."
    fi
    printf "\n"
}

set_project_id() {
	printf "Looking up project name in variables.tf..."
	project_name=$(awk '/variable "project_name"/{f=1} f==1&&/default/{print $3; exit}' ./variables.tf | tr -d '",')-seed
	printf ' \033[1m%s\033[0m\n' "${project_name}"

	printf "Fetching the project ID..."
	project_id=$(gcloud projects list --filter="name:${project_name}" --format="value(projectId)")
	printf ' \033[1m%s\033[0m\n' "${project_id}"

	# Set your local default project
	echo "Setting your default project to \033[1m%s\033[0m...\n" "${project_id}"
	gcloud config set project "${project_id}"
    printf "\n"

	# Set the quota project to the governance-watchdog project, some gcloud commands require this to be set
	echo "Setting the quota project to \033[1m%s\033[0m...\n" "${project_id}"
	gcloud auth application-default set-quota-project "${project_id}"
    printf "\n"

	echo "✅ All Done!"
    printf "\n"
}

cache_file=".project_vars_cache"

# Function to load values from cache
load_cache() {
	if [[ -f ${cache_file} ]]; then
		# shellcheck disable=SC1090
		source "${cache_file}"
		return 0
	else
		return 1
	fi
}

# Function to write values to cache
write_cache() {
	{
		echo "project_id=${project_id}"
		echo "project_name=${project_name}"
		echo "bucket_name=${bucket_name}"
		echo "region=${region}"
		echo "service_account_email=${service_account_email}"
	} >>"${cache_file}"
}

# Function to fetch and print values
fetch_values() {
	printf "Loading and caching project values...\n\n"

	printf " - Project Name:"
	project_name=$(awk '/variable "project_name"/{f=1} f==1&&/default/{print $3; exit}' ./variables.tf | tr -d '",')
	printf ' \033[1m%s\033[0m\n' "${project_name}"

	printf " - Terraform State Bucket Name:"
	bucket_name=$(terraform state show "module.bootstrap.google_storage_bucket.org_terraform_state" | grep 'name' | awk -F '=' '{print $2}' | tr -d ' "')
	printf ' \033[1m%s\033[0m\n' "${bucket_name}"

	printf " - Region:"
	region=$(awk '/variable "region"/{f=1} f==1&&/default/{print $3; exit}' ./variables.tf | tr -d '",')
	printf ' \033[1m%s\033[0m\n' "${region}"

	printf " - Service Account:"
	service_account_email=$(terraform state show "module.bootstrap.google_service_account.org_terraform[0]" | grep email | awk '{print $3}' | tr -d '"')
	printf ' \033[1m%s\033[0m\n' "${service_account_email}"

	printf "\nCaching values in"
	printf ' \033[1m%s\033[0m...' "${cache_file}"
	write_cache

	printf "✅\n\n"
}

# Function to invalidate cache
invalidate_cache() {
	printf "Invalidating cache...\n"
	rm -f "${cache_file}"
}

# Main script logic
main() {
    check_gcloud_login

    printf "Loading current local gcloud project ID: "
	current_local_project_id=$(gcloud config get project)
    printf ' \033[1m%s\033[0m\n' "${current_local_project_id}"

    printf "Comparing with project ID from terraform state: "
	current_tf_state_project_id=$(terraform state show module.bootstrap.module.seed_project.module.project-factory.google_project.main | grep project_id | awk '{print $3}' | tr -d '"')
    printf ' \033[1m%s\033[0m\n' "${current_tf_state_project_id}"

	if [[ ${current_local_project_id} != "${current_tf_state_project_id}" ]]; then
		printf '️\n🚨 Your local gcloud is set to the wrong project: \033[1m%s\033[0m 🚨\n' "${current_local_project_id}"
		printf "\nTrying to set the correct project...\n\n"
		set_project_id
		invalidate_cache
		fetch_values
		printf "\n\n"
		return 0
	else
		project_id="${current_local_project_id}"
	fi

	if [[ ${1-} == "--invalidate-cache" ]]; then
		invalidate_cache
	fi

	set +e # Disable exit on error
	load_cache
	cache_loaded=$?
	set +e # Re-enable exit on error

	if [[ ${cache_loaded} -eq 0 ]]; then
		printf "Using cached values from %s:\n" "${cache_file}"
		printf " - Project ID: \033[1m%s\033[0m\n" "${project_id}"
		printf " - Project Name: \033[1m%s\033[0m\n" "${project_name}"
		printf " - Terraform State Bucket Name: \033[1m%s\033[0m\n" "${bucket_name}"
		printf " - Region: \033[1m%s\033[0m\n" "${region}"
		printf " - Service Account: \033[1m%s\033[0m\n" "${service_account_email}"
	else
		fetch_values
	fi
}

main "$@"
