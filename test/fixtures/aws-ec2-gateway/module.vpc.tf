module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = local.name_prefix
  cidr = "10.0.0.0/16"

  azs = ["${local.region}a", "${local.region}b", "${local.region}c"]

  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_dns_hostnames = true
  enable_dns_support   = true

  # IPv6
  enable_ipv6                     = true
  assign_ipv6_address_on_creation = true

  private_subnet_assign_ipv6_address_on_creation = false

  public_subnet_ipv6_prefixes  = [0, 1, 2]
  private_subnet_ipv6_prefixes = [3, 4, 5]

  # Single NAT Gateway
  enable_nat_gateway     = true
  single_nat_gateway     = true
  one_nat_gateway_per_az = false

  # Tags
  manage_default_network_acl = true
  default_network_acl_tags   = local.tags

  manage_default_security_group = true
  default_security_group_tags   = local.tags

  private_route_table_tags = local.tags_private
  private_subnet_tags      = local.tags_private
  public_route_table_tags  = local.tags_public
  public_subnet_tags       = local.tags_public

  tags = local.tags

  vpc_tags = {
    Name = "${local.name_prefix}-vpc"
  }
}
