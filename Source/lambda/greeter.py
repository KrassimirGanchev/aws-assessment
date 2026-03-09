import json
import os
import time
import uuid

import boto3


dynamodb = boto3.resource("dynamodb")
sns = boto3.client("sns", region_name="us-east-1")


def lambda_handler(event, context):
    execution_region = os.environ["EXECUTION_REGION"]
    table_name = os.environ["DYNAMODB_TABLE"]
    topic_arns = [
        arn.strip()
        for arn in os.environ.get("SNS_TOPIC_ARNS", os.environ.get("SNS_TOPIC_ARN", "")).split(",")
        if arn.strip()
    ]
    candidate_email = os.environ["CANDIDATE_EMAIL"]
    candidate_repo_url = os.environ["CANDIDATE_REPO_URL"]

    table = dynamodb.Table(table_name)
    record_id = str(uuid.uuid4())

    table.put_item(
        Item={
            "id": record_id,
            "createdAt": int(time.time()),
            "region": execution_region,
            "source": "Lambda",
            "path": event.get("rawPath", "/greet"),
        }
    )

    payload = {
        "email": candidate_email,
        "source": "Lambda",
        "region": execution_region,
        "repo": candidate_repo_url,
    }

    for topic_arn in dict.fromkeys(topic_arns):
        sns.publish(TopicArn=topic_arn, Message=json.dumps(payload))

    return {
        "statusCode": 200,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps({"region": execution_region, "status": "ok", "id": record_id}),
    }