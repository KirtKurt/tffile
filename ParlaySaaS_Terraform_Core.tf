
terraform {
  required_version = ">= 1.4.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# S3 Bucket for odds data
resource "aws_s3_bucket" "odds_data" {
  bucket = "parlaysaas-odds-data-${random_id.bucket_suffix.hex}"
  force_destroy = true
}

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# DynamoDB Table for normalized odds
resource "aws_dynamodb_table" "odds_table" {
  name           = "ParlayOddsTable"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "GameID"

  attribute {
    name = "GameID"
    type = "S"
  }
}

# IAM Role for Lambda functions
resource "aws_iam_role" "lambda_exec_role" {
  name = "ParlayLambdaExecutionRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

# Attach policies to Lambda execution role
resource "aws_iam_role_policy" "lambda_policy" {
  name = "ParlayLambdaPolicy"
  role = aws_iam_role.lambda_exec_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:*",
          "dynamodb:*",
          "s3:*",
          "events:*"
        ]
        Resource = "*"
      }
    ]
  })
}

# Lambda function for Odds ETL placeholder
resource "aws_lambda_function" "odds_etl_lambda" {
  function_name = "ParlayOddsETL"
  role          = aws_iam_role.lambda_exec_role.arn
  runtime       = "python3.12"
  handler       = "lambda_function.lambda_handler"

  filename         = "lambda_package/odds_etl_placeholder.zip"
  source_code_hash = filebase64sha256("lambda_package/odds_etl_placeholder.zip")

  environment {
    variables = {
      ODDS_API_KEY = "INSERT-YOUR-ODDSAPI-KEY-HERE"
    }
  }
}

# EventBridge rule to trigger ETL daily
resource "aws_cloudwatch_event_rule" "etl_schedule" {
  name                = "OddsETLDailyTrigger"
  schedule_expression = "rate(1 day)"
}

resource "aws_cloudwatch_event_target" "etl_target" {
  rule      = aws_cloudwatch_event_rule.etl_schedule.name
  target_id = "OddsETLLambda"
  arn       = aws_lambda_function.odds_etl_lambda.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.odds_etl_lambda.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.etl_schedule.arn
}

# Cognito User Pool for authentication
resource "aws_cognito_user_pool" "user_pool" {
  name = "ParlayUserPool"
}

# API Gateway REST API scaffold
resource "aws_api_gateway_rest_api" "api" {
  name        = "ParlayAPI"
  description = "REST API scaffold for Parlay SaaS"
}
