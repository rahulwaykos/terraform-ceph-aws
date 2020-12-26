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

variable "cluster_member_count" {
  description = "Number of members in the cluster"
  default = "5"
}
variable "cluster_member_name_prefix" {
  description = "Prefix to use when naming cluster members"
  default = "node-"
}
variable "aws_keypair_privatekey_filepath" {
  description = "Path to SSH private key to SSH-connect to instances"
  default = "./secrets/aws.key"
}
