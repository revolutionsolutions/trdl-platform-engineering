# Data Sources
data "aws_availability_zones" "available" {
  state = "available"
}

# VPC
resource "aws_vpc" "trdl" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "trdl-vpc"
  }
}

# Public Subnet
resource "aws_subnet" "public_subnet1" {
  vpc_id                  = aws_vpc.trdl.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name                             = "trdl-public-subnet1"
    "kubernetes.io/role/elb"         = "1"
    "kubernetes.io/cluster/trdl-eks" = "shared"
  }
}

resource "aws_subnet" "public_subnet2" {
  vpc_id                  = aws_vpc.trdl.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true

  tags = {
    Name                             = "trdl-public-subnet2"
    "kubernetes.io/role/elb"         = "1"
    "kubernetes.io/cluster/trdl-eks" = "shared"
  }
}

# Private Subnet
resource "aws_subnet" "private_subnet1" {
  vpc_id            = aws_vpc.trdl.id
  cidr_block        = "10.0.101.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name                              = "trdl-private-subnet1"
    "kubernetes.io/role/internal-elb" = "1"
    "kubernetes.io/cluster/trdl-eks"  = "shared"
  }
}

resource "aws_subnet" "private_subnet2" {
  vpc_id            = aws_vpc.trdl.id
  cidr_block        = "10.0.102.0/24"
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = {
    Name                              = "trdl-private-subnet2"
    "kubernetes.io/role/internal-elb" = "1"
    "kubernetes.io/cluster/trdl-eks"  = "shared"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "trdl" {
  vpc_id = aws_vpc.trdl.id

  tags = {
    Name = "trdl-igw"
  }
}

# EIP for NAT Gateway
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "trdl-nat"
  }
}

# NAT Gateway
resource "aws_nat_gateway" "ngw" {
  allocation_id = aws_eip.nat.allocation_id
  subnet_id     = aws_subnet.public_subnet1.id

  tags = {
    Name = "trdl-ngw"
  }

  depends_on = [aws_internet_gateway.trdl]
}

# Routing table for public subnet
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.trdl.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.trdl.id
  }

  tags = {
    Name = "trdl-public-rt"
  }
}

resource "aws_route_table_association" "public_subnet1" {
  subnet_id      = aws_subnet.public_subnet1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_subnet2" {
  subnet_id      = aws_subnet.public_subnet2.id
  route_table_id = aws_route_table.public.id
}

# Routing table for private subnet
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.trdl.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.ngw.id
  }

  tags = {
    Name = "trdl-private-rt"
  }
}

resource "aws_route_table_association" "private_subnet1" {
  subnet_id      = aws_subnet.private_subnet1.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_subnet2" {
  subnet_id      = aws_subnet.private_subnet2.id
  route_table_id = aws_route_table.private.id
}