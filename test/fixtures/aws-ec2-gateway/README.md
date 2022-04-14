# aws-ec2-gateway

## Usage

```shell
terraform init --backend-config=backend.hcl
terraform apply
<do some testing>
terraform destroy
```

### Files

#### `backend.hcl`

The `backend.hcl` file referred to above should look something like this, with regard to Terraform Cloud:

```hcl
hostname     = "app.terraform.io"
organization = "<ORGANISATION NAME>"

workspaces { name = "<WORKSPACE NAME>" }
```

Note that, at the time of writing, Terraform Cloud
[does not support partial configuration](https://support.hashicorp.com/hc/en-us/articles/4408532630675-How-to-set-remote-backend-partial-configuration-to-manage-different-environments-with-Terraform-Cloud).

#### `locals.sensitive.tf`

The `locals.sensitive.tf` file should contain the values for two `local` variables, like so:

```hcl
locals {
  name_prefix = "<NAME PREFIX STRING>"
  owner       = "<OWNER OF RESOURCES>"
}
```

#### `sensitive.auto.tfvars`

The `sensitive.auto.tfvars` file should contain a `public_key_file` key where the value is the path to a public key
file for use with EC2 VMs, like so:

```hcl
public_key_file = "~/.ssh/id_rsa_terratest_tyk_aws.pub"
```

## Auth

There is a [helper script `aws-op-auth.sh`](aws-op-auth.sh) which will access 1Password via the CLI and go through the
necessary authentication flow to set environment variables for both the AWS CLI and Terraform to make use of.

Note that this script needs to be `eval`d to be effective. More details will be emitted from the script itself.
