provider "aws" {
  region = local.region

  # Set filter to only operate on this specific account
  allowed_account_ids = [local.aws_account_id]
}
