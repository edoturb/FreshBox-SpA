resource "aws_db_subnet_group" "freshbox_db_subnet" {
  name       = "freshbox-db-subnet-group"
  subnet_ids = [aws_subnet.private_data_1a.id, aws_subnet.private_data_1b.id]

  tags = { Name = "freshbox-db-subnet-group" }
}

resource "aws_db_instance" "freshbox_rds" {
  allocated_storage      = 20
  max_allocated_storage  = 50
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = "db.t3.micro"
  db_name                = var.db_name
  username               = var.db_user
  password               = var.db_password
  db_subnet_group_name   = aws_db_subnet_group.freshbox_db_subnet.name
  vpc_security_group_ids = [aws_security_group.data.id]
  multi_az               = true
  skip_final_snapshot    = true

  tags = { Name = "freshbox-rds-mysql" }
}
