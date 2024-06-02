resource "helm_release" "secrets-store-csi-driver" {
  name       = "secrets-store-csi-driver"
  repository = "https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts"
  chart      = "secrets-store-csi-driver"
  version    = "1.3.4"
  namespace  = "kube-system"
  timeout    = 10 * 60
  depends_on = [ 
      module.eks
  ]

     set {
       name  = "syncSecret.enabled"
       value = true
     }
}

data "kubectl_path_documents" "aws-secrets-manager" {
  pattern = "./k8s-manifests/aws-provider-installer.yaml"
}
# https://raw.githubusercontent.com/aws/secrets-store-csi-driver-provider-aws/main/deployment/aws-provider-installer.yaml
resource "kubectl_manifest" "aws-secrets-manager" {
  for_each  = data.kubectl_path_documents.aws-secrets-manager.manifests
  yaml_body = each.value
  depends_on = [ 
      module.eks
  ]
}

resource "helm_release" "cert-manager" {
  name             = "cert-manager"
  namespace        = "cert-manager"
  create_namespace = true
  chart            = "cert-manager"
  repository       = "https://charts.jetstack.io"
  version          = "v1.14.5"
  #values = [
  #  file("./eks/k8s-manifests/cert-manager-values.yaml")
  #]
  set {
    name  = "installCRDs"
    value = "true"
  }
  set {
    name  = "prometheus.enabled"
    value = "false"
  }
  depends_on = [ 
      module.eks
  ]
}
