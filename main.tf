terraform {
    required_version = ">= 0.12.0"
    required_providers {
        google = "~> 3.24.0",
        time = "~> 0.5.0",
        helm = "~> 1.3.0"
    }
}

# Presumably our admins created a project for us using TFE and we're going to get info about that project from the resulting workspace.
data "terraform_remote_state" "project" {
  backend = "remote"

  config = {
    hostname = var.remote-hostname
    organization = var.organization-name
    workspaces = {
      name = var.workspace-name
    }
  }
}

provider "google" {
  credentials = base64decode(data.terraform_remote_state.project.outputs.service_account_token)
  project     = data.terraform_remote_state.project.outputs.short_project_id
  region = var.region
  zone = var.zone
}



# ****************************************************************************
# Kubernetes
# ****************************************************************************


module "module-gke" {
  source  = "gcp-tfe.andybaran.cloud/universalexports/module-gke/gcp"
  organization-name = var.organization-name
  workspace-name = var.workspace-name
  remote-hostname = var.remote-hostname
  creds = base64decode(data.terraform_remote_state.project.outputs.service_account_token)
  gcloud_project = data.terraform_remote_state.project.outputs.short_project_id
  region = var.region
  zone = var.zone
  bq-cluster-usage-dataset = var.bq-cluster-usage-dataset
  primary-cluster = var.primary-cluster
  primary-node-count = var.primary-node-count
  primary-node-machine-type = var.primary-node-machine-type
  primary-node-pool = var.primary-node-pool
}

data "google_client_config" "provider" {}


provider "kubernetes" {
  load_config_file = false

  host  = "https://${module.module-gke.gke_endpoint}"
  token = data.google_client_config.provider.access_token
  cluster_ca_certificate = base64decode(
    module.module-gke.cluster_ca_certificate,
  )
}

resource "kubernetes_namespace" "consul_k8s_namespace" {
  
  metadata {
    name = var.k8s-namespace
  }
}

resource "kubernetes_secret" "consulLicense" {
  depends_on = [kubernetes_namespace.consul_k8s_namespace]

  metadata {
    name = "consul-license"
  }

  data = {
    entKey = var.consul-enterprise-key
  }

  type = "Opaque"
}

# ****************************************************************************
# Consul via Helm
# ****************************************************************************

## Wait 30 seconds to let GKE "settle"..otherwise we'll going to inconsistently hit frustating API timeouts
provider "time" {}
resource "time_sleep" "wait_30_seconds" {
  depends_on = [kubernetes_secret.consulLicense]
  create_duration = "30s"
}

provider "helm" {
  kubernetes {
  load_config_file = false

  host  = "https://${module.module-gke.gke_endpoint}"
  token = data.google_client_config.provider.access_token
  cluster_ca_certificate = base64decode(
    module.module-gke.cluster_ca_certificate,
  )
  }
}

resource "helm_release" "helm_consul" {

  depends_on = [time_sleep.wait_30_seconds]

  name = "consul"
  repository = "https://helm.releases.hashicorp.com"
  chart = "consul"
  version = var.helm-chart-version
  namespace = var.k8s-namespace

  lint = true
  timeout = 600
  atomic = false

####Globals

  set {
    name = "global.enabled"
    value = true
  }

  set {
    name = "global.name"
    value = "consul-"
  }

  set {
    name = "global.image"
    value = "consul:1.8.0"
  }

  set {
    name = "global.datacenter"
    value = "dc01"
  }

  set {
    name = "global.acls.manageSystemACLs"
    value = true
  }

####Server
  set {
    name = "server.replicas"
    value = 3
  }

  set {
    name = "server.bootstrapExpect"
    value = 3
  }

  set {
    name = "server.enterpriseLicense.consulLicense"
    value = "consullicense"
  }

  set {
    name = "server.connect"
    value = true
  }

####Client

  set {
    name = "client.grpc"
    value = true
  }
  

####UI

  set {
    name = "ui.service.type"
    value = "LoadBalancer"
  }

####ConnectInject

  set {
    name = "connectInject.enabled"
    value = true
  }

  set {
    name = "connectInject.default"
    value = false
  }

}