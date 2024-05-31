data "aws_security_group" "additional" {
    id = module.eks.node_security_group_id
}

resource "aws_security_group_rule" "prod-to-prod" {
  from_port = 443
  to_port = 443
  protocol = "tcp"
  security_group_id = module.eks.cluster_security_group_id
  type = "ingress"
  cidr_blocks = var.public_access_cidrs
}