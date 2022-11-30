resource "google_secret_manager_secret" "webhook_trigger_secret_key" {
  secret_id = "webhook_trigger-secret-key-1"

  replication {
    user_managed {
      replicas {
        location = var.region
      }
    }
  }
}

resource "google_secret_manager_secret_version" "webhook_trigger_secret_key_data" {
  secret = google_secret_manager_secret.webhook_trigger_secret_key.id

  secret_data = var.secret
}

resource "google_secret_manager_secret" "github_access_token_secret_key" {
  secret_id = "github-access-token"

  replication {
    user_managed {
      replicas {
        location = var.region
      }
    }
  }
}

resource "google_secret_manager_secret_version" "github_access_token_secret_key_data" {
  secret = google_secret_manager_secret.github_access_token_secret_key.id

  secret_data = var.github_access_token
}

data "google_project" "project" {}

data "google_iam_policy" "secret_accessor" {
  binding {
    role = "roles/secretmanager.secretAccessor"
    members = [
      "serviceAccount:service-${data.google_project.project.number}@gcp-sa-cloudbuild.iam.gserviceaccount.com",
    ]
  }
}

resource "google_secret_manager_secret_iam_policy" "policy" {
  project     = google_secret_manager_secret.webhook_trigger_secret_key.project
  secret_id   = google_secret_manager_secret.webhook_trigger_secret_key.secret_id
  policy_data = data.google_iam_policy.secret_accessor.policy_data
}

resource "google_storage_bucket" "tf-state" {
  project       = var.project
  name          = "tf-state-${data.google_project.project.number}"
  location      = var.region
  force_destroy = true
}


resource "google_cloudbuild_trigger" "webhook-config-trigger" {
  name        = var.web_trigger_name
  description = "Use webhooks to trigger a central Cloud Build pipeline from multiple Git repositories"
  location    = "global"

  webhook_config {
    secret = google_secret_manager_secret_version.webhook_trigger_secret_key_data.id
  }

  build {

    step {
      name       = "gcr.io/cloud-builders/git"
      args       = ["-c", "git clone https://gitlab-token:$$GITHUB_TOKEN@$${_REPO_URL} repo"]
      entrypoint = "bash"
      secret_env = ["GITHUB_TOKEN"]
    }

    step {
      name = "hashicorp/terraform"
      args = ["init", "-backend-config=bucket=$${_TF_BACKEND_BUCKET}", "-backend-config=prefix=$${_TF_BACKEND_PREFIX}"]
      dir  = "repo"
    }

    step {
      name = "hashicorp/terraform"
      args = ["plan", "-out=/workspace/tfplan-$BUILD_ID"]
      dir  = "repo"
    }

    step {
      name = "hashicorp/terraform"
      args = ["apply", "-auto-approve", "/workspace/tfplan-$BUILD_ID"]
      dir  = "repo"
    }


    substitutions = {
      _TF_BACKEND_BUCKET = "${google_storage_bucket.tf-state.name}"
      _TF_BACKEND_PREFIX = "tf-state-prefix"
      _GIT_REPO          = "$(body.repository.clone_url)"
      _REPO_URL          = "$${_GIT_REPO##https://}"
    }

    available_secrets {
      secret_manager {
        env          = "GITHUB_TOKEN"
        version_name = "${google_secret_manager_secret.github_access_token_secret_key.id}/versions/latest"
      }
    }
  }
}
