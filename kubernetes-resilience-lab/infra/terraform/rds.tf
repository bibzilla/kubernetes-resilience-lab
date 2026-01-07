############################################
# RDS Postgres (private) for the lab
############################################

resource "aws_db_subnet_group" "postgres" {
  name       = "${var.project_name}-postgres-subnets"
  subnet_ids = [for s in aws_subnet.private : s.id]

  tags = {
    Project = var.project_name
    Owner   = "bibi"
  }
}

resource "aws_security_group" "postgres" {
  name        = "${var.project_name}-postgres-sg"
  description = "Allow Postgres from EKS nodes/cluster security group"
  vpc_id      = aws_vpc.this.id

  tags = {
    Project = var.project_name
    Owner   = "bibi"
  }
}

# Allow Postgres only from the EKS cluster security group
resource "aws_security_group_rule" "postgres_ingress_from_eks" {
  type                     = "ingress"
  security_group_id        = aws_security_group.postgres.id
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
  description              = "Postgres from EKS cluster security group"
}

resource "aws_security_group_rule" "postgres_egress_all" {
  type              = "egress"
  security_group_id = aws_security_group.postgres.id
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow all egress"
}

resource "random_password" "postgres" {
  length  = 24
  special = true
}

resource "aws_secretsmanager_secret" "postgres" {
  name = "${var.project_name}/postgres"
  tags = {
    Project = var.project_name
    Owner   = "bibi"
  }
}

resource "aws_secretsmanager_secret_version" "postgres" {
  secret_id = aws_secretsmanager_secret.postgres.id

  secret_string = jsonencode({
    username = var.db_username
    password = random_password.postgres.result
    dbname   = var.db_name
    port     = 5432
  })
}

resource "aws_db_instance" "postgres" {
  identifier        = "${var.project_name}-postgres"
  engine            = "postgres"
  engine_version    = var.db_engine_version
  instance_class    = var.db_instance_class
  allocated_storage = 20
  storage_type      = "gp3"

  db_subnet_group_name   = aws_db_subnet_group.postgres.name
  vpc_security_group_ids = [aws_security_group.postgres.id]

  username = var.db_username
  password = random_password.postgres.result
  db_name  = var.db_name

  publicly_accessible = false
  multi_az            = false

  skip_final_snapshot = true
  deletion_protection = false

  tags = {
    Project = var.project_name
    Owner   = "bibi"
  }
}
