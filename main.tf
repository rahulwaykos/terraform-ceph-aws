provider "aws" {
  region = "us-east-1"
}

resource "aws_security_group" "nginx" {
  name   = "nginx_access"
  vpc_id = var.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# EC2 instances
resource "aws_instance" "cluster_member" {
  count = var.cluster_member_count
  ami                         = "ami-0015b9ef68c77328d"
  subnet_id                   = var.subnet_id
  instance_type               = "t2.micro"
  associate_public_ip_address = true
  security_groups             = [aws_security_group.nginx.id]
  user_data                   = << EOF
                                  #!/bin/bash
                                  hostnamectl set-hostname ${var.vluster_member_name_prefix}-[count.index]
                                  EOF
  key_name                    = var.key_name
}

# Bash command to populate /etc/hosts file on each instances
resource "null_resource" "provision_cluster_member_hosts_file" {
  count = var.cluster_member_count

  # Changes to any instance of the cluster requires re-provisioning
  triggers = {
    cluster_instance_ids = "${join(",", aws_instance.cluster_member.*.id)}"
  }
  connection {
    type = "ssh"
    host = "${element(aws_instance.cluster_member.*.public_ip, count.index)}"
    user = "centos"
    private_key = file(var.private_key_path)
  }
  provisioner "remote-exec" {
    inline = [
      # Adds all cluster members' IP addresses to /etc/hosts (on each member)
      "echo '${join("\n", formatlist("%v", aws_instance.cluster_member.*.private_ip))}' | awk 'BEGIN{ print \"\\n\\n# Cluster members:\" }; { print $0 \" ${var.cluster_member_name_prefix}\" NR-1 }' | sudo tee -a /etc/hosts > /dev/null",
      "sudo yum install docker chrony -y > /dev/null",
      "sudo systemctl restart docker && sudo systemctl restart chronyd",
      
    ]
  }
}
