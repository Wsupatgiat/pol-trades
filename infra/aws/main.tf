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

output "raw_data_bucket" {
	value = aws_s3_bucket.raw_data.bucket
}

resource "aws_ssm_parameter" "raw_data_bucket" {
  name  = "/pol-trades/raw_data_bucket"
  type  = "String"
  value = aws_s3_bucket.raw_data.bucket
}



# airflow connections

resource "aws_ssm_parameter" "snowflake_default" {
	name             = "/pol-trades/airflow/connections/snowflake_default"
	type             = "SecureString"
	value_wo         = regex("AIRFLOW_CONN_SNOWFLAKE_DEFAULT='?(\\{.*\\})'?", file("${path.module}/../../.env"))[0]
	value_wo_version = 1
}

resource "aws_ssm_parameter" "aws_default" {
	name             = "/pol-trades/airflow/connections/aws_default"
	type             = "SecureString"
	value_wo         = regex("AIRFLOW_CONN_AWS_DEFAULT='?(\\{.*\\})'?", file("${path.module}/../../.env"))[0]
	value_wo_version = 1
}

# EC2 role for Airflow
resource "aws_iam_role" "airflow" {
	name = "pol-trades-airflow"
	assume_role_policy = jsonencode({
		Version   = "2012-10-17"
		Statement = [{ Effect = "Allow", Action = "sts:AssumeRole", Principal = { Service = "ec2.amazonaws.com" } }]
	})
}

resource "aws_iam_role_policy" "airflow" {
	role = aws_iam_role.airflow.id
	policy = jsonencode({
		Version   = "2012-10-17"
		Statement = [{ Effect = "Allow", Action = "ssm:GetParameter", Resource = "arn:aws:ssm:*:*:parameter/pol-trades/airflow/connections/*" }]
	})
}

resource "aws_iam_instance_profile" "airflow" {
	name = "pol-trades-airflow"
	role = aws_iam_role.airflow.name
}

# EC2 instance for Airflow

resource "aws_iam_role_policy_attachment" "airflow_ssm" {
	role       = aws_iam_role.airflow.name
	policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

data "aws_ami" "ubuntu" {
	most_recent = true
	owners      = ["099720109477"] # Canonical
	filter {
		name   = "name"
		values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
	}
}

resource "aws_instance" "airflow" {
	ami                  = data.aws_ami.ubuntu.id
	instance_type        = "t3.medium"
	iam_instance_profile = aws_iam_instance_profile.airflow.name
	metadata_options {
		http_tokens                 = "required"
		http_put_response_hop_limit = 2
	}
	root_block_device {
		volume_size = 20
	}
	lifecycle {
		ignore_changes = [ami]
	}
	tags = {
		Name = "airflow"
	}
}
