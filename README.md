# Cloud Build Trigger Webhook

## Use webhooks to trigger a central Cloud Build pipeline from multiple Git repositories
---
Using a Webhook, we can connect multiple GitHub repositories with the Central Cloud Build trigger, which clones the repos, and apply the terraform code in each connected repos.
```
terraform repo ---|
terraform repo ---|> Cloud Build Trigger(With Inline config ) --> Create Resources 
terraform repo ---|
```

This project creates the Central Cloud Build Trigger. For security reasons, you should not store the GitHub access token in plaintext in the inline Cloud Build config. So adding the GitHub access token to Secret Manager is handled automatically when you apply this terraform code.

### Resources created
---
- Secret for the Cloud Build trigger webhook.
- Secret for the GitHub access token.
- A Cloud Storage to store the terraform state.
- Cloud build trigger, which is triggered with a webhook and has inline config.
- A policy that allows the Cloud Build to access the secrets.

### Installation and setup
---
- Clone the repository

Create a `terraform.auto.tfvars` file and add `github_access_token` and `secret` variables.

> `github_access_token`: A GitHub access token. [here](https://docs.github.com/en/enterprise-server@3.4/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token) is how to create one and Give it a Full controll of private repository scope.

> `secret`: A string value used to create the secret.


The `terraform.auto.tfvars` will be like this.
```
github_access_token = "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"
secret              = "somesecret"
```

### Creating the Cloud Build Trigger
---

1. Download and initialize terraform
    - `terraform init`

2. Terraform plan (Optional)
    - `terraform plan`

3. Apply the terraform code.
    - `terraform apply`

### Adding the webhook URL to a GitHub Repo
---

After applying the code, a Cloud Build Trigger is created, So go to the triggers tab and click the cloud build trigger. Then under the webhook URL, click the `Show URL Preview` button and wait and copy the value. After copying the value. Go to the repo in GitHub and add the webhook URL.

### Testing
---
To test this project, you can create a new GitHub repo with some terraform code to create a bucket.

Create main.tf file with the following content and replace the variables with your values.
```terraform
terraform {
  backend "gcs" {
    bucket  = ""
    prefix  = ""
  }
}

variable "location" {
  description = "The bucket location"
  default = "REPLACE THIS VALUE WITH THE REGION YOU WANT"
}
variable "project" {
  description = "The GCP project ID"
  default = "REPLACE THIS VALUE WITH THE YOU PROJECT ID"
}

resource "google_storage_bucket" "test-bucket" {
  project = var.project
  name   = "test-bucket-${var.project}"
  location = var.location
}
```

Get the Cloud Build Trigger URL  and add a webhook in GitHub with the URL for a `pull request` event and change the Content-type to `application/json`.
After Finishing with the setup, you can create a new branch and add some changes (like a `README.md` file) and commit and create a pull request to the `main` branch. This will trigger the Cloud Build and it will create a Bucket with the name `"test-bucket-${var.project}"`.