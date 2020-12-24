variable "vpc_id" {
  default  = "vpc-3909da44"
}

variable "subnet_id" {
  default  = "subnet-efaafda2"
}

variable "ssh_user" {
  default  = "centos"
}

variable "key_name" {
  default  = "storage-gateway"
}

variable "private_key_path" {
  default  = "~/terraform/storage-gateway.pem"
}
