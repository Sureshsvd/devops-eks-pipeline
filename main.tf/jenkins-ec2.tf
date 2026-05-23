resource "aws_security_group" "jenkins" {
  name        = "jenkins-sg"
  description = "Security group for Jenkins"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "jenkins-sg"
  }
}

resource "aws_instance" "jenkins" {
  ami                    = "ami-0c3cca3862f844ab5"
  instance_type          = var.jenkins_instance_type
  key_name               = aws_key_pair.eks_node.key_name
  subnet_id              = aws_subnet.public_a.id
  vpc_security_group_ids = [aws_security_group.jenkins.id]
  associate_public_ip_address = true

  user_data = base64encode(<<-EOF
              #!/bin/bash
              set -e
              yum update -y
              amazon-linux-extras install java-openjdk21 -y
              wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
              rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io.key
              yum install jenkins -y
              systemctl enable jenkins
              systemctl start jenkins
              EOF
  )

  tags = {
    Name = "jenkins-server"
  }
}

output "jenkins_public_ip" {
  value = aws_instance.jenkins.public_ip
  description = "Public IP of Jenkins instance"
}
