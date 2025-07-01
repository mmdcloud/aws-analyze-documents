# VPC Configuration
module "vpc" {
  source                = "./modules/vpc/vpc"
  vpc_name              = "document-analyzer-vpc"
  vpc_cidr_block        = "10.0.0.0/16"
  enable_dns_hostnames  = true
  enable_dns_support    = true
  internet_gateway_name = "vpc_igw"
}

# Security Group
module "security_group" {
  source = "./modules/vpc/security_groups"
  vpc_id = module.vpc.vpc_id
  name   = "document-analyzer-security-group"
  ingress = [
    {
      from_port       = 80
      to_port         = 80
      protocol        = "tcp"
      self            = "false"
      cidr_blocks     = ["0.0.0.0/0"]
      security_groups = []
      description     = "any"
    },
    {
      from_port       = 22
      to_port         = 22
      protocol        = "tcp"
      self            = "false"
      cidr_blocks     = ["0.0.0.0/0"]
      security_groups = []
      description     = "any"
    }
  ]
  egress = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]
}

# Public Subnets
module "public_subnets" {
  source = "./modules/vpc/subnets"
  name   = "document-analyzer-public-subnet"
  subnets = [
    {
      subnet = "10.0.1.0/24"
      az     = "us-east-1a"
    },
    {
      subnet = "10.0.2.0/24"
      az     = "us-east-1b"
    },
    {
      subnet = "10.0.3.0/24"
      az     = "us-east-1c"
    }
  ]
  vpc_id                  = module.vpc.vpc_id
  map_public_ip_on_launch = true
}

# Private Subnets
module "private_subnets" {
  source = "./modules/vpc/subnets"
  name   = "document-analyzer-private-subnet"
  subnets = [
    {
      subnet = "10.0.6.0/24"
      az     = "us-east-1a"
    },
    {
      subnet = "10.0.5.0/24"
      az     = "us-east-1b"
    },
    {
      subnet = "10.0.4.0/24"
      az     = "us-east-1c"
    }
  ]
  vpc_id                  = module.vpc.vpc_id
  map_public_ip_on_launch = false
}

# Public Route Table
module "public_rt" {
  source  = "./modules/vpc/route_tables"
  name    = "document-analyzer-public-route-table"
  subnets = module.public_subnets.subnets[*]
  routes = [
    {
      cidr_block = "0.0.0.0/0"
      gateway_id = module.vpc.igw_id
    }
  ]
  vpc_id = module.vpc.vpc_id
}

# Private Route Table
module "private_rt" {
  source  = "./modules/vpc/route_tables"
  name    = "document-analyzer-private-route-table"
  subnets = module.private_subnets.subnets[*]
  routes  = []
  vpc_id  = module.vpc.vpc_id
}

# Cognito User Pool
module "cognito" {
  source                     = "./modules/cognito"
  name                       = "document_analyzer_users"
  username_attributes        = ["email"]
  auto_verified_attributes   = ["email"]
  password_minimum_length    = 8
  password_require_lowercase = true
  password_require_numbers   = true
  password_require_symbols   = true
  password_require_uppercase = true
  schema = [
    {
      attribute_data_type = "String"
      name                = "email"
      required            = true
    }
  ]
  verification_message_template_default_email_option = "CONFIRM_WITH_CODE"
  verification_email_subject                         = "Verify your email for Document Analyzer"
  verification_email_message                         = "Your verification code is {####}"
  user_pool_clients = [
    {
      name                                 = "document_analyzer_cognito_client"
      generate_secret                      = false
      explicit_auth_flows                  = ["ALLOW_USER_PASSWORD_AUTH", "ALLOW_REFRESH_TOKEN_AUTH"]
      allowed_oauth_flows_user_pool_client = true
      allowed_oauth_flows                  = ["code", "implicit"]
      allowed_oauth_scopes                 = ["email", "openid"]
      callback_urls                        = ["https://example.com/callback"]
      logout_urls                          = ["https://example.com/logout"]
      supported_identity_providers         = ["COGNITO"]
    }
  ]
}

# DynamoDB Table
module "document_records" {
  source = "./modules/dynamodb"
  name   = "document-records"
  attributes = [
    {
      name = "RecordId"
      type = "S"
    },
    {
      name = "filename"
      type = "S"
    }
  ]
  billing_mode          = "PROVISIONED"
  hash_key              = "RecordId"
  range_key             = "filename"
  read_capacity         = 20
  write_capacity        = 20
  ttl_attribute_name    = "TimeToExist"
  ttl_attribute_enabled = true
}

# Document upload queue
module "document_upload_queue" {
  source                        = "./modules/sqs"
  queue_name                    = "document-upload-queue"
  delay_seconds                 = 0
  maxReceiveCount               = 3
  dlq_message_retention_seconds = 86400
  dlq_name                      = "document-upload-dlq"
  max_message_size              = 262144
  message_retention_seconds     = 345600
  visibility_timeout_seconds    = 180
  receive_wait_time_seconds     = 20
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "s3.amazonaws.com" }
        Action    = "sqs:SendMessage"
        Resource  = "arn:aws:sqs:${var.region}:*:document-upload-queue"
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = module.document_storage_bucket.arn
          }
        }
      }
    ]
  })
}

# Document Storage Bucket
module "document_storage_bucket" {
  source             = "./modules/s3"
  bucket_name        = "document-storage-${var.environment}"
  objects            = []
  versioning_enabled = "Enabled"
  bucket_notification = {
    queue = [
      {
        queue_arn = module.document_upload_queue.arn
        events    = ["s3:ObjectCreated:*"]
      }
    ]
    lambda_function = []
  }
  cors = [
    {
      allowed_headers = ["*"]
      allowed_methods = ["PUT", "POST", "GET"]
      allowed_origins = ["*"]
      max_age_seconds = 3000
    }
  ]
  force_destroy = true
}

# EC2 IAM Instance Profile
data "aws_iam_policy_document" "instance_profile_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "instance_profile_iam_role" {
  name               = "document-analyzer-instance-profile-role"
  path               = "/"
  assume_role_policy = data.aws_iam_policy_document.instance_profile_assume_role.json
}

data "aws_iam_policy_document" "instance_profile_policy_document" {
  statement {
    effect    = "Allow"
    actions   = ["s3:*"]
    resources = ["${module.mediaconvert_source_bucket.arn}/*"]
  }
  statement {
    effect    = "Allow"
    actions   = ["cloudwatch:*"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "instance_profile_s3_policy" {
  role   = aws_iam_role.instance_profile_iam_role.name
  policy = data.aws_iam_policy_document.instance_profile_policy_document.json
}

resource "aws_iam_instance_profile" "iam_instance_profile" {
  name = "document-analyzer-iam-instance-profile"
  role = aws_iam_role.instance_profile_iam_role.name
}

# Frontend Instance
module "document_analyzer_frontend_instance" {
  source                      = "./modules/ec2"
  name                        = "document-analyzer-frontend-instance"
  ami_id                      = data.aws_ami.ubuntu.id
  instance_type               = "t2.micro"
  key_name                    = "madmaxkeypair"
  associate_public_ip_address = true
  user_data                   = filebase64("${path.module}/scripts/user_data.sh")
  instance_profile            = aws_iam_instance_profile.iam_instance_profile.name
  subnet_id                   = module.public_subnets.subnets[0].id
  security_groups             = [module.security_group.id]
}
