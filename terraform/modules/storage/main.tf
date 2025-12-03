# EFS Security Group
# Note: Ingress rule will be added via security_group_rule in root module
# to avoid circular dependency with ECS module
resource "aws_security_group" "efs" {
  name        = "minecraft-efs-sg"
  description = "Security group for EFS mount targets"
  vpc_id      = var.vpc_id

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    {
      Name = "minecraft-efs-sg"
    },
    var.tags
  )
}

# EFS File System
resource "aws_efs_file_system" "main" {
  creation_token   = "minecraft-efs"
  performance_mode = var.performance_mode
  throughput_mode  = "bursting"
  encrypted        = true

  tags = merge(
    {
      Name = "minecraft-efs"
    },
    var.tags
  )
}

# EFS Mount Targets (one per subnet/AZ)
resource "aws_efs_mount_target" "main" {
  count = length(var.subnet_ids)

  file_system_id  = aws_efs_file_system.main.id
  subnet_id       = var.subnet_ids[count.index]
  security_groups = [aws_security_group.efs.id]
}

