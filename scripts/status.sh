#!/bin/bash
# Print the status of Airflow on the EC2 instance: instance state, systemd service,
# astro containers and the Airflow health endpoint. Exits non-zero only if the instance
# is not running or the SSM command itself fails; unhealthy checks are printed, not enforced.
set -euo pipefail

instance_id="$(terraform -chdir="$(dirname "$0")/../infra/aws" output -raw airflow_instance_id)"

state="$(aws ec2 describe-instances --region us-east-1 --instance-ids "$instance_id" \
	--query 'Reservations[0].Instances[0].State.Name' --output text)"
echo "== instance $instance_id: $state =="
if [[ "$state" != running ]]; then
	echo "instance is not running, skipping service checks"
	exit 1
fi

# each check ends in || true so an unhealthy check does not mark the SSM command failed
command_id="$(aws ssm send-command --region us-east-1 --instance-ids "$instance_id" \
	--document-name AWS-RunShellScript \
	--parameters '{"commands":[
		"echo == systemd service ==",
		"systemctl is-active airflow || true",
		"journalctl -u airflow -n 10 --no-pager || true",
		"echo == containers ==",
		"docker ps -a || true",
		"echo == health ==",
		"curl -sS --max-time 5 http://localhost:8080/api/v2/monitor/health || true",
		"echo"
	]}' \
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
