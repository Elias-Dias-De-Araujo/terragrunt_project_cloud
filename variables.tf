variable "aws_profile" {
  description = "aws profile to deploy infra"
  type = string
}

variable "aws_region" {
  description = "Region of aws that the resources will be provisioned"
  type        = string
  nullable    = false
}

variable "aws_vpc_name" {
  description = "Name of the vpc"
  type        = string
  nullable    = false
}

variable "aws_vpc_cidr" {
  description = "Available cidr block"
  type        = string
  nullable    = false
}

variable "aws_vpc_azs" {
  description = "Set of azs"
  type        = set(string)
  nullable    = false
}

variable "aws_vpc_private_subnets" {
  description = "Set of private subnets"
  type        = set(string)
  nullable    = false
}

variable "aws_vpc_public_subnets" {
  description = "Set of public subnets"
  type        = set(string)
  nullable    = false
}

variable "aws_eks_name" {
  description = "Name of eks"
  type        = string
  nullable    = false
}

variable "aws_eks_version" {
  description = "Version of eks"
  type        = string
  nullable    = false
}

variable "aws_eks_managed_node_groups_instance_types" {
  description = "Types of node instances available to the cluster"
  type        = set(string)
  nullable    = false
}

variable "aws_project_tags" {
  description = "Tags of project"
  type        = map(any)
  nullable    = false
}

variable "db_identifier" {
  description = "identifier of database"
  type        = string
  nullable    = false
}

variable "additional_policies" {
  description = "A map of additional IAM policies to attach to the EKS node group role"
  type        = map(string)
}

# variable "WORDPRESS_DB_NAME" {
#   description = "The WordPress database name"
#   type        = string
# }

# variable "WORDPRESS_DB_USER" {
#   description = "The WordPress database user"
#   type        = string
# }

# variable "WORDPRESS_DB_PASSWORD" {
#   description = "The WordPress database password"
#   type        = string
# }

# variable "WORDPRESS_DB_HOST" {
#   description = "The WordPress database host"
#   type        = string
# }


# variable "node_security_group_additional_rules" {
#   description = "Additional security group rules for the node group"
#   type        = map(object({
#     description = string
#     from_port   = number
#     to_port     = number
#     protocol    = string
#     cidr_blocks = string
#   }))
#   default = {}
# }
