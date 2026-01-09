variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "k8s_version" {
  description = "Kubernetes version for EKS"
  type        = string
  default     = "1.29"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "kubernetes-resilience-lab"
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "krl-eks"
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.20.0.0/16"
}

variable "node_instance_types" {
  description = "List of EC2 instance types for worker nodes"
  type        = list(string)
  default     = ["t3.large"]
}

variable "desired_size" {
  description = "Desired number of worker nodes"
  type        = number
  default     = 2
}

variable "min_size" {
  description = "Minimum number of worker nodes"
  type        = number
  default     = 2
}

variable "max_size" {
  description = "Maximum number of worker nodes"
  type        = number
  default     = 4
}

variable "db_instance_class" {
  type    = string
  default = "db.t4g.micro"
}

variable "db_engine_version" {
  type    = string
  default = "15"
}

variable "db_name" {
  type    = string
  default = "resilience"
}

variable "db_username" {
  type    = string
  default = "appuser"
}
