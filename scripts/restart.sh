#!/bin/bash
# Restart Airflow on the EC2 instance (astro dev stop + start, which rebuilds the image) and
# print the last service log lines. Needed after changing requirements, packages or the Dockerfile.
set -euo pipefail

instance_id="$(terraform -chdir="$(dirname "$0")/../infra/aws" output -raw airflow_instance_id)"
command_id="$(aws ssm send-command --region us-east-1 --instance-ids "$instance_id" \
	--document-name AWS-RunShellScript \
	--parameters 'commands=["systemctl restart airflow","journalctl -u airflow -n 20 --no-pager"]' \
	--query Command.CommandId --output text)"

# send-command is asynchronous: poll until it finishes
status=Pending
while [[ "$status" == Pending || "$status" == InProgress || "$status" == Delayed ]]; do
	sleep 3
	status="$(aws ssm get-command-invocation --region us-east-1 --command-id "$command_id" --instance-id "$instance_id" --query Status --output text 2>/dev/null || echo Pending)"
done

aws ssm get-command-invocation --region us-east-1 --command-id "$command_id" --instance-id "$instance_id" \
	--query '[StandardOutputContent, StandardErrorContent]' --output text
echo "status: $status"
[[ "$status" == Success ]]
