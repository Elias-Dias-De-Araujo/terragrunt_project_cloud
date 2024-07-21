provider "aws" {
  profile = var.aws_profile
  region  = var.aws_region
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate =  base64decode(module.eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.auth.token
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.auth.token
  }
}

data "aws_eks_cluster" "cluster" {
  name = module.eks.cluster_name
  depends_on = [ module.eks ]
}

data "aws_eks_cluster_auth" "auth" {
  name = module.eks.cluster_name
  depends_on = [ module.eks ]
}

terraform {
  backend "local" {
    path = "terraform.tfstate"
  }
}

