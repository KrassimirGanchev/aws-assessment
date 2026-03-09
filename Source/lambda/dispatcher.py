import json
import os

import boto3


def lambda_handler(event, context):
    execution_region = os.environ["EXECUTION_REGION"]
    ecs = boto3.client("ecs", region_name=execution_region)

    cluster_name = os.environ["ECS_CLUSTER_NAME"]
    task_definition_arn = os.environ["ECS_TASK_DEFINITION_ARN"]
    subnet_ids = [subnet.strip() for subnet in os.environ["ECS_SUBNET_IDS"].split(",") if subnet.strip()]
    security_group_id = os.environ["ECS_SECURITY_GROUP_ID"]

    response = ecs.run_task(
        cluster=cluster_name,
        taskDefinition=task_definition_arn,
        launchType="FARGATE",
        count=1,
        networkConfiguration={
            "awsvpcConfiguration": {
                "subnets": subnet_ids,
                "securityGroups": [security_group_id],
                "assignPublicIp": "ENABLED",
            }
        },
    )

    failures = response.get("failures", [])
    if failures:
        return {
            "statusCode": 500,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({"region": execution_region, "status": "error", "failures": failures}),
        }

    task_arns = [task.get("taskArn") for task in response.get("tasks", [])]
    return {
        "statusCode": 200,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps({"region": execution_region, "status": "dispatched", "tasks": task_arns}),
    }