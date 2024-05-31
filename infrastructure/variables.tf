variable "env_name" {
  type        = string
  default     = ""
  description = "Environment Name"
}

variable "cluster_name" {
  type        = string
  default     = ""
  description = "Main Cluster Name"
}

variable "region" {
  type        = string
  default     = ""
  description = "region to deploy everything"
}

variable "cluster_users" {
  type        = list(string)
  default     = [""]
  description = "Admin ARN to add to kubernetes auth"
}


variable "cidr" {
  default     = ""
  type        = string
  description = "VPC CIDR prefix"
}

variable "cidr_public" {
  default     = ""
  description = "VPC CIDR prefix"
}

#variable "secondary_cidr" {
#  default     = ""
#  description = "Internal K8s networking CIDR"
#}

variable "public_access_cidrs" {
  type        = list(string)
  description = "publicAccessCIDRs for cluster controlplane api"

}