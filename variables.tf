variable "organization-name" {
  description = "TFE Organization name"
}

variable "workspace-name" {
  description = "TFE workspace name where project was created"
}

variable "region" {
  description = "GCP region"
}

variable "zone" {
  description = "GCP zone, needed by dataflow"
}

variable "bq-cluster-usage-dataset" {
  description = "GCP dataset for cluster usage data"
}

variable "primary-cluster" {
  description = "Primary GKE cluster"
}

variable "primary-node-count" {
  description = "Primary GKE cluster node count"
}

variable "primary-node-machine-type" {
  description = "Primary GKE cluster node machine type"
}

variable "primary-node-pool" {
  description = "gke primary node pool"
}

variable "consul-enterprise-key" {
  description = "Consul enterprise licensing"
}

variable "remote-hostname" {
  description = "Hostname of TFE server storing remote state"
}

variable "helm-chart-version" {
  description = "Consul helm chart version"
  type = string
  default = "0.21.0"
  }

variable "k8s-namespace" {
  description = "Namespace to deploy Consul to"
  type=string
  default = "consul-namespace"
}