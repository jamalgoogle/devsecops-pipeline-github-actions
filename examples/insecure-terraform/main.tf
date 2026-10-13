# INTENTIONALLY INSECURE - used only to demonstrate the pipeline failing.
# This directory is excluded from the CI scan. Run it by hand with:
#   ./scripts/run-local-scans.sh examples
# Never apply this configuration.

resource "aws_s3_bucket" "public_data" {
  bucket = "novacart-demo-public-data"
  acl    = "public-read"
}

resource "aws_security_group" "open_ssh" {
  name        = "demo-open-ssh"
  description = "SSH open to the whole internet"

  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_instance" "unencrypted" {
  identifier          = "novacart-demo-db"
  engine              = "postgres"
  instance_class      = "db.t3.micro"
  allocated_storage   = 20
  username            = "admin"
  password            = "change-me-please"
  publicly_accessible = true
  storage_encrypted   = false
  skip_final_snapshot = true
}
