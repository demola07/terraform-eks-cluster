################################################################################
# Bastion/Jump Box for EKS Access
################################################################################

# Security Group for Bastion
resource "aws_security_group" "bastion" {
  name        = "${var.cluster-name}-bastion-sg"
  description = "Security group for bastion host"
  vpc_id      = module.vpc.vpc_id

  # SSH access (only if enabled)
  dynamic "ingress" {
    for_each = var.bastion_enable_ssh ? [1] : []
    content {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = var.bastion_allowed_cidrs
      description = "SSH access from allowed IPs"
    }
  }

  # Outbound to anywhere (for kubectl, aws cli, etc.)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = {
    Name        = "${var.cluster-name}-bastion-sg"
    Environment = var.env
    ManagedBy   = "Terraform"
  }
}

# Allow bastion to access EKS cluster control plane
resource "aws_security_group_rule" "bastion_to_cluster" {
  count = var.enable_bastion ? 1 : 0

  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = module.eks.cluster_security_group_id
  source_security_group_id = aws_security_group.bastion.id
  description              = "Allow bastion to access EKS cluster API"
}

# IAM Role for Bastion (to access EKS)
resource "aws_iam_role" "bastion" {
  name = "${var.cluster-name}-bastion-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })

  tags = {
    Name        = "${var.cluster-name}-bastion-role"
    Environment = var.env
    ManagedBy   = "Terraform"
  }
}

# Attach policies to bastion role
resource "aws_iam_role_policy_attachment" "bastion_eks_read" {
  role       = aws_iam_role.bastion.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role_policy_attachment" "bastion_ssm" {
  role       = aws_iam_role.bastion.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Custom policy for EKS access
resource "aws_iam_role_policy" "bastion_eks_access" {
  name = "${var.cluster-name}-bastion-eks-access"
  role = aws_iam_role.bastion.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters",
          "eks:DescribeNodegroup",
          "eks:ListNodegroups",
          "eks:AccessKubernetesApi"
        ]
        Resource = "*"
      }
    ]
  })
}

# IAM Instance Profile
resource "aws_iam_instance_profile" "bastion" {
  name = "${var.cluster-name}-bastion-profile"
  role = aws_iam_role.bastion.name

  tags = {
    Name        = "${var.cluster-name}-bastion-profile"
    Environment = var.env
    ManagedBy   = "Terraform"
  }
}

# Get latest Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Bastion EC2 Instance
resource "aws_instance" "bastion" {
  count = var.enable_bastion ? 1 : 0

  ami           = data.aws_ami.amazon_linux_2023.id
  instance_type = var.bastion_instance_type
  key_name      = var.bastion_enable_ssh ? var.bastion_key_name : null

  subnet_id                   = module.vpc.public_subnets[0]
  vpc_security_group_ids      = [aws_security_group.bastion.id]
  iam_instance_profile        = aws_iam_instance_profile.bastion.name
  associate_public_ip_address = true

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 30  # Amazon Linux 2023 requires minimum 30GB
    encrypted             = true
    delete_on_termination = true
  }

  user_data = base64encode(templatefile("${path.module}/bastion-userdata.sh", {
    cluster_name = var.cluster-name
    aws_region   = data.aws_region.current.name
  }))

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  tags = {
    Name        = "${var.cluster-name}-bastion"
    Environment = var.env
    ManagedBy   = "Terraform"
  }
}

# Elastic IP for Bastion (optional but recommended)
resource "aws_eip" "bastion" {
  count = var.enable_bastion ? 1 : 0

  instance = aws_instance.bastion[0].id
  domain   = "vpc"

  tags = {
    Name        = "${var.cluster-name}-bastion-eip"
    Environment = var.env
    ManagedBy   = "Terraform"
  }
}
