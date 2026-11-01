#!/bin/bash
# Open the Airflow UI on the EC2 instance through a Session Manager tunnel: http://localhost:8080
# Ctrl+C closes the tunnel.
set -euo pipefail

aws ssm start-session --region us-east-1 \
	--target "$(terraform -chdir="$(dirname "$0")/../infra/aws" output -raw airflow_instance_id)" \
	--document-name AWS-StartPortForwardingSession \
	--parameters '{"portNumber":["8080"],"localPortNumber":["8080"]}'
