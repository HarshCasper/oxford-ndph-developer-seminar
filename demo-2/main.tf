terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.22.0"
    }
  }
}

resource "aws_s3_bucket" "original_images" {
  bucket = "original-images"

  force_destroy = true
}

resource "aws_s3_bucket" "resized_images" {
  bucket = "resized-images"

  force_destroy = true
}

resource "aws_dynamodb_table" "image_metadata" {
  name           = "ImageMetaData"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "ImageID"

  attribute {
    name = "ImageID"
    type = "S"
  }

  tags = {
    Name = "Image MetaData Table"
  }
}

resource "aws_lambda_function" "image_resizer" {
  filename         = "lambda.zip"
  function_name    = "ImageResizerFunction"
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.11"
  role             = "arn:aws:iam::000000000000:role/lambda-role"
  timeout          = 60

  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.image_metadata.name
    }
  }
}

resource "aws_lambda_permission" "allow_s3_invoke" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.image_resizer.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.original_images.arn
}

resource "aws_s3_bucket_notification" "original_images_notification" {
  bucket = aws_s3_bucket.original_images.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.image_resizer.arn
    events              = ["s3:ObjectCreated:*"]
  }

  depends_on = [aws_lambda_permission.allow_s3_invoke]
}