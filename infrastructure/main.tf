locals {
  subnets_available = false
}

locals {
  cluster_available = false
}


module "eks-resources" {
  source                 = "./eks/"
  cluster_name           = var.cluster_name
  region                 = var.region
  cidr                   = var.cidr
  cidr_public            = var.cidr_public
  vpc_id                 = aws_vpc.this_vpc.id
  vpc_cidr               = aws_vpc.this_vpc.cidr_block
  subnetids_listA        = local.subnet_ids_listA
  subnet_ids_listPrivate = local.subnet_ids_stringPrivate
  cluster_users       = var.cluster_users
  public_access_cidrs = var.public_access_cidrs
}