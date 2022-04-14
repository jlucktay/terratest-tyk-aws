module "key_pair" {
  source = "terraform-aws-modules/key-pair/aws"

  key_name   = "${local.name_prefix}-key"
  public_key = file(pathexpand(var.public_key_file))
  tags       = local.tags
}
