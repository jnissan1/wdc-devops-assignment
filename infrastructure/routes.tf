resource "aws_route_table" "PrivateRT" {
  count  = length(aws_subnet.private)
  vpc_id = aws_vpc.this_vpc.id
  depends_on = [
    aws_nat_gateway.ngw
  ]
  route {
    # The CIDR block of the route.
    cidr_block = "0.0.0.0/0"
    # Identifier of a VPC NAT gateway.
    nat_gateway_id = aws_nat_gateway.ngw[count.index].id
  }
  # A map of tags to assign to the resource.
  tags = {
    Name = "PrivateRT-${var.cluster_name}-${data.aws_availability_zones.available.names[count.index]}"
    env  = "${var.cluster_name}"
  }
}

resource "aws_route_table" "PublicRT" {
  count = length(aws_subnet.public)
  # The VPC ID.
  vpc_id = aws_vpc.this_vpc.id
  depends_on = [
    aws_nat_gateway.ngw
  ]
  route {
    # The CIDR block of the route.
    cidr_block = "0.0.0.0/0"
    # Identifier of a VPC NAT gateway.
    gateway_id = aws_internet_gateway.this_ig.id
  }
  # A map of tags to assign to the resource.
  tags = {
    Name = "PublicRT-${data.aws_availability_zones.available.names[count.index]}"
    env  = "${var.cluster_name}"
  }
}



data "aws_route_tables" "PrivateRT" {
  vpc_id = aws_vpc.this_vpc.id
  count  = length(aws_subnet.private)
  depends_on = [
    aws_route_table.PrivateRT, aws_nat_gateway.ngw
  ]
  filter {
    name   = "tag:env"
    values = ["${var.cluster_name}"]
  }
  filter {
    name   = "tag:Name"
    values = ["PrivateRT-${var.cluster_name}-${data.aws_availability_zones.available.names[count.index]}"]
  }
}

resource "aws_route_table_association" "private" {
  count = length(aws_route_table.PrivateRT)
  depends_on = [
    data.aws_route_tables.PrivateRT
  ]
  subnet_id = element(aws_subnet.private.*.id, count.index)
  # The ID of the routing table to associate with.
  route_table_id = aws_route_table.PrivateRT[count.index].id
}


resource "aws_route_table_association" "public" {
  count = length(aws_route_table.PublicRT)
  depends_on = [
    aws_route_table.PublicRT
  ]
  subnet_id = element(aws_subnet.public.*.id, count.index)
  # The ID of the routing table to associate with.
  route_table_id = aws_route_table.PublicRT[count.index].id
}


output "aws_subnet" {
  value = aws_subnet.private
}