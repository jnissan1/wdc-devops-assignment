module "eks-auth" {
   source  = "terraform-aws-modules/eks/aws//modules/aws-auth"
   version = "~> 20.0"
   manage_aws_auth_configmap = true
   aws_auth_roles = [
     {
       rolearn  = "${module.eks.eks_managed_node_groups["${var.cluster_name}-node"].iam_role_arn}"
       username = "system:node:{{EC2PrivateDNSName}}"
       groups   = ["system:bootstrappers","system:nodes"]
     },
   ]
 }


module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"
  cluster_name                   = local.name
  cluster_version                = local.cluster_version
  cluster_endpoint_private_access = true
  cluster_endpoint_public_access = true
  cluster_endpoint_public_access_cidrs     = var.public_access_cidrs
  create_iam_role = true
  kms_key_enable_default_policy = false
  enable_cluster_creator_admin_permissions = true
  authentication_mode = "API_AND_CONFIG_MAP"
  cluster_addons = {
    coredns    = {
      most_recent    = true
      resolve_conflicts_on_update = "PRESERVE"
    }
    kube-proxy = {
      before_compute = false
      most_recent    = true
      resolve_conflicts_on_update = "PRESERVE"
    }
    aws-ebs-csi-driver = {
      most_recent    = true
      service_account_role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.cluster_name}-ebs-csi-controller-role"
      resolve_conflicts_on_update = "PRESERVE"
    }
    vpc-cni = {

      service_account_role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.cluster_name}-eni-controller-role"
      before_compute = true
      most_recent    = true
      resolve_conflicts_on_update = "PRESERVE"
      configuration_values = jsonencode({
        env = {
          ENABLE_PREFIX_DELEGATION = "true"
          WARM_PREFIX_TARGET       = "1"
        }
      })
    }
  }

  vpc_id = var.vpc_id
  
  subnet_ids               = split(",", var.subnet_ids_listPrivate) 
  control_plane_subnet_ids = split(",", var.subnet_ids_listPrivate)
  eks_managed_node_group_defaults = {
    iam_role_additional_policies = {
      AmazonEC2ContainerRegistryReadOnly = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
      AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
      AmazonEKS_CNI_Policy = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
    }
  }
  eks_managed_node_groups = {
    "${var.cluster_name}-node" = {
      use_name_prefix = true
      enable_bootstrap_user_data = false
      pre_bootstrap_user_data = <<-EOT
        #!/bin/bash
        LINE_NUMBER=$(grep -n "KUBELET_EXTRA_ARGS=\$2" /etc/eks/bootstrap.sh | cut -f1 -d:)
        REPLACEMENT="\ \ \ \ \ \ KUBELET_EXTRA_ARGS=\$(echo \$2 | sed -s -E 's/--max-pods=[0-9]+/--max-pods=110/g')"
        sed -i '/KUBELET_EXTRA_ARGS=\$2/d' /etc/eks/bootstrap.sh
        sed -i "$${LINE_NUMBER}i $${REPLACEMENT}" /etc/eks/bootstrap.sh
      EOT
      min_size     = 1
      max_size     = 3
      desired_size = 1
      capacity_type        = "SPOT"
      use_mixed_instances_policy = true
      mixed_instances_policy = {
        instances_distribution = {
          on_demand_base_capacity                  = 0
          spot_allocation_strategy                 = "price-optimized"
        }
      }
      disk_size            = 30
      instance_types       = ["t3.xlarge","t3a.xlarge","m5.xlarge","m5a.xlarge","m5ad.xlarge","m5d.xlarge","c5.xlarge","c5a.xlarge","c5ad.xlarge","c5d.xlarge","m6a.xlarge","r5.xlarge","r5a.xlarge","r5ad.xlarge","r5d.xlarge"]
      labels = {
        task = "worker"
        env = "${local.name}"
      }
      update_config = {
        max_unavailable_percentage = 100 # max_unavailable or `max_unavailable_percentage`
      }
      ebs_optimized           = true
      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size           = 30
            volume_type           = "gp3"
            iops                  = 3000
            throughput            = 150
            encrypted             = true
            kms_key_id            = aws_kms_key.ebs.arn
            delete_on_termination = true
          }
        }
      }
      tags = local.tags
    }
  }
    tags = local.tags
}

resource "aws_eks_identity_provider_config" "oidc" {
  cluster_name = module.eks.cluster_name

  oidc {
    client_id                     = module.eks.oidc_provider_arn
    identity_provider_config_name = "${var.cluster_name}-oidcconf"
    issuer_url                    = module.eks.cluster_oidc_issuer_url
  }
}

resource "aws_kms_key" "eks" {
  description             = "EKS ${var.cluster_name} Encryption Key"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = local.tags
}

resource "aws_kms_key" "ebs" {
  description             = "${var.cluster_name} managed key to encrypt EKS managed node group volumes"
  deletion_window_in_days = 7
  policy                  = data.aws_iam_policy_document.ebs.json
}

data "aws_iam_policy_document" "ebs" {
  # Copy of default KMS policy that lets you manage it
  statement {
    sid       = "Enable IAM User Permissions"
    actions   = ["kms:*"]
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }

  # Required for EKS
  statement {
    sid = "Allow service-linked role use of the CMK"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey"
    ]
    resources = ["*"]

    principals {
      type = "AWS"
      identifiers = [
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling", # required for the ASG to manage encrypted volumes for nodes
        module.eks.cluster_iam_role_arn,                                                                                                            # required for the cluster / persistentvolume-controller to create encrypted PVCs
      ]
    }
  }

  statement {
    sid       = "Allow attachment of persistent resources"
    actions   = ["kms:CreateGrant"]
    resources = ["*"]

    principals {
      type = "AWS"
      identifiers = [
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling", # required for the ASG to manage encrypted volumes for nodes
        module.eks.cluster_iam_role_arn,                                                                                                            # required for the cluster / persistentvolume-controller to create encrypted PVCs
      ]
    }

    condition {
      test     = "Bool"
      variable = "kms:GrantIsForAWSResource"
      values   = ["true"]
    }
  }
}

resource "kubectl_manifest" "ebs-sc" {
  depends_on = [
    module.eks
  ]
  yaml_body = yamlencode({
    apiVersion = "storage.k8s.io/v1"
    kind       = "StorageClass"
    metadata = {
      name = "ebs-sc"
    }
    parameters = {
      "csi.storage.k8s.io/fstype" = "ext4"
      encrypted = "true"
      type = "gp2"
    }
    provisioner = "ebs.csi.aws.com"
    reclaimPolicy = "Retain"
    volumeBindingMode = "WaitForFirstConsumer"
  })
}

resource "kubectl_manifest" "gp3-sc" {
  depends_on = [
    module.eks
  ]
  yaml_body = yamlencode({
    apiVersion = "storage.k8s.io/v1"
    kind       = "StorageClass"
    metadata = {
      name = "gp3-sc"
    }
    parameters = {
      "csi.storage.k8s.io/fstype" = "xfs"
      allowautoiopspergbincrease: "true"
      encrypted = "true"
      type = "gp3"
    }
    provisioner = "ebs.csi.aws.com"
    reclaimPolicy = "Retain"
    volumeBindingMode = "WaitForFirstConsumer"
  })
}