
module "eks-resources" {
  source                 = "./eks/"
  cluster_name           = var.cluster_name
  cluster_version        = var.cluster_version
  region                 = var.region
  cidr                   = var.cidr
  cidr_public            = var.cidr_public
  vpc_id                 = aws_vpc.this_vpc.id
  vpc_cidr               = aws_vpc.this_vpc.cidr_block
  subnetids_listA        = tolist(aws_subnet.public.*.id)
  subnet_ids_listPrivate = tolist(aws_subnet.private.*.id)
  cluster_users          = var.cluster_users
  public_access_cidrs    = var.public_access_cidrs
  github_secret_name     = var.github_secret_name

}