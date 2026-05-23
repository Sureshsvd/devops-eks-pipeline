resource "tls_private_key" "eks_node_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "aws_key_pair" "eks_node" {
  key_name   = "eks-node-key"
  public_key = tls_private_key.eks_node_key.public_key_openssh
}

resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "main-eks-node-group"
  node_role_arn   = aws_iam_role.eks_node_group.arn
  subnet_ids      = [aws_subnet.private_a.id, aws_subnet.private_b.id]

  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 1
  }

  instance_types = ["t3.micro"]
  ami_type       = "AL2_x86_64"
  capacity_type  = "ON_DEMAND"

  remote_access {
    ec2_ssh_key = aws_key_pair.eks_node.key_name
  }

  tags = {
    Name = "main-eks-node-group"
  }

  depends_on = [
    aws_eks_cluster.main,
  ]
}
