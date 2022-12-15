terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.46.0"
    }
  }
}

provider "aws" {
  access_key = var.access_key
  secret_key = var.secret_key
  region     = var.region
}

resource "aws_s3_bucket" "kubernetes_events_bucket" {
  bucket        = "kubernetes-events-bucket"
  force_destroy = true
  tags          = {
    Managed = "terraform"
  }
}

resource "aws_s3_bucket_acl" "kubernetes_events_bucket_acl" {
  bucket = aws_s3_bucket.kubernetes_events_bucket.id
  acl    = "private"
}

resource "aws_iam_role" "firehose_role" {
  name               = "firehose_role_events_bucket"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "firehose.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
EOF
  tags               = {
    Managed = "terraform"
  }
}

resource "aws_iam_role_policy" "firehose_role_policy" {
  name   = "firehose_role_events_bucket_inline_policy"
  role   = aws_iam_role.firehose_role.id
  policy = jsonencode({
    Version : "2012-10-17"
    Statement : [
      {
        Action : [
          "s3:AbortMultipartUpload",
          "s3:GetBucketLocation",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:ListBucketMultipartUploads",
          "s3:PutObject"
        ],
        Effect : "Allow"
        Resource : [
          aws_s3_bucket.kubernetes_events_bucket.arn,
          "${aws_s3_bucket.kubernetes_events_bucket.arn}/*"
        ]
      },
      {
        Action : [
          "kinesis:DescribeStream",
          "kinesis:GetShardIterator",
          "kinesis:GetRecords",
          "kinesis:ListShards"
        ],
        Effect : "Allow"
        Resource : [
          aws_kinesis_firehose_delivery_stream.firehose_s3_stream.arn
        ]
      }
    ]
  })
}

resource "aws_kinesis_firehose_delivery_stream" "firehose_s3_stream" {
  name        = "firehose-events-stream"
  destination = "extended_s3"
  extended_s3_configuration {
    role_arn            = aws_iam_role.firehose_role.arn
    bucket_arn          = aws_s3_bucket.kubernetes_events_bucket.arn
    prefix              = "data/namespace=!{partitionKeyFromQuery:namespace}/dt=!{timestamp:yyyy}-!{timestamp:MM}-!{timestamp:dd}/"
    error_output_prefix = "errors/dt=!{timestamp:yyyy}-!{timestamp:MM}-!{timestamp:dd}/!{firehose:error-output-type}/"
    buffer_size         = 64
    processing_configuration {
      enabled = true
      processors {
        type = "AppendDelimiterToRecord"
      }
      processors {
        type = "MetadataExtraction"
        parameters {
          parameter_name  = "JsonParsingEngine"
          parameter_value = "JQ-1.6"
        }
        parameters {
          parameter_name  = "MetadataExtractionQuery"
          parameter_value = "{namespace:.namespace}"
        }
      }
    }
    dynamic_partitioning_configuration {
      enabled = true
    }
  }
  tags = {
    Managed = "terraform"
  }
}
