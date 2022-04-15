variable "public_key_file" {
  description = "path to a '.pub' file that will be created as a key pair for use with EC2 VMs"
  type        = string

  validation {
    condition     = length(var.public_key_file) > 4 && substr(var.public_key_file, -4, 4) == ".pub"
    error_message = "The value for 'public_key_file' must be a path to a '.pub' file."
  }
}
