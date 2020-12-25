provider "aws" {
  region = "us-east-1"
}

resource "aws_security_group" "ceph_sec_grp" {
  name   = "ceph_access"
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
  security_groups             = [aws_security_group.ceph_sec_grp.id]
  key_name                    = var.key_name
  
  ebs_block_device {
    device_name = "/dev/sdb"
    volume_size = "20"
    volume_type = "standard"
    delete_on_termination = "true"
  }
}

# Bash command to populate /etc/hosts file on each instances
resource "null_resource" "cluster_hosts" {
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
      "echo '${join("\n", formatlist("%v", aws_instance.cluster_member.*.private_ip))}' | awk 'BEGIN{ print \"\\n\\n# Cluster members:\" }; { print $0 \" ${var.cluster_member_name_prefix}\"  NR-1  }' | sudo tee -a /etc/hosts > /dev/null",
      "sudo yum install docker chrony sshpass python3 -y > /dev/null",
      "sudo systemctl restart docker && sudo systemctl restart chronyd",
      "sudo sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/g' /etc/ssh/sshd_config",
      "echo redhat | sudo passwd --stdin centos",
      "echo redhat | sudo passwd --stdin root",
      "sudo systemctl restart sshd",
      ]
    }
  }
resource "null_resource" "set_hostname_1" {
  count = var.cluster_member_count
  depends_on = [ "null_resource.cluster_hosts" ]
  # Changes to any instance of the cluster requires re-provisioning
  triggers = {
    cluster_instance_ids = "${join(",", aws_instance.cluster_member.*.id)}"
  }
  connection {
    type = "ssh"
    host = "${element(aws_instance.cluster_member.*.public_ip, 1)}"
    user = "centos"
    private_key = file(var.private_key_path)
  }

  provisioner "remote-exec" {
    # Bootstrap script called with private_ip of each node in the cluster
    inline = [
      "sudo hostnamectl set-hostname node-1 ",
      
    ]
  }
}

resource "null_resource" "set_hostname_2" {
  count = var.cluster_member_count
  depends_on = [ "null_resource.cluster_hosts" ]
  # Changes to any instance of the cluster requires re-provisioning
  triggers = {
    cluster_instance_ids = "${join(",", aws_instance.cluster_member.*.id)}"
  }
  connection {
    type = "ssh"
    host = "${element(aws_instance.cluster_member.*.public_ip, 2)}"
    user = "centos"
    private_key = file(var.private_key_path)
  }

  provisioner "remote-exec" {
    # Bootstrap script called with private_ip of each node in the cluster
    inline = [
      "sudo hostnamectl set-hostname node-2 ",
      
    ]
  }
}

resource "null_resource" "set_hostname_0" {
  count = var.cluster_member_count
  depends_on = [ "null_resource.cluster_hosts" ]
  # Changes to any instance of the cluster requires re-provisioning
  triggers = {
    cluster_instance_ids = "${join(",", aws_instance.cluster_member.*.id)}"
  }
  connection {
    type = "ssh"
    host = "${element(aws_instance.cluster_member.*.public_ip, 0)}"
    user = "centos"
    private_key = file(var.private_key_path)
  }

  provisioner "remote-exec" {
    # Bootstrap script called with private_ip of each node in the cluster
    inline = [
      
      "sudo hostnamectl set-hostname node-0 ",
      "curl --silent --remote-name --location https://github.com/ceph/ceph/raw/octopus/src/cephadm/cephadm",
      "chmod +x cephadm",
      "sudo ./cephadm add-repo --release octopus",
      "sudo ./cephadm install",
      "sudo mkdir -p /etc/ceph",
      "node0=$(cut -d \" \" -f 1 /etc/hosts | tail -3 | head -1)",
      "node1=$(cut -d \" \" -f 1 /etc/hosts | tail -2 | head -1 )",
      "node2=$(cut -d \" \" -f 1 /etc/hosts | tail -1)",
      "sudo cephadm bootstrap --mon-ip $node0 ",
      "sudo cephadm add-repo --release octopus",
      "sudo cephadm install ceph-common",
      "sudo sshpass -p redhat ssh-copy-id -f -i /etc/ceph/ceph.pub -o StrictHostKeyChecking=no root@node-0",
      "sudo sshpass -p redhat ssh-copy-id -f -i /etc/ceph/ceph.pub -o StrictHostKeyChecking=no root@node-1",
      "sudo sshpass -p redhat ssh-copy-id -f -i /etc/ceph/ceph.pub -o StrictHostKeyChecking=no root@node-2",
      "alias ceph=\"cephadm shell -- ceph\"",
      "sudo ceph orch host add node-1 $node1",
      "sudo ceph orch host add node-2 $node2",
      "sudo ceph orch apply mon node-1 node-2",
      "sudo ceph orch apply osd --all-available-devices",
    ]
  }
}

output "cluster_ip" {
  value = aws_instance.cluster_member[0].public_ip
}

