provider "helm" {
  kubernetes {
    host                   = yandex_kubernetes_cluster.k8s-cluster.master.0.external_v4_endpoint
    cluster_ca_certificate = base64decode(yandex_kubernetes_cluster.k8s-cluster.master.0.cluster_ca_certificate)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "yc"
      args        = ["k8s", "create-token"]
    }
  }
}

resource "helm_release" "jenkins" {
  name       = "jenkins"
  repository = "https://charts.jenkins.io"
  chart      = "jenkins"
  version    = "4.3.30"

  set {
    name  = "controller.serviceType"
    value = "LoadBalancer"
  }
  set {
    name  = "controller.ingress.enabled"
    value = "true"
  }
  set {
    name  = "controller.ingress.hostName"
    value = var.jenkins_domain # Например, jenkins.mycompany.com
  }
}