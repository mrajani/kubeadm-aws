#-------- Gen Key Pair --------#
resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = "2048"
}

#-------- Import Pub Key in AWS --------#
resource "aws_key_pair" "ssh_key" {
  key_name   = var.ssh-key-name
  public_key = tls_private_key.ssh_key.public_key_openssh
}

#-------- Save Key Pair --------#
resource "local_file" "private_pem" {
  content         = tls_private_key.ssh_key.private_key_pem
  filename        = pathexpand("~/.ssh/milpa.pem")
  file_permission = "0600"
}

resource "local_file" "public_openssh" {
  content         = tls_private_key.ssh_key.public_key_openssh
  filename        = pathexpand("~/.ssh/milpa.pub")
  file_permission = "0644"
}

