import json
import os

import boto3


def main():
    sns = boto3.client("sns", region_name="us-east-1")
    topic_arns = [
        arn.strip()
        for arn in os.environ.get("SNS_TOPIC_ARNS", os.environ.get("SNS_TOPIC_ARN", "")).split(",")
        if arn.strip()
    ]

    payload = {
        "email": os.environ["CANDIDATE_EMAIL"],
        "source": "ECS",
        "region": os.environ["EXECUTION_REGION"],
        "repo": os.environ["CANDIDATE_REPO_URL"],
    }

    message_ids = []
    for topic_arn in dict.fromkeys(topic_arns):
        response = sns.publish(
            TopicArn=topic_arn,
            Message=json.dumps(payload),
        )
        message_ids.append(response.get("MessageId"))

    print(json.dumps({"status": "published", "messageIds": message_ids, "payload": payload}))


if __name__ == "__main__":
    main()
