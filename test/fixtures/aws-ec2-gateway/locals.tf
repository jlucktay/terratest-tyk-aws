locals {
  region = "eu-west-2"

  tags = {
    Environment = "dev-terratest"
    Owner       = local.owner
    Terraform   = "true"
  }

  tags_private = {
    Tier = "Private"
  }

  tags_public = {
    Tier = "Public"
  }
}
