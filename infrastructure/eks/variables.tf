variable "public_access_cidrs" {
    type = list(string)
    description = "publicAccessCIDRs for cluster controlplane api"
  
}
variable "cluster_version" {
  default = ""
  description = "kubernetes control plane version"
}


variable "cluster_name" {
  description = "Cluster name"
}

variable "region" {
  description = "Region to depoy cluster to"
}

variable "cidr" {
  description = "VPC CIDR prefix"
  }

variable "cidr_public" {
  description = "VPC CIDR prefix"
  }


variable "vpc_id" {
  description = "VPC CIDR prefix"
  }

variable "vpc_cidr" {
  description = "VPC CIDR prefix"
  }

variable "subnetids_listA" {
  description = "K8s networking CIDR"
}
variable "subnet_ids_listPrivate" {
  description = "Internal K8s networking CIDR"
}

data "aws_caller_identity" "current" {}

variable "cluster_users" {
  description = "admin user arn for cluster"
  type = list(string)
}

variable github_secret_name {
  type        = string
  default     = ""
  description = "AWS Secrets Manager github credentials secret name"
}