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

resource "kubernetes_secret" "consulLicense" {
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

  depends_on = [kubernetes_secret.consulLicense]

  name = "consul"
  repository = "https://helm.releases.hashicorp.com"
  chart = "consul"
  version = "0.21.0"

  lint = true
  timeout = 600
  atomic = false


  set {
    name = "server.replicas"
    value = 3
  }

  set {
    name = "server.bootstrapExpect"
    value = 3
  }
  
  set {
    name = "ui.service.type"
    value = "LoadBalancer"
  }

  set {
    name = "server.enterpriseLicense.consulLicense"
    value = "consullicense"
  }

  set {
    name = "server.enterpriseLicense.entKey"
    value = "key"
  }

  set {
    name = "server.connect"
    value = true
  }

  set {
    name = "client.grpc"
    value = true
  }

  set {
    name = "connectInject.enabled"
    value = true
  }

  set {
    name = "connectInject.default"
    value = false
  }

 /* set {
    name = "affinity"
    value = false
  }*/

}