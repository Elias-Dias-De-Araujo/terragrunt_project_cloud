module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.8.1"

  name = var.aws_vpc_name
  cidr = var.aws_vpc_cidr

  azs             = var.aws_vpc_azs
  private_subnets = var.aws_vpc_private_subnets
  public_subnets  = var.aws_vpc_public_subnets

  enable_nat_gateway = true
  enable_vpn_gateway = true

  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(var.aws_project_tags, { "kubernetes.io/cluster/${var.aws_eks_name}" = "shared" })

  public_subnet_tags = {
    "kubernetes.io/cluster/${var.aws_eks_name}" = "shared"
    "kubernetes.io/role/elb"                    = 1
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${var.aws_eks_name}" = "shared"
    "kubernetes.io/role/internal-elb"           = 1
  }
}

resource "aws_iam_policy" "security_group_policy" {
  name        = "SecurityGroupPolicy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateSecurityGroup",
          "ec2:DescribeSecurityGroups",
          "ec2:DeleteSecurityGroup",
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:AuthorizeSecurityGroupEgress",
          "ec2:RevokeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupEgress"
        ]
        Resource = "*"
      }
    ]
  })
}

module "load_balancer_security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 4.0"

  name        = "load-balancer-sg"
  description = "Security group for the Load Balancer"
  vpc_id      = module.vpc.vpc_id

  ingress_with_cidr_blocks = [
    {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      description = "Allow HTTP traffic from any IP"
      cidr_blocks = "0.0.0.0/0"
    },
    {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      description = "Allow HTTPS traffic from any IP"
      cidr_blocks = "0.0.0.0/0"
    }
  ]

  egress_rules = ["all-all"]
}

module "eks_security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 4.0"

  name        = "eks-nodes-sg"
  description = "Security group for all nodes in the EKS cluster"
  vpc_id      = module.vpc.vpc_id

  ingress_with_cidr_blocks = [
    {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      description = "Allow HTTPS traffic from any IP"
      cidr_blocks = "0.0.0.0/0"
    },
    {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      description = "Allow HTTP traffic from any IP"
      cidr_blocks = "0.0.0.0/0"
    }
  ]

  egress_rules = ["all-all"]
}

module "rds_security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 4.0"

  name        = "rds-sg"
  description = "Security group for the RDS instance"
  vpc_id      = module.vpc.vpc_id

  ingress_with_source_security_group_id = [
    {
      rule                     = "mysql-tcp"
      source_security_group_id = module.eks.node_security_group_id
    },
  ]

  depends_on = [ module.eks ]

  egress_rules = ["all-all"]
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.13.0"

  cluster_name    = var.aws_eks_name
  cluster_version = var.aws_eks_version
  cluster_security_group_id = module.eks_security_group.security_group_id

  enable_cluster_creator_admin_permissions = true

  subnet_ids = module.vpc.private_subnets
  vpc_id     = module.vpc.vpc_id

  cluster_endpoint_public_access = true

  eks_managed_node_groups = {
    default = {
      min_size       = 1
      max_size       = 1
      desired_size   = 1
      instance_types = var.aws_eks_managed_node_groups_instance_types
      tags           = var.aws_project_tags
      iam_role_additional_policies = {
        SGPolicy = aws_iam_policy.security_group_policy.arn,
        EBSCSIDriver = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
      }
    }
  }

  node_security_group_additional_rules = {
    http = {
      description = "Allow HTTP traffic from Load Balancer"
      type        = "ingress"
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      source_node_security_group = true
    },
    https = {
      description = "Allow HTTPS traffic from Load Balancer"
      type        = "ingress"
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      source_node_security_group = true
    }
  }

  tags = var.aws_project_tags
}

module "rds" {
  source  = "terraform-aws-modules/rds/aws"
  version = "6.7.0"

  identifier = var.db_identifier
  engine            = "mysql"
  engine_version    = "8.0"
  instance_class    = "db.t3.micro"
  allocated_storage = 20

  db_name  = "ptc_terragrunt_db"
  username = "admin"
  password = "admin123"

  vpc_security_group_ids = [module.rds_security_group.security_group_id]

  tags = {
    Environment = "prod"
  }

  create_db_option_group = false
  create_db_parameter_group = false

  # DB subnet group
  create_db_subnet_group = true
  subnet_ids             = concat(
    module.vpc.private_subnets,
    module.vpc.public_subnets
  )
  
  multi_az = false
}

resource "helm_release" "aws_ebs_csi_driver" {
  name       = "aws-ebs-csi-driver"
  repository = "https://kubernetes-sigs.github.io/aws-ebs-csi-driver"
  chart      = "aws-ebs-csi-driver"
  namespace  = "kube-system"

  set {
    name  = "controller.replicas"
    value = "2"
  }

  set {
    name  = "node.tolerations[0].key"
    value = "CriticalAddonsOnly"
  }

  set {
    name  = "node.tolerations[0].operator"
    value = "Exists"
  }

  set {
    name  = "node.tolerations[1].key"
    value = "node.kubernetes.io/not-ready"
  }

  set {
    name  = "node.tolerations[1].operator"
    value = "Exists"
  }

  set {
    name  = "node.tolerations[1].effect"
    value = "NoExecute"
  }

  set {
    name  = "node.tolerations[2].key"
    value = "node.kubernetes.io/unreachable"
  }

  set {
    name  = "node.tolerations[2].operator"
    value = "Exists"
  }

  set {
    name  = "node.tolerations[2].effect"
    value = "NoExecute"
  }
}

resource "kubernetes_config_map" "wordpress-cm" {
  metadata {
    name = "wordpress-cm"
  }

  data = {
    WORDPRESS_DB_HOST: module.rds.db_instance_endpoint
    WORDPRESS_DB_NAME: "ptc_terragrunt_db"
  }
}

resource "kubernetes_secret" "wordpress-scrt" {
  metadata {
    name = "wordpress-scrt"
  }

  data = {
    WORDPRESS_DB_USER: "admin"
    WORDPRESS_DB_PASSWORD: "admin123"
    
  }
}

resource "kubernetes_storage_class" "wordpress-sc" {
  metadata {
    name = "immediate-binding-gp2"
  }
  storage_provisioner = "ebs.csi.aws.com"
  volume_binding_mode = "Immediate"
}

resource "kubernetes_persistent_volume_claim" "wordpress-pvc" {
  metadata {
    name = "wordpress-pvc"
    namespace = "default"
  }

  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "10Gi"
      }
    }
    storage_class_name = "immediate-binding-gp2"
  }
}


resource "kubernetes_deployment" "wordpress-deployment" {
  metadata {
    name = "wordpress-deployment"
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "wordpress"
      }
    }

    template {
      metadata {
        labels = {
          app = "wordpress"
        }
      }

      spec {
        container {
          name  = "wordpress"
          image = "wordpress:latest"

          env_from {
            config_map_ref {
              name = "wordpress-cm"
            }
          }

          env_from {
            secret_ref {
              name = "wordpress-scrt"
            }
          }

          port {
            container_port = 80
          }

          volume_mount {
            name      = "wordpress-data"
            mount_path = "/var/www/html"
          }
        }

        volume {
          name = "wordpress-data"

          persistent_volume_claim {
            claim_name = "wordpress-pvc"
          }
        }
      }
    }
  }
}


resource "kubernetes_service" "wordpress-svc" {
  metadata {
    name = "wordpress-svc"
    annotations = {
      "service.beta.kubernetes.io/aws-load-balancer-security-groups" = module.load_balancer_security_group.security_group_id
    }
  }

  spec {
    selector = {
      app = "wordpress"
    }

    port {
      port        = 80
      target_port = 80
    }

    type = "LoadBalancer"
  }
}
