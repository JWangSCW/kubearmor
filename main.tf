terraform {
  required_providers {
    scaleway = {
      source  = "scaleway/scaleway"
      version = "2.51.0"
    }
  }
}

provider "scaleway" {
  access_key = "SCWNECCF91TMJN3FGJRD"
  secret_key = "84b48235-3b44-4534-8095-c7e690a6b72e"
  project_id = "8cfcea18-2aa9-4eb4-8754-4e32a034abec"
  region     = "fr-par" # ou "nl-ams", "pl-waw" selon le besoin
  zone       = "fr-par-1"
}

provider "kubernetes" {
  config_path = "${path.module}/kubeconfig.yaml"
}

provider "helm" {
  kubernetes {
    config_path = "${path.module}/kubeconfig.yaml"
  }
}




resource "scaleway_vpc_private_network" "private_net" {
  name   = "kapsule-private-net"
  region = "fr-par"
}


# Création du cluster Kapsule
resource "scaleway_k8s_cluster" "main" {
  name       = "kapsule-secure"
  type			              = "kapsule"
  region     = "fr-par"
  version    = "1.28.2"  # Modifier selon version souhaitée
  cni        = "cilium"
  tags       = ["secure", "kubearmor"]
  private_network_id = scaleway_vpc_private_network.private_net.id
  delete_additional_resources = true
}

# Pool de noeuds
resource "scaleway_k8s_pool" "main" {
  cluster_id = scaleway_k8s_cluster.main.id
  name       = "pool-secure"
  node_type  = "DEV1-M" # ou GP1-M, GP1-L selon les besoins
  size       = 2
  autoscaling = false
  min_size   = 1
  max_size   = 3
  tags       = ["secure"]
}

# ArgoCD installé via Helm dans le cluster
resource "helm_release" "argocd" {
  name       = "argocd"
  namespace  = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = "5.51.6" # vérifier la dernière version stable

  create_namespace = true

  values = [
    file("values/argocd-values.yaml")
  ]

    depends_on = [
    scaleway_k8s_cluster.main,
    scaleway_k8s_pool.main,
    ]

}