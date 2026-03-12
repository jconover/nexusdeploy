locals {
  # Map of AZ index -> AZ name for for_each keying
  az_map = { for i, az in var.availability_zones : az => i }

  # When single_nat_gateway = true, all private route tables point to the
  # single NAT GW deployed in the first public subnet.
  nat_gateway_count = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(var.availability_zones)) : 0
}

# ── VPC ──────────────────────────────────────────────────────────────────────

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(var.tags, {
    Name = var.vpc_name
  })
}

# ── Subnets ───────────────────────────────────────────────────────────────────

resource "aws_subnet" "public" {
  for_each = local.az_map

  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnet_cidrs[each.value]
  availability_zone       = each.key
  map_public_ip_on_launch = true

  tags = merge(var.tags, {
    Name = "${var.vpc_name}-public-${each.key}"
    Tier = "public"
  })
}

resource "aws_subnet" "private" {
  for_each = local.az_map

  vpc_id            = aws_vpc.this.id
  cidr_block        = var.private_subnet_cidrs[each.value]
  availability_zone = each.key

  tags = merge(var.tags, {
    Name = "${var.vpc_name}-private-${each.key}"
    Tier = "private"
  })
}

# ── Internet Gateway ──────────────────────────────────────────────────────────

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.vpc_name}-igw"
  })
}

# ── NAT Gateway (conditional) ─────────────────────────────────────────────────

resource "aws_eip" "nat" {
  count = local.nat_gateway_count

  domain = "vpc"

  tags = merge(var.tags, {
    Name = var.single_nat_gateway ? "${var.vpc_name}-nat-eip" : "${var.vpc_name}-nat-eip-${var.availability_zones[count.index]}"
  })

  depends_on = [aws_internet_gateway.this]
}

resource "aws_nat_gateway" "this" {
  count = local.nat_gateway_count

  # Place each NAT GW in the corresponding public subnet (or the first one when single)
  subnet_id     = aws_subnet.public[var.availability_zones[count.index]].id
  allocation_id = aws_eip.nat[count.index].id

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(var.tags, {
    Name = var.single_nat_gateway ? "${var.vpc_name}-nat" : "${var.vpc_name}-nat-${var.availability_zones[count.index]}"
  })

  depends_on = [aws_internet_gateway.this]
}

# ── Route Tables ──────────────────────────────────────────────────────────────

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = merge(var.tags, {
    Name = "${var.vpc_name}-public-rt"
  })
}

# One private route table per AZ (or one shared when single_nat_gateway = true)
resource "aws_route_table" "private" {
  for_each = local.az_map

  vpc_id = aws_vpc.this.id

  dynamic "route" {
    for_each = var.enable_nat_gateway ? [1] : []
    content {
      cidr_block     = "0.0.0.0/0"
      nat_gateway_id = var.single_nat_gateway ? aws_nat_gateway.this[0].id : aws_nat_gateway.this[each.value].id
    }
  }

  tags = merge(var.tags, {
    Name = "${var.vpc_name}-private-rt-${each.key}"
  })
}

# ── Route Table Associations ──────────────────────────────────────────────────

resource "aws_route_table_association" "public" {
  for_each = local.az_map

  subnet_id      = aws_subnet.public[each.key].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  for_each = local.az_map

  subnet_id      = aws_subnet.private[each.key].id
  route_table_id = aws_route_table.private[each.key].id
}

# ── Default Security Group ────────────────────────────────────────────────────
# Remove all default rules so the default SG is deny-all.

resource "aws_default_security_group" "this" {
  vpc_id = aws_vpc.this.id

  # No ingress or egress blocks = deny all traffic on the default SG

  tags = merge(var.tags, {
    Name = "${var.vpc_name}-default-sg-restricted"
  })
}
