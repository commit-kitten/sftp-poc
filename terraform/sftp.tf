resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# Generate SSH key pair for SFTP user access
resource "tls_private_key" "sftp_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# S3 bucket simulating "external" SFTP storage
resource "aws_s3_bucket" "sftp_source_bucket" {
  bucket = "sftp-source-bucket-${random_id.bucket_suffix.hex}"
}


# S3 bucket to act as the sync destination
resource "aws_s3_bucket" "sftp_destination_bucket" {
  bucket = "sftp-destination-bucket-${random_id.bucket_suffix.hex}"
}

output "sftp_destination_bucket_name" {
  value       = aws_s3_bucket.sftp_destination_bucket.bucket
  description = "The full name of the SFTP destination bucket with unique suffix."
}

resource "aws_s3_bucket_ownership_controls" "destination_bucket_ownership_controls" {
  bucket = aws_s3_bucket.sftp_destination_bucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "destination_bucket_acl" {
  depends_on = [aws_s3_bucket_ownership_controls.destination_bucket_ownership_controls]

  bucket = aws_s3_bucket.sftp_destination_bucket.id
  acl    = "private"
}

resource "aws_s3_bucket_versioning" "destination_bucket_versioning" {
  bucket = aws_s3_bucket.sftp_destination_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

# IAM role for AWS Transfer Family server to access SFTP source bucket
data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["transfer.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "sftp_access_role" {
  name               = "SftpAccessRole"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

# Policy to allow access to only the SFTP source bucket
data "aws_iam_policy_document" "sftp_source_policy" {
  statement {
    effect  = "Allow"
    actions = ["s3:ListBucket", "s3:GetObject", "s3:PutObject"]
    resources = [
      aws_s3_bucket.sftp_source_bucket.arn,
      "${aws_s3_bucket.sftp_source_bucket.arn}/*"
    ]
  }
}

resource "aws_iam_role_policy" "sftp_source_policy_attachment" {
  name   = "SftpSourcePolicy"
  role   = aws_iam_role.sftp_access_role.id
  policy = data.aws_iam_policy_document.sftp_source_policy.json
}

# AWS Transfer Family server configured for SFTP protocol
resource "aws_transfer_server" "sftp_server" {
  identity_provider_type = "SERVICE_MANAGED"
  endpoint_type          = "PUBLIC"
  protocols              = ["SFTP"]

  tags = {
    Name = "SFTP Simulation Server"
  }
}

output "sftp_host" {
  value       = aws_transfer_server.sftp_server.endpoint
  description = "The endpoint URL for the AWS Transfer Family SFTP server"
}

# Transfer Family user with assigned SSH public key
resource "aws_transfer_user" "sftp_user" {
  server_id      = aws_transfer_server.sftp_server.id
  user_name      = "sftp-sync-user"
  role           = aws_iam_role.sftp_access_role.arn
  home_directory = "/${aws_s3_bucket.sftp_source_bucket.bucket}"

  tags = {
    Name = "SFTP Sync User"
  }
}

# Associate SSH public key with Transfer Family user
resource "aws_transfer_ssh_key" "sftp_user_key" {
  server_id = aws_transfer_server.sftp_server.id
  user_name = aws_transfer_user.sftp_user.user_name
  body      = trimspace(tls_private_key.sftp_key.public_key_openssh)
}

# Output private key for secure storage in GitHub Secrets (temporary for setup)
output "sftp_private_key" {
  value     = tls_private_key.sftp_key.private_key_pem
  sensitive = true
}
