
data "aws_subnets" "destination" {
  filter {
    name   = "vpc-id"
    values = [aws_vpc.this_vpc.id]
  }
  filter {
    name   = "tag:Name"
    values = ["PublicSubnet-${var.cluster_name}-*"] # insert values here
  }
  tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
    "kubernetes.io/role/elb"                    = "1"
    env                                         = "${var.cluster_name}"
  }
}

locals {
  subnet_ids_stringA = join(",", data.aws_subnets.destination.ids)
  subnet_ids_listA   = split(",", local.subnet_ids_stringA)
}


data "aws_subnet" "azs_public_dest" {
  count = length(aws_subnet.public)
  depends_on = [
    aws_subnet.private, aws_subnet.public
  ]
  tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
    "kubernetes.io/role/elb"                    = "1"
    env                                         = "${var.cluster_name}"
    Name                                        = "PublicSubnet-${var.cluster_name}-*"
  }
  #id = local.subnet_ids_listA[count.index] 
  id = element(tolist(data.aws_subnets.destination.ids), count.index)
}


resource "aws_nat_gateway" "ngw" {
  count         = length(data.aws_eip.by_filter[*])
  subnet_id     = element(data.aws_subnet.azs_public_dest.*.id, count.index)
  allocation_id = element(data.aws_eip.by_filter.*.id, count.index)
  tags = {
    Name = "NatGateway-${var.cluster_name}-${data.aws_availability_zones.available.names[count.index]}"
    env  = "${var.cluster_name}"
    zone = "${data.aws_availability_zones.available.names[count.index]}"
  }
  depends_on = [aws_internet_gateway.this_ig]
}


resource "null_resource" "dummy_dependency" {
  depends_on = [
    aws_nat_gateway.ngw
  ]
}
output "depends_id" {
  value = null_resource.dummy_dependency.id
}


data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [aws_vpc.this_vpc.id]
  }
  filter {
    name   = "tag:Name"
    values = ["PrivateSubnet-${var.cluster_name}-*"] # insert values here
  }
  tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
    "kubernetes.io/role/internal-elb"           = "1"
    env                                         = "${var.cluster_name}"
  }
}


locals {
  subnet_ids_stringPrivate = join(",", data.aws_subnets.private.ids)
  subnet_ids_listPrivate   = split(",", local.subnet_ids_stringPrivate)
}

data "aws_subnets" "internal" {
  filter {
    name   = "vpc-id"
    values = [aws_vpc.this_vpc.id]
  }
  filter {
    name   = "tag:Name"
    values = ["${var.cluster_name}-k8s-internal-*"] # insert values here
  }
  tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
    #  "kubernetes.io/role/internal-elb" = "1"
    env = "${var.cluster_name}"
  }
}


locals {
  subnet_ids_internal = join(",", data.aws_subnets.internal.ids)
  #subnet_ids_listInternal = split(",", local.subnet_ids_internal)
  subnet_ids_listInternal = data.aws_subnets.internal.ids
}


resource "aws_eip" "redundency" {
  count  = 3
  domain = "vpc"
  tags = {
    env  = "${var.cluster_name}"
    zone = "${data.aws_availability_zones.available.names[count.index]}"
    task = "ngw"

  }

}

data "aws_eip" "by_filter" {
  count = 3
  filter {
    name   = "tag:env"
    values = ["${var.cluster_name}"]
  }
  filter {
    name   = "tag:zone"
    values = ["${data.aws_availability_zones.available.names[count.index]}"]
  }
  filter {
    name   = "tag:task"
    values = ["ngw"]
  }
  depends_on = [
    aws_eip.redundency
  ]
}
