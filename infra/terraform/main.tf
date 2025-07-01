resource "random_id" "random_id" {
  byte_length = 4
}

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
  name                       = "document-analyzer-users"
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
  bucket_name        = "document-storage-${random_id.random_id.hex}"
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
# Document Analyzer Lambda Function
module "documentanalyzer_function_code_bucket" {
  source      = "./modules/s3"
  bucket_name = "documentanalyzerfunctioncode"
  objects = [
    {
      key    = "documentanalyzer_function.zip"
      source = "./files/documentanalyzer_function.zip"
    }
  ]
  versioning_enabled = "Enabled"
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
module "documentanalyzer_get_presigned_url_function_code_bucket" {
  source      = "./modules/s3"
  bucket_name = "documentanalyzergetpresignedurlfunctioncode"
  objects = [
    {
      key    = "get_presigned_url.zip"
      source = "./files/get_presigned_url.zip"
    }
  ]
  versioning_enabled = "Enabled"
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

module "documentanalyzer_get_records_function_code_bucket" {
  source      = "./modules/s3"
  bucket_name = "documentanalyzergetrecordsfunctioncode"
  objects = [
    {
      key    = "get_records.zip"
      source = "./files/get_records.zip"
    }
  ]
  versioning_enabled = "Enabled"
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

# Lambda function IAM Role
module "documentanalyzer_function_iam_role" {
  source             = "./modules/iam"
  role_name          = "documentanalyzer_function_iam_role"
  role_description   = "documentanalyzer_function_iam_role"
  policy_name        = "documentanalyzer_function_iam_policy"
  policy_description = "documentanalyzer_function_iam_policy"
  assume_role_policy = <<EOF
    {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Action": "sts:AssumeRole",
                "Principal": {
                  "Service": "lambda.amazonaws.com"
                },
                "Effect": "Allow",
                "Sid": ""
            }
        ]
    }
    EOF
  policy             = <<EOF
    {
      "Version": "2012-10-17",
      "Statement": [
        {
            "Action": [
              "logs:CreateLogGroup",
              "logs:CreateLogStream",
              "logs:PutLogEvents"
            ],
            "Resource": "arn:aws:logs:*:*:*",
            "Effect": "Allow"
        }
      ]
    }
    EOF
}

module "documentanalyzer_lambda_function" {
  source        = "./modules/lambda"
  function_name = "documentanalyzer-lambda-function"
  role_arn      = module.documentanalyzer_function_iam_role.arn
  env_variables = {
    REGION = var.region
  }
  handler    = "documentanalyzer_function.lambda_handler"
  runtime    = "python3.12"
  s3_bucket  = module.documentanalyzer_function_code_bucket.bucket
  s3_key     = "documentanalyzer_function.zip"
  depends_on = [module.documentanalyzer_function_code_bucket]
}

# Lambda function to get presigned url
module "documentanalyzer_get_presigned_url_function" {
  source        = "./modules/lambda"
  function_name = "documentanalyzer-get-presigned-url-function"
  role_arn      = module.documentanalyzer_function_iam_role.arn
  env_variables = {
    REGION = var.region
  }
  permissions = [
    {
      statement_id = "InvokeGetPresignedUrl"
      action       = "lambda:InvokeFunction"
      principal    = "apigateway.amazonaws.com"
      source_arn   = "${aws_api_gateway_rest_api.documentanalyzer_rest_api.execution_arn}/*/*/get-presigned-url"
    }
  ]
  handler    = "get_presigned_url.lambda_handler"
  runtime    = "python3.12"
  s3_bucket  = module.documentanalyzer_get_presigned_url_function_code_bucket.bucket
  s3_key     = "get_presigned_url.zip"
  depends_on = [module.documentanalyzer_get_presigned_url_function_code_bucket]
}

# Lambda function to get processed records from DynamoDB
module "documentanalyzer_get_records_function" {
  source        = "./modules/lambda"
  function_name = "documentanalyzer-get-records-function"
  role_arn      = module.documentanalyzer_function_iam_role.arn
  env_variables = {
    REGION = var.region
  }
  permissions = [
    {
      statement_id = "InvokeGetRecords"
      action       = "lambda:InvokeFunction"
      principal    = "apigateway.amazonaws.com"
      source_arn   = "${aws_api_gateway_rest_api.documentanalyzer_rest_api.execution_arn}/*/*/get-records"
    }
  ]
  handler    = "get_records.lambda_handler"
  runtime    = "python3.12"
  s3_bucket  = module.documentanalyzer_get_records_function_code_bucket.bucket
  s3_key     = "get_records.zip"
  depends_on = [module.documentanalyzer_get_records_function_code_bucket]
}

# EC2 IAM Instance Profile
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

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
    resources = ["${module.document_storage_bucket.arn}/*"]
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

#  Lambda SQS event source mapping
resource "aws_lambda_event_source_mapping" "sqs_event_trigger" {
  event_source_arn                   = module.document_upload_queue.arn
  function_name                      = module.documentanalyzer_lambda_function.arn
  enabled                            = true
  batch_size                         = 10
  maximum_batching_window_in_seconds = 60
}

# API Gateway configuration
resource "aws_api_gateway_rest_api" "documentanalyzer_rest_api" {
  name = "documentanalyzer-api"
  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

# Authorizer Resource
# resource "aws_api_gateway_authorizer" "cognito_authorizer" {
#   name            = "documentanalyzer-cognito-authorizer"
#   rest_api_id     = aws_api_gateway_rest_api.documentanalyzer_rest_api.id
#   authorizer_uri  = module.documentanalyzer_api_authorizer_function.invoke_arn
#   identity_source = "method.request.header.Authorization"
#   type            = "REQUEST"
# }

resource "aws_api_gateway_resource" "documentanalyzer_resource_api" {
  rest_api_id = aws_api_gateway_rest_api.documentanalyzer_rest_api.id
  parent_id   = aws_api_gateway_rest_api.documentanalyzer_rest_api.root_resource_id
  path_part   = "get-presigned-url"
}

resource "aws_api_gateway_method" "documentanalyzer_resource_api_get_presigned_url_method" {
  rest_api_id      = aws_api_gateway_rest_api.documentanalyzer_rest_api.id
  resource_id      = aws_api_gateway_resource.documentanalyzer_resource_api.id
  api_key_required = false
  http_method      = "ANY"
  authorization    = "NONE"
  # authorizer_id    = aws_api_gateway_authorizer.cognito_authorizer.id
}

resource "aws_api_gateway_integration" "documentanalyzer_resource_api_get_presigned_url_method_integration" {
  rest_api_id             = aws_api_gateway_rest_api.documentanalyzer_rest_api.id
  resource_id             = aws_api_gateway_resource.documentanalyzer_resource_api.id
  http_method             = aws_api_gateway_method.documentanalyzer_resource_api_get_presigned_url_method.http_method
  integration_http_method = "ANY"
  type                    = "AWS_PROXY"
  uri                     = module.documentanalyzer_get_presigned_url_function.invoke_arn
}

resource "aws_api_gateway_method_response" "get_presigned_url_method_response_200" {
  rest_api_id = aws_api_gateway_rest_api.documentanalyzer_rest_api.id
  resource_id = aws_api_gateway_resource.documentanalyzer_resource_api.id
  http_method = aws_api_gateway_method.documentanalyzer_resource_api_get_presigned_url_method.http_method
  status_code = "200"
}

resource "aws_api_gateway_integration_response" "get_presigned_url_integration_response_200" {
  rest_api_id = aws_api_gateway_rest_api.documentanalyzer_rest_api.id
  resource_id = aws_api_gateway_resource.documentanalyzer_resource_api.id
  http_method = aws_api_gateway_method.documentanalyzer_resource_api_get_presigned_url_method.http_method
  status_code = aws_api_gateway_method_response.get_presigned_url_method_response_200.status_code
  depends_on = [
    aws_api_gateway_integration.documentanalyzer_resource_api_get_presigned_url_method_integration
  ]
}

# ---------------------------------------------------------------------------------------------------

resource "aws_api_gateway_resource" "documentanalyzer_get_records_api" {
  rest_api_id = aws_api_gateway_rest_api.documentanalyzer_rest_api.id
  parent_id   = aws_api_gateway_rest_api.documentanalyzer_rest_api.root_resource_id
  path_part   = "get-records"
}

resource "aws_api_gateway_method" "documentanalyzer_resource_api_get_records_method" {
  rest_api_id      = aws_api_gateway_rest_api.documentanalyzer_rest_api.id
  resource_id      = aws_api_gateway_resource.documentanalyzer_get_records_api.id
  api_key_required = false
  http_method      = "ANY"
  authorization    = "NONE"
  # authorizer_id    = aws_api_gateway_authorizer.cognito_authorizer.id
}

resource "aws_api_gateway_integration" "documentanalyzer_resource_api_get_records_method_integration" {
  rest_api_id             = aws_api_gateway_rest_api.documentanalyzer_rest_api.id
  resource_id             = aws_api_gateway_resource.documentanalyzer_get_records_api.id
  http_method             = aws_api_gateway_method.documentanalyzer_resource_api_get_records_method.http_method
  integration_http_method = "ANY"
  type                    = "AWS_PROXY"
  uri                     = module.documentanalyzer_get_records_function.invoke_arn
}

resource "aws_api_gateway_method_response" "get_records_method_response_200" {
  rest_api_id = aws_api_gateway_rest_api.documentanalyzer_rest_api.id
  resource_id = aws_api_gateway_resource.documentanalyzer_get_records_api.id
  http_method = aws_api_gateway_method.documentanalyzer_resource_api_get_records_method.http_method
  status_code = "200"
}

resource "aws_api_gateway_integration_response" "get_records_integration_response_200" {
  rest_api_id = aws_api_gateway_rest_api.documentanalyzer_rest_api.id
  resource_id = aws_api_gateway_resource.documentanalyzer_get_records_api.id
  http_method = aws_api_gateway_method.documentanalyzer_resource_api_get_records_method.http_method
  status_code = aws_api_gateway_method_response.get_records_method_response_200.status_code
  depends_on = [
    aws_api_gateway_integration.documentanalyzer_resource_api_get_records_method_integration
  ]
}

resource "aws_api_gateway_deployment" "documentanalyzer_api_deployment" {
  rest_api_id = aws_api_gateway_rest_api.documentanalyzer_rest_api.id
  lifecycle {
    create_before_destroy = true
  }
  depends_on = [aws_api_gateway_integration.documentanalyzer_resource_api_get_presigned_url_method_integration, aws_api_gateway_integration.documentanalyzer_resource_api_get_records_method_integration]
}

resource "aws_api_gateway_stage" "documentanalyzer_api_stage" {
  deployment_id = aws_api_gateway_deployment.documentanalyzer_api_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.documentanalyzer_rest_api.id
  stage_name    = "dev"
}