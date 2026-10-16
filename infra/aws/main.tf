provider "aws" { 
  region = "us-east-1"
}

resource "aws_s3_bucket" "raw_data" {
	bucket_prefix = "raw-data-"
	force_destroy = true
	tags = {
		Project = "pol-trades"
	}
}
