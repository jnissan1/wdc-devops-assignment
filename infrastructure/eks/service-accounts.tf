resource "aws_iam_role_policy" "aws-ebs-csi-driver" {
  name = "${var.cluster_name}-ebs-csi-controller"
  role = aws_iam_role.aws-ebs-csi-driver.id
  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  policy = jsonencode({
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:CreateSnapshot",
        "ec2:AttachVolume",
        "ec2:DetachVolume",
        "ec2:ModifyVolume",
        "ec2:DescribeAvailabilityZones",
        "ec2:DescribeInstances",
        "ec2:DescribeSnapshots",
        "ec2:DescribeTags",
        "ec2:DescribeVolumes",
        "ec2:DescribeVolumesModifications"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:CreateTags"
      ],
      "Resource": [
        "arn:aws:ec2:*:*:volume/*",
        "arn:aws:ec2:*:*:snapshot/*"
      ],
      "Condition": {
        "StringEquals": {
          "ec2:CreateAction": [
            "CreateVolume",
            "CreateSnapshot"
          ]
        }
      }
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:DeleteTags"
      ],
      "Resource": [
        "arn:aws:ec2:*:*:volume/*",
        "arn:aws:ec2:*:*:snapshot/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:CreateVolume"
      ],
      "Resource": "*",
      "Condition": {
        "StringLike": {
          "aws:RequestTag/ebs.csi.aws.com/cluster": "true"
        }
      }
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:CreateVolume"
      ],
      "Resource": "*",
      "Condition": {
        "StringLike": {
          "aws:RequestTag/CSIVolumeName": "*"
        }
      }
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:DeleteVolume"
      ],
      "Resource": "*",
      "Condition": {
        "StringLike": {
          "ec2:ResourceTag/ebs.csi.aws.com/cluster": "true"
        }
      }
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:DeleteVolume"
      ],
      "Resource": "*",
      "Condition": {
        "StringLike": {
          "ec2:ResourceTag/CSIVolumeName": "*"
        }
      }
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:DeleteVolume"
      ],
      "Resource": "*",
      "Condition": {
        "StringLike": {
          "ec2:ResourceTag/kubernetes.io/created-for/pvc/name": "*"
        }
      }
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:DeleteSnapshot"
      ],
      "Resource": "*",
      "Condition": {
        "StringLike": {
          "ec2:ResourceTag/CSIVolumeSnapshotName": "*"
        }
      }
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:DeleteSnapshot"
      ],
      "Resource": "*",
      "Condition": {
        "StringLike": {
          "ec2:ResourceTag/ebs.csi.aws.com/cluster": "true"
        }
      }
    }
  ]
}
)
}

locals {
  oidc_clean_url = trimprefix(module.eks.cluster_oidc_issuer_url,"https://")
}

resource "aws_iam_role" "aws-ebs-csi-driver" {
  name = "${var.cluster_name}-ebs-csi-controller-role"
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
          "${local.oidc_clean_url}:sub": "system:serviceaccount:kube-system:ebs-csi-controller-sa",
          "${local.oidc_clean_url}:aud": "sts.amazonaws.com"
        }
      }
    }
    ]
  })
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