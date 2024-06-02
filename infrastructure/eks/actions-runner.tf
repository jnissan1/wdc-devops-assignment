data "aws_secretsmanager_secret" "by-name" {
  name = var.github_secret_name
}
data "aws_secretsmanager_secret_version" "secret-version" {
  secret_id = data.aws_secretsmanager_secret.by-name.id
}


locals {
  github_username = jsondecode(data.aws_secretsmanager_secret_version.secret-version.secret_string)["GITHUB_USERNAME"]
  github_api_key = jsondecode(data.aws_secretsmanager_secret_version.secret-version.secret_string)["GITHUB_PASSWORD"]
  github_url = jsondecode(data.aws_secretsmanager_secret_version.secret-version.secret_string)["GITHUB_URL"]
}



resource "null_resource" "helm_login" {
  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    command = <<-EOT
        HELM_EXPERIMENTAL_OCI=1 \
        helm registry login \
          -u ${local.github_username} \
          -p ${local.github_api_key} \
          https://ghcr.io
    EOT
  }
}

resource "helm_release" "actions-runner-controller" {
  repository_username = local.github_username
  repository_password = local.github_api_key
  
  name             = "arc"
  repository       = "oci://ghcr.io/actions/actions-runner-controller-charts/"
  chart            = "gha-runner-scale-set-controller"
  namespace        = "arc-systems"
  create_namespace = true
  depends_on       = [
    module.eks,
    helm_release.cert-manager,
    ]
}


resource "helm_release" "actions-runner-set" {
  repository_username = local.github_username
  repository_password = local.github_api_key
  name             = "arc-runner-set"
  repository       = "oci://ghcr.io/actions/actions-runner-controller-charts/"
  chart            = "gha-runner-scale-set"
  namespace        = "arc-runners"
  create_namespace = true
#
#  values = [
#    templatefile("./eks/k8s-manifests/arc-values.yaml", { secret_name = "${var.github_secret_name}" })
#    #"${file("./eks/k8s-manifests/arc-values.yaml")}"
#  ]
  set {
    name  = "githubConfigUrl"
    value = local.github_url
  }
  set {
      name = "githubConfigSecret.github_token"
      value = local.github_api_key
  }
  depends_on       = [
    module.eks,
    helm_release.cert-manager,
    helm_release.actions-runner-controller]

}
