
locals {
  oidc_clean_url = trimprefix(module.eks.cluster_oidc_issuer_url,"https://")
}

resource "aws_iam_role_policy_attachment" "eni-controller-role" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role = aws_iam_role.eni-controller-role.name
}



resource "aws_iam_role" "eni-controller-role" {
  name = "${var.cluster_name}-eni-controller-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
      Effect: "Allow",
      Principal: {
        Federated: module.eks.oidc_provider_arn
      },
      Action: "sts:AssumeRoleWithWebIdentity",
      Condition: {
        StringEquals: {
          "${local.oidc_clean_url}:sub": "system:serviceaccount:kube-system:aws-node",
          "${local.oidc_clean_url}:aud": "sts.amazonaws.com"
        }
      }
    }
    ]
  })
}



resource "kubernetes_service_account" "secret_manager" {
  metadata {
    name = "${var.cluster_name}-secret-manager"
    namespace = var.cluster_name
    annotations = {
      "eks.amazonaws.com/role-arn" = "${aws_iam_role.secrst_role.arn}"
    }
  }
}


resource "aws_iam_role" "secrst_role" {
  name = "${var.cluster_name}-secret-role"
  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
      Effect: "Allow",
      Principal: {
        Federated: module.eks.oidc_provider_arn
      },
      Action: "sts:AssumeRoleWithWebIdentity",
      Condition: {
        StringEquals: {
          "${local.oidc_clean_url}:sub": "system:serviceaccount:${var.cluster_name}:${var.cluster_name}-secret-manager",
          "${local.oidc_clean_url}:aud": "sts.amazonaws.com"
        }
      }
    }
    ]
  })


  tags = {
    env = "${var.cluster_name}"
  }
}

resource "aws_iam_role_policy_attachment" "secretsmanager" {
  policy_arn = aws_iam_policy.iamsecretpolicy.arn
  role = aws_iam_role.secrst_role.name
}



resource "aws_iam_policy" "iamsecretpolicy" {
  name        = "${var.cluster_name}-secret-policy"
  path        = "/"
  description = "Allow access to ${var.cluster_name} secrets"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "secretsmanager:GetResourcePolicy",
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
          "secretsmanager:ListSecretVersionIds"
        ]
        Effect   = "Allow"
        Resource = [
          "arn:aws:secretsmanager:${var.region}:${data.aws_caller_identity.current.account_id}:secret:${var.cluster_name}/**"
        ]
      },
      {
        Effect = "Allow",
        Action = [
            "kms:GetPublicKey",
            "kms:Decrypt",
            "kms:ListKeyPolicies",
            "kms:UntagResource",
            "kms:ListRetirableGrants",
            "kms:GetKeyPolicy",
            "kms:ListResourceTags",
            "kms:ListGrants",
            "kms:GetParametersForImport",
            "kms:TagResource",
            "kms:Encrypt",
            "kms:GetKeyRotationStatus",
            "kms:DescribeKey"
        ],
        Resource = "arn:aws:kms:${var.region}:286428122158:key/${var.cluster_name}/**"
        },
        {
        Effect = "Allow",
        Action = [
            "kms:DescribeCustomKeyStores",
            "kms:ListKeys",
            "kms:ListAliases"
        ],
        Resource = "*"
        }
    ]
  })
}


resource "kubernetes_namespace" "namespace" {
  metadata {
    name = "${var.cluster_name}"
  }
}