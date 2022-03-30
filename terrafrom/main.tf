provider "aws" {
  profile = "default"
  region  = var.region
}

resource "tls_private_key" "tikv_cross_az" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "generated_key" {
  key_name   = "tikv_cross_az_key"
  public_key = tls_private_key.tikv_cross_az.public_key_openssh

  provisioner "local-exec" {
    command = "echo '${tls_private_key.tikv_cross_az.private_key_pem}' > ./tikv_cross_az_key.pem"
  }
}

resource "aws_vpc" "cross_az_test_client" {
  cidr_block = "10.1.0.0/16"

  tags = {
    Name = "tidb-tikv-cross-az-zlib_client"
    usedby = var.usedby_tags
  }
}

resource "aws_subnet" "test_subnet" {
  vpc_id            = aws_vpc.cross_az_test_client.id
  cidr_block        = "10.1.1.0/24"
  availability_zone = "ap-southeast-1a"

  tags = {
    Name = "tidb-tikv-cross-az-zlib_client"
    usedby = var.usedby_tags
  }
}
resource "aws_internet_gateway" "cross_az_test_client" {
  vpc_id = aws_vpc.cross_az_test_client.id

  tags = {
    Name = "tidb-tikv-cross-az-zlib-client"
    usedby = var.usedby_tags
  }
}

resource "aws_route_table" "public_rt_client" {
  vpc_id = aws_vpc.cross_az_test_client.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.cross_az_test_client.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.cross_az_test_client.id
  }

  tags = {
    Name = "tidb-tikv-cross-az-zlib-client"
    usedby = var.usedby_tags
  }
}

resource "aws_route_table_association" "public_rt_client" {
  subnet_id      = aws_subnet.test_subnet.id
  route_table_id = aws_route_table.public_rt_client.id
}

resource "aws_security_group" "test_client_sg" {
  name   = "test client"
  vpc_id = aws_vpc.cross_az_test_client.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }
}

data "template_file" "user_data" {
  template = file("server.yml")
}

resource "aws_instance" "test_server" {
  ami           = var.amis
  instance_type = var.tools_instance_type
  key_name      = aws_key_pair.generated_key.key_name

  subnet_id                   = aws_subnet.test_subnet.id
  vpc_security_group_ids      = [aws_security_group.test_client_sg.id]

  user_data = data.template_file.user_data.rendered

  private_ip = "10.1.1.23"

  root_block_device {
    delete_on_termination = true
    volume_size           = 100
    volume_type           = "gp2"
  }

  tags = {
    Name = "test-client-server"
    usedby = var.usedby_tags
    component = "test-client-server"
  }
}

resource "aws_eip" "test_server_public_ip" {
  instance = aws_instance.test_server.id
  vpc      = true
}

resource "aws_vpc" "cross_az_test" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "tidb-tikv-cross-az-zlib"
    usedby = var.usedby_tags
  }
}

resource "aws_subnet" "subnet_0" {
  vpc_id            = aws_vpc.cross_az_test.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "ap-southeast-1a"

  tags = {
    Name = "tidb-tikv-subnet-0"
    usedby = var.usedby_tags
  }
}

resource "aws_subnet" "subnet_1" {
  vpc_id            = aws_vpc.cross_az_test.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "ap-southeast-1b"

  tags = {
    Name = "tidb-tikv-subnet-1"
    usedby = var.usedby_tags
  }
}

resource "aws_subnet" "subnet_2" {
  vpc_id            = aws_vpc.cross_az_test.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "ap-southeast-1c"

  tags = {
    Name = "tidb-tikv-subnet-2"
    usedby = var.usedby_tags
  }
}

resource "aws_internet_gateway" "cross_az_test" {
  vpc_id = aws_vpc.cross_az_test.id

  tags = {
    Name = "tidb-tikv-cross-az-zlib"
    usedby = var.usedby_tags
  }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.cross_az_test.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.cross_az_test.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.cross_az_test.id
  }

  tags = {
    Name = "tidb-tikv-cross-az-zlib"
    usedby = var.usedby_tags
  }
}

resource "aws_route_table_association" "public_1_rt" {
  subnet_id      = aws_subnet.subnet_0.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_2_rt" {
  subnet_id      = aws_subnet.subnet_1.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_3_rt" {
  subnet_id      = aws_subnet.subnet_2.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_security_group" "web_sg" {
  name   = "HTTP and SSH"
  vpc_id = aws_vpc.cross_az_test.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 0
    to_port     = 4000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }
}

data "template_file" "tikv_user_data" {
  template = file("tikv_server.yml")
}

resource "aws_instance" "tikv_0" {
  ami           = var.amis
  instance_type = var.tikv_instance_type
  key_name      = aws_key_pair.generated_key.key_name

  subnet_id                   = aws_subnet.subnet_0.id
  vpc_security_group_ids      = [aws_security_group.web_sg.id]

  user_data = data.template_file.tikv_user_data.rendered

  private_ip = "10.0.1.23"
  root_block_device {
    delete_on_termination = true
    volume_size           = 100
    volume_type           = "gp2"
  }

  ebs_block_device {
    device_name = "/dev/xvdh"
    delete_on_termination = true
    volume_size = var.tikv_storage_size
    volume_type = "gp3"
    iops        = 4000
    throughput  = 400

    tags = {
      Name = "test-tikv-0"
      usedby = var.usedby_tags
      component = "cross-az-tikv"
    }
  }

  tags = {
    Name = "test-tikv-0"
    usedby = var.usedby_tags
    component = "cross-az-tikv"
  }
}

resource "aws_instance" "tikv_1" {
  ami           = var.amis
  instance_type = var.tikv_instance_type
  key_name      = aws_key_pair.generated_key.key_name

  private_ip = "10.0.2.23"
  subnet_id                   = aws_subnet.subnet_1.id
  vpc_security_group_ids      = [aws_security_group.web_sg.id]

  user_data = data.template_file.tikv_user_data.rendered

  root_block_device {
    delete_on_termination = true
    volume_size           = 100
    volume_type           = "gp2"
  }

  ebs_block_device {
    device_name = "/dev/xvdh"
    delete_on_termination = true
    volume_size = var.tikv_storage_size
    volume_type = "gp3"
    iops        = 4000
    throughput  = 400
    tags = {
      Name = "test-tikv-1"
      usedby = var.usedby_tags
      component = "cross-az-tikv"
    }
  }

  tags = {
    Name = "test-tikv-1"
    usedby = var.usedby_tags
    component = "cross-az-tikv"
  }
}

resource "aws_instance" "tikv_2" {
  ami           = var.amis
  instance_type = var.tikv_instance_type
  key_name      = aws_key_pair.generated_key.key_name

  subnet_id                   = aws_subnet.subnet_2.id
  vpc_security_group_ids      = [aws_security_group.web_sg.id]

  private_ip = "10.0.3.23"
  user_data = data.template_file.tikv_user_data.rendered

  root_block_device {
    delete_on_termination = true
    volume_size           = 100
    volume_type           = "gp2"
  }

  ebs_block_device {
    device_name = "/dev/xvdh"
    delete_on_termination = true
    volume_size = var.tikv_storage_size
    volume_type = "gp3"
    iops        = 4000
    throughput  = 400
    tags = {
      Name = "test-tikv-2"
      usedby = var.usedby_tags
      component = "cross-az-tikv"
    }
  }

  tags = {
    Name = "test-tikv-2"
    usedby = var.usedby_tags
    component = "cross-az-tikv"
  }
}

resource "aws_instance" "pd_0" {
  ami           = var.amis
  instance_type = var.pd_instance_type
  key_name      = aws_key_pair.generated_key.key_name

  private_ip = "10.0.1.24"

  subnet_id                   = aws_subnet.subnet_0.id
  vpc_security_group_ids      = [aws_security_group.web_sg.id]

  user_data = data.template_file.user_data.rendered

  root_block_device {
    delete_on_termination = true
    volume_size           = 100
    volume_type           = "gp2"
  }

  tags = {
    Name = "test-pd-0"
    usedby = var.usedby_tags
    component = "cross-az-tikv"
  }
}

resource "aws_instance" "pd_1" {
  ami           = var.amis
  instance_type = var.pd_instance_type
  key_name      = aws_key_pair.generated_key.key_name

  private_ip = "10.0.2.24"
  subnet_id                   = aws_subnet.subnet_1.id
  vpc_security_group_ids      = [aws_security_group.web_sg.id]

  user_data = data.template_file.user_data.rendered

  root_block_device {
    delete_on_termination = true
    volume_size           = 100
    volume_type           = "gp2"
  }

  tags = {
    Name = "test-pd-1"
    usedby = var.usedby_tags
    component = "cross-az-tikv"
  }
}

resource "aws_instance" "pd_2" {
  ami           = var.amis
  instance_type = var.pd_instance_type
  key_name      = aws_key_pair.generated_key.key_name

  private_ip = "10.0.3.24"

  subnet_id                   = aws_subnet.subnet_2.id
  vpc_security_group_ids      = [aws_security_group.web_sg.id]

  user_data = data.template_file.user_data.rendered

  root_block_device {
    delete_on_termination = true
    volume_size           = 100
    volume_type           = "gp2"
  }

  ebs_block_device {
    device_name = "xvdf"
    delete_on_termination = true
    volume_size = 50
    volume_type = "gp2"
  }

  tags = {
    Name = "test-pd-2"
    usedby = var.usedby_tags
    component = "cross-az-tikv"
  }
}


resource "aws_instance" "tidb_0" {
  ami           = var.amis
  instance_type = var.tidb_instance_type
  key_name      = aws_key_pair.generated_key.key_name

  private_ip = "10.0.1.25"

  subnet_id                   = aws_subnet.subnet_0.id
  vpc_security_group_ids      = [aws_security_group.web_sg.id]

  user_data = data.template_file.user_data.rendered

  root_block_device {
    delete_on_termination = true
    volume_size           = 100
    volume_type           = "gp2"
  }

  tags = {
    Name = "test-tidb-0"
    usedby = var.usedby_tags
    component = "cross-az-tikv"
  }
}

resource "aws_instance" "tidb_1" {
  ami           = var.amis
  instance_type = var.tidb_instance_type
  key_name      = aws_key_pair.generated_key.key_name

  private_ip = "10.0.2.25"
  subnet_id                   = aws_subnet.subnet_1.id
  vpc_security_group_ids      = [aws_security_group.web_sg.id]

  user_data = data.template_file.user_data.rendered

  root_block_device {
    delete_on_termination = true
    volume_size           = 100
    volume_type           = "gp2"
  }

  tags = {
    Name = "test-tidb-1"
    usedby = var.usedby_tags
    component = "cross-az-tikv"
  }
}

resource "aws_instance" "prometheus" {
  ami           = var.amis
  instance_type = var.tools_instance_type
  key_name      = aws_key_pair.generated_key.key_name

  private_ip = "10.0.3.25"

  subnet_id                   = aws_subnet.subnet_2.id
  vpc_security_group_ids      = [aws_security_group.web_sg.id]

  user_data = data.template_file.user_data.rendered

  root_block_device {
    delete_on_termination = true
    volume_size           = 100
    volume_type           = "gp2"
  }

  tags = {
    Name = "prometheus"
    usedby = var.usedby_tags
    component = "cross-az-prometheus"
  }
}

resource "aws_instance" "grafana" {
  ami           = var.amis
  instance_type = var.tools_instance_type
  key_name      = aws_key_pair.generated_key.key_name

  private_ip = "10.0.2.26"

  subnet_id                   = aws_subnet.subnet_1.id
  vpc_security_group_ids      = [aws_security_group.web_sg.id]
  user_data = data.template_file.user_data.rendered

  root_block_device {
    delete_on_termination = true
    volume_size           = 100
    volume_type           = "gp2"
  }

  tags = {
    Name = "grafana"
    usedby = var.usedby_tags
    component = "cross-az-grafana"
  }
}

resource "aws_eip" "grafana_public_ip" {
  instance = aws_instance.grafana.id
  vpc      = true
}


resource "aws_instance" "bastion" {
  ami           = var.amis
  instance_type = var.tools_instance_type
  key_name      = aws_key_pair.generated_key.key_name

  private_ip = "10.0.1.26"

  subnet_id                   = aws_subnet.subnet_0.id
  vpc_security_group_ids      = [aws_security_group.web_sg.id]
  associate_public_ip_address = true

  user_data = data.template_file.user_data.rendered

  tags = {
    Name = "test-bastion"
    usedby = var.usedby_tags
    component = "cross-az-bastion"
  }
}


resource "aws_eip" "bastion_public_ip" {
  instance = aws_instance.bastion.id
  vpc      = true
}

resource "aws_lb" "tidb_public" {
  name               = "tidbpublicclientss"
  load_balancer_type = "network"
  internal           = false
  enable_cross_zone_load_balancing = true
  subnets = [  aws_subnet.subnet_0.id, aws_subnet.subnet_1.id, aws_subnet.subnet_2.id ]
}

resource "aws_lb_target_group" "tidb_public" {
  name     = "tidbserverclienttarget"
  port     = 4000
  protocol = "TCP"
  vpc_id      = aws_vpc.cross_az_test.id

  depends_on = [
    aws_lb.tidb_public
  ]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb_target_group_attachment" "tidb_attachment_0" {
  target_group_arn = aws_lb_target_group.tidb_public.arn
  target_id        = aws_instance.tidb_0.id
  port             = 4000
}

resource "aws_lb_target_group_attachment" "tidb_attachment_1" {
  target_group_arn = aws_lb_target_group.tidb_public.arn
  target_id        = aws_instance.tidb_1.id
  port             = 4000
}

resource "aws_lb_listener" "tidb_public" {

  load_balancer_arn = aws_lb.tidb_public.arn

  protocol = "TCP"
  port     = 4000

  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.tidb_public.arn
  }
}

output "tikv_0" {
  description = "tikv_0 ip"
  value       = aws_instance.tikv_0.private_ip
}

output "tikv_1" {
  description = "tikv_1 ip"
  value       = aws_instance.tikv_1.private_ip
}

output "tikv_2" {
  description = "tikv_2 ip"
  value       = aws_instance.tikv_2.private_ip
}

output "pd_0" {
  description = "pd_0 ip"
  value       = aws_instance.pd_0.private_ip
}

output "pd_1" {
  description = "pd_1 ip"
  value       = aws_instance.pd_1.private_ip
}

output "pd_2" {
  description = "pd_2 ip"
  value       = aws_instance.pd_2.private_ip
}

output "tidb_0" {
  description = "tidb_0 ip"
  value       = aws_instance.tidb_0.private_ip
}

output "tidb_1" {
  description = "tidb_1 ip"
  value       = aws_instance.tidb_1.private_ip
}

output "prometheus" {
  description = "prometheus ip"
  value       = aws_instance.prometheus.private_ip
}

output "grafana" {
  description = "grafana ip"
  value       = aws_instance.grafana.private_ip
}

output "grafana_public_ip" {
  description = "grafana public ip"
  value       = aws_eip.grafana_public_ip.public_ip
}

output "bastion_public_ip" {
  description = "bastion ip"
  value       = aws_eip.bastion_public_ip.public_ip
}

output "test_server_public_ip" {
  description = "test server public ip"
  value       = aws_eip.test_server_public_ip.public_ip
}

output "tidb_public_url" {
  description = "tidb public url"
  value       = aws_lb.tidb_public.dns_name
}

output "ssh_test_server" {
  description = "ssh into test server"
  value       = format("ssh -i tikv_cross_az_key.pem centos@${aws_eip.test_server_public_ip.public_ip}")
}

output "ssh_bastion_server" {
  description = "ssh into bastion server"
  value       = format("ssh -i tikv_cross_az_key.pem centos@${aws_eip.bastion_public_ip.public_ip}")
}
