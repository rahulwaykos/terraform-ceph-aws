
# EC2 instances
resource "aws_instance" "cluster_member" {
  count = "${var.cluster_member_count}"
  # ...
}

# Bash command to populate /etc/hosts file on each instances
resource "null_resource" "provision_cluster_member_hosts_file" {
  count = "${var.cluster_member_count}"

  # Changes to any instance of the cluster requires re-provisioning
  triggers {
    cluster_instance_ids = "${join(",", aws_instance.cluster_member.*.id)}"
  }
  connection {
    type = "ssh"
    host = "${element(aws_instance.cluster_member.*.public_ip, count.index)}"
    user = "ec2-user"
    private_key = "${file(var.aws_keypair_privatekey_filepath)}"
  }
  provisioner "remote-exec" {
    inline = [
      # Adds all cluster members' IP addresses to /etc/hosts (on each member)
      "echo '${join("\n", formatlist("%v", aws_instance.cluster_member.*.private_ip))}' | awk 'BEGIN{ print \"\\n\\n# Cluster members:\" }; { print $0 \" ${var.cluster_member_name_prefix}\" NR-1 }' | sudo tee -a /etc/hosts > /dev/null",
    ]
  }
}
