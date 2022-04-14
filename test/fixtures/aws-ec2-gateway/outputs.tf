output "sg_id" {
  value = module.vpc.default_security_group_id
}

output "vpc_name" {
  value = module.vpc.name
}
