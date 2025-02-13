resource "aws_vpc" "main" {
  cidr_block = "192.168.3.0/24"

  tags = {
    Name = "custom-vpc"
  }
}

resource "aws_subnet" "public1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "192.168.3.0/26"
  availability_zone = "ap-southeast-2a"
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet1"
  }
}

resource "aws_subnet" "public2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "192.168.3.64/26"
  availability_zone = "ap-southeast-2b"
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet2"
  }
}

resource "aws_subnet" "private1" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "192.168.3.128/26"
  availability_zone = "ap-southeast-2a"
  tags = {
    Name = "private-subnet1"
  }
}

resource "aws_subnet" "private2" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "192.168.3.192/26"
  availability_zone = "ap-southeast-2b"
  tags = {
    Name = "private-subnet2"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "custom-igw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "public-route-table"
  }
}

resource "aws_route_table_association" "publicr1" {
  subnet_id      = aws_subnet.public1.id
  
  route_table_id = aws_route_table.public.id
}
resource "aws_route_table_association" "publicr2" {
  subnet_id      = aws_subnet.public2.id
  
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "private-route-table"
  }
}

resource "aws_route_table_association" "privater1" {
  subnet_id      = aws_subnet.private1.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "privater2" {
  subnet_id      = aws_subnet.private2.id
  route_table_id = aws_route_table.private.id
}



output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_id" {
  value = [aws_subnet.public1.id,aws_subnet.public2.id]
}

output "private_subnet_id" {
  value = [aws_subnet.private1.id,aws_subnet.private2.id]
}

resource "aws_security_group" "example" {
  vpc_id = aws_vpc.main.id
  name   = "linux"
  description = "Example security group"

  ingress {
    description      = "Allow SSH"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    description      = "Allow HTTP"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    description      = "Allow MySql/Aurora"
    from_port        = 3306
    to_port          = 3306
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    description      = "Allow HTTPS"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    description      = "Allow all outbound traffic"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = {
    Name = "linux"
  }
}

output "security_group_id" {
  value = aws_security_group.example.id
}

# Create Security Group for RDS
resource "aws_security_group" "rds_sg" {
  vpc_id = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 3306  # Change this port to match your RDS database port
    to_port     = 3306
    protocol    = "tcp"
    security_groups = [aws_security_group.example.id]
  }

  tags = {
    Name = "rds_sg"
  }
}

# Create RDS Subnet Group
resource "aws_db_subnet_group" "mydb_subnet_group" {
  name        = "mydb_subnet_group"
  subnet_ids  = [aws_subnet.private1.id,aws_subnet.private2.id]

  tags = {
    Name = "mydb_subnet_group"
  }
}

# Create RDS Instance
resource "aws_db_instance" "mydb" {
  allocated_storage    = 20
  storage_type         = "gp2"
  engine               = "mysql"
  engine_version       = "8.0.35"
  instance_class       = "db.t3.micro"
  db_name              = "Students"
  username             = "admin"
  password             = "Prajna0312."
  db_subnet_group_name = aws_db_subnet_group.mydb_subnet_group.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  publicly_accessible  = false
  backup_retention_period = 0  # Disable automated backups
  skip_final_snapshot  = true  # Skip final snapshot
  tags = {
    Name = "mydb_instance"
  }
}


resource "aws_instance" "example_server1" {
  ami           = "ami-09f5ddaab17f5ff43"
  instance_type = "t2.micro"
  key_name = "bangtan_sy"
  subnet_id = aws_subnet.public1.id
  associate_public_ip_address = true
  vpc_security_group_ids = [aws_security_group.example.id]

  connection {
    type        = "ssh"
    user        = "ec2-user"
    host        = self.public_ip
    private_key = file("C:/Users/HP/bangtan_sy.pem")
  }

  provisioner "remote-exec" {
    inline = [
      "sudo dnf install httpd php php-mysqli mariadb105 -y",
      "sudo systemctl start httpd",
      "sudo systemctl enable httpd",
      "sudo chown -R ec2-user /var/www/"
    ]
  }

  provisioner "file" {
    content     = <<-EOF
    <?php

     define('DB_SERVER', '${aws_db_instance.mydb.address}');
     define('DB_USERNAME', 'admin');
     define('DB_PASSWORD', 'Prajna0312.');
     define('DB_DATABASE', 'Students');

    ?>
     EOF
     destination = "/var/www/html/dbinfo.inc"
  }

  provisioner "file" {
    source      = "C:/Users/HP/index.php"
    destination = "/var/www/html/index.php"
  }

  tags = {
    Name = "server_rds"
  }
}

output "public_ip_address_nv"{
  value = [aws_instance.example_server1.public_dns, aws_instance.example_server1.public_ip]
   
}

