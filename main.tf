/*
Copyright (c) 2016, UPMC Enterprises
All rights reserved.
Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:
    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name UPMC Enterprises nor the
      names of its contributors may be used to endorse or promote products
      derived from this software without specific prior written permission.
THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL UPMC ENTERPRISES BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PR)
OCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
*/

provider "aws" {
  region     = "${var.region}"
}

locals {
  k8s_cluster_tags = "${map(
    "Name", "kubeadm-milpa-${var.cluster-name}",
    "kubernetes.io/cluster/${var.cluster-name}", "owned"
  )}"
  k8s_master_tags = "${map(
    "Name", "kubeadm-milpa-${var.cluster-name}",
    "kubernetes.io/cluster/${var.cluster-name}", "owned",
    "Role", "master"
  )}"
  k8s_worker_tags = "${map(
    "Name", "kubeadm-milpa-${var.cluster-name}",
    "kubernetes.io/cluster/${var.cluster-name}", "owned",
    "Role", "worker"
  )}"
}

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = true

  tags = "${local.k8s_cluster_tags}"

  provisioner "local-exec" {
    # Remove any leftover instance, security group etc Milpa created. They
    # would prevent terraform from destroying the VPC.
    when    = "destroy"
    command = "./cleanup-vpc.sh ${self.id} ${var.cluster-name}"
    interpreter = ["/bin/bash", "-c"]
    environment = {
      "AWS_REGION" = "${var.region}"
      "AWS_DEFAULT_REGION" = "${var.region}"
    }
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = "${aws_vpc.main.id}"

  tags = "${local.k8s_cluster_tags}"

  provisioner "local-exec" {
    # Remove any leftover instance, security group etc Milpa created. They
    # would prevent terraform from destroying the VPC.
    when    = "destroy"
    command = "./cleanup-vpc.sh ${self.vpc_id} ${var.cluster-name}"
    interpreter = ["/bin/bash", "-c"]
    environment = {
      "AWS_REGION" = "${var.region}"
      "AWS_DEFAULT_REGION" = "${var.region}"
    }
  }
}

resource "aws_route_table" "r" {
  vpc_id = "${aws_vpc.main.id}"
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.gw.id}"
  }

  depends_on = ["aws_internet_gateway.gw"]

  tags = "${local.k8s_cluster_tags}"
}

resource "aws_route_table_association" "publicA" {
  subnet_id = "${aws_subnet.publicA.id}"
  route_table_id = "${aws_route_table.r.id}"
}

resource "aws_subnet" "publicA" {
  vpc_id = "${aws_vpc.main.id}"
  cidr_block = "10.0.100.0/24"
  availability_zone = "us-east-1c"
  map_public_ip_on_launch = true

  tags = "${local.k8s_cluster_tags}"
}

resource "aws_security_group" "kubernetes" {
  name = "kubernetes"
  description = "Allow inbound ssh traffic"
  vpc_id = "${aws_vpc.main.id}"

  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["10.0.0.0/8"]
  }
  
  ingress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["172.0.0.0/8"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = "${local.k8s_cluster_tags}"
}

resource "aws_iam_role" "k8s-bcox-master" {
  name = "k8s-bcox-master"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "k8s-bcox-master" {
  name = "k8s-bcox-master"
  role = "${aws_iam_role.k8s-bcox-master.id}"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "autoscaling:DescribeAutoScalingGroups",
        "autoscaling:DescribeLaunchConfigurations",
        "autoscaling:DescribeTags",
        "ec2:DescribeInstances",
        "ec2:DescribeRegions",
        "ec2:DescribeRouteTables",
        "ec2:DescribeSecurityGroups",
        "ec2:DescribeSubnets",
        "ec2:DescribeVolumes",
        "ec2:CreateSecurityGroup",
        "ec2:CreateTags",
        "ec2:CreateVolume",
        "ec2:ModifyInstanceAttribute",
        "ec2:ModifyVolume",
        "ec2:AttachVolume",
        "ec2:AuthorizeSecurityGroupIngress",
        "ec2:CreateRoute",
        "ec2:DeleteRoute",
        "ec2:DeleteSecurityGroup",
        "ec2:DeleteVolume",
        "ec2:DetachVolume",
        "ec2:RevokeSecurityGroupIngress",
        "ec2:DescribeVpcs",
        "elasticloadbalancing:AddTags",
        "elasticloadbalancing:AttachLoadBalancerToSubnets",
        "elasticloadbalancing:ApplySecurityGroupsToLoadBalancer",
        "elasticloadbalancing:CreateLoadBalancer",
        "elasticloadbalancing:CreateLoadBalancerPolicy",
        "elasticloadbalancing:CreateLoadBalancerListeners",
        "elasticloadbalancing:ConfigureHealthCheck",
        "elasticloadbalancing:DeleteLoadBalancer",
        "elasticloadbalancing:DeleteLoadBalancerListeners",
        "elasticloadbalancing:DescribeLoadBalancers",
        "elasticloadbalancing:DescribeLoadBalancerAttributes",
        "elasticloadbalancing:DetachLoadBalancerFromSubnets",
        "elasticloadbalancing:DeregisterInstancesFromLoadBalancer",
        "elasticloadbalancing:ModifyLoadBalancerAttributes",
        "elasticloadbalancing:RegisterInstancesWithLoadBalancer",
        "elasticloadbalancing:SetLoadBalancerPoliciesForBackendServer",
        "elasticloadbalancing:AddTags",
        "elasticloadbalancing:CreateListener",
        "elasticloadbalancing:CreateTargetGroup",
        "elasticloadbalancing:DeleteListener",
        "elasticloadbalancing:DeleteTargetGroup",
        "elasticloadbalancing:DescribeListeners",
        "elasticloadbalancing:DescribeLoadBalancerPolicies",
        "elasticloadbalancing:DescribeTargetGroups",
        "elasticloadbalancing:DescribeTargetHealth",
        "elasticloadbalancing:ModifyListener",
        "elasticloadbalancing:ModifyTargetGroup",
        "elasticloadbalancing:RegisterTargets",
        "elasticloadbalancing:SetLoadBalancerPoliciesOfListener",
        "iam:CreateServiceLinkedRole",
        "kms:DescribeKey"
      ],
      "Resource": [
        "*"
      ]
    }
  ]
}
EOF
}

resource  "aws_iam_instance_profile" "k8s-bcox-master" {
  name = "k8s-bcox-master"
  role = "${aws_iam_role.k8s-bcox-master.name}"
}

data "template_file" "master-userdata" {
  template = "${file("${var.master-userdata}")}"

  vars {
    k8stoken = "${var.k8stoken}"
  }
}

data "template_file" "worker-userdata" {
  template = "${file("${var.worker-userdata}")}"

  vars {
    k8stoken = "${var.k8stoken}"
    masterIP = "${aws_instance.k8s-master.private_ip}"
    cluster_name = "${var.cluster-name}"
    aws_access_key_id = "${var.aws-access-key-id}"
    aws_secret_access_key = "${var.aws-secret-access-key}"
    ssh_key_name = "${var.ssh-key-name}"
    license_key = "${var.license-key}"
    license_id = "${var.license-id}"
    license_username = "${var.license-username}"
    license_password = "${var.license-password}"
  }
}

resource "aws_instance" "k8s-master" {
  ami           = "ami-2ef48339"
  instance_type = "t2.medium"
  subnet_id = "${aws_subnet.publicA.id}"
  user_data = "${data.template_file.master-userdata.rendered}"
  key_name = "${var.ssh-key-name}"
  associate_public_ip_address = true
  vpc_security_group_ids = ["${aws_security_group.kubernetes.id}"]
  iam_instance_profile = "${aws_iam_instance_profile.k8s-bcox-master.id}"
  source_dest_check = false
  
  depends_on = ["aws_internet_gateway.gw"]

  tags = "${local.k8s_master_tags}"
}

resource "aws_instance" "k8s-worker" {
  ami           = "ami-2ef48339"
  instance_type = "t2.medium"
  subnet_id = "${aws_subnet.publicA.id}"
  user_data = "${data.template_file.worker-userdata.rendered}"
  key_name = "${var.ssh-key-name}"
  associate_public_ip_address = true
  vpc_security_group_ids = ["${aws_security_group.kubernetes.id}"]
  iam_instance_profile = "${aws_iam_instance_profile.k8s-bcox-master.id}"
  source_dest_check = false
  
  depends_on = ["aws_internet_gateway.gw"]

  tags = "${local.k8s_worker_tags}"
}
