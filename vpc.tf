module "label_vpc" {
  source     = "cloudposse/label/null"
  version    = "0.25.0"
  context    = module.base_label.context
  name       = "vpc"
  attributes = ["main"]
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = module.label_vpc.tags
}

# =========================
# Create your subnets here
# =========================

# ==========================
# Creating necessary labels
# ==========================
module "label_public_subnet"{
  source     = "cloudposse/label/null"
  version    = "0.25.0"
  context    = module.base_label.context
  name       = "subnet"
  attributes = ["public"]
}

module "label_private_subnet"{
  source     = "cloudposse/label/null"
  version    = "0.25.0"
  context    = module.base_label.context
  name       = "subnet"
  attributes = ["public"]
}

module "label_igw"{
  source     = "cloudposse/label/null"
  version    = "0.25.0"
  context    = module.base_label.context
  name       = "internet_gateway"
}

# ====================================================
# data resource for az, as it should not be hardcoded
# ====================================================

data "aws_availability_zones" "azs" {
  state = "available"
}

# ==========================
# Module for subnet cidr
# ==========================
module "subnets" {
  source        = "hashicorp/subnets/cidr"
  version = "1.0.0"
  base_cidr_block = aws_vpc.main.cidr_block
  networks = [
    {
      name = "public"
      new_bits = 4
    },
    {
      name = "private"
      new_bits = 4
    }
  ]
}

# ==========================
# Resource: Public Subnet
# ==========================

resource "aws_subnet" "public" {
  vpc_id = aws_vpc.main.id
  cidr_block = module.subnets.networks[0].cidr_block
  availability_zone = data.aws_availability_zones.azs.names[0]
  tags = module.label_public_subnet.tags
}

# ==========================
# Resource: Private Subnet
# ==========================

resource "aws_subnet" "private" {
  vpc_id = aws_vpc.main.id
  cidr_block = module.subnets.networks[1].cidr_block
  availability_zone = data.aws_availability_zones.azs.names[0]
  tags = module.label_private_subnet.tags
}

# ===========================
# Resource: Internet Gateway
# ===========================

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags = module.label_igw.tags
}

# ============================
# Resource: Public Route Table
# ============================

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    Name = "${module.label_vpc.name}-public-route-table"
  }
}

# =================================================
# Resource: Public route table & subnet association
# =================================================

resource "aws_route_table_association" "public_subnet_association" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public_rt.id
}

# ==============================
# Resource: Private Route Table
# ==============================

resource "aws_route_table_association" "private_subnet_association" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_vpc.main.main_route_table_id
}