resource "aws_vpc" "this_vpc" {
  cidr_block           = var.cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags                 = { Name = "${var.env_name}-VPC", env = "${var.cluster_name}" }
}

resource "aws_internet_gateway" "this_ig" {
  vpc_id = aws_vpc.this_vpc.id
}

resource "aws_default_route_table" "default_route_table" {
  default_route_table_id = aws_vpc.this_vpc.default_route_table_id
  tags = {
    Name = "${var.cluster_name}RT",
    env  = "${var.cluster_name}"
  }
}



resource "aws_subnet" "private" {
  count = 3
  depends_on = [
    aws_vpc.this_vpc, aws_vpc_ipv4_cidr_block_association.cidr_public
  ]
  vpc_id                  = aws_vpc.this_vpc.id
  cidr_block              = cidrsubnet(var.cidr, 2, count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = false
  tags = {
    Name                                         = "PrivateSubnet-${var.cluster_name}-${data.aws_availability_zones.available.names[count.index]}"
    "kubernetes.io/cluster/${var.cluster_name}"  = "owned"
    "kubernetes.io/cluster/${var.cluster_name}2" = "shared"
    "kubernetes.io/role/internal-elb"            = "1"
    env                                          = "${var.cluster_name}"
  }
}

resource "aws_subnet" "public" {
  count = 3
  depends_on = [
    aws_internet_gateway.this_ig, aws_vpc.this_vpc, aws_vpc_ipv4_cidr_block_association.cidr_public
  ]
  vpc_id                  = aws_vpc.this_vpc.id
  cidr_block              = cidrsubnet(var.cidr_public, 2, count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = false
  tags = {
    Name                                         = "PublicSubnet-${var.cluster_name}-${data.aws_availability_zones.available.names[count.index]}"
    "kubernetes.io/cluster/${var.cluster_name}"  = "owned"
    "kubernetes.io/cluster/${var.cluster_name}2" = "shared"
    "kubernetes.io/role/elb"                     = "1"
    env                                          = "${var.cluster_name}"
  }
}

resource "aws_vpc_ipv4_cidr_block_association" "cidr_public" {
  vpc_id     = aws_vpc.this_vpc.id
  cidr_block = var.cidr_public
}

output "subnet_ids" {
  value = [for s in aws_subnet.private : [s.id, s.availability_zone]]
}


data "aws_subnet" "azs" {
  count = length(aws_subnet.private[*].id)
  depends_on = [
    aws_subnet.private, aws_subnet.public
  ]
  filter {
    name   = "tag:Name"
    values = ["PrivateSubnet-${var.cluster_name}-${data.aws_availability_zones.available.names[count.index]}"]
  }
  availability_zone = aws_subnet.private[count.index].availability_zone
  id                = aws_subnet.private[count.index].id
}

