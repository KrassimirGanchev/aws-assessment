import argparse
import concurrent.futures
import json
import time
from dataclasses import dataclass

import boto3
import requests


@dataclass
class ApiResult:
    endpoint: str
    status_code: int
    latency_ms: float
    response_json: dict


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Authenticate via Cognito and test /greet and /dispatch in both regions.")
    parser.add_argument("--cognito-user-pool-id", required=True)
    parser.add_argument("--cognito-client-id", required=True)
    parser.add_argument("--username", required=True)
    parser.add_argument("--password-secret-id", required=True, help="Secrets Manager secret ID/ARN containing the Cognito test password")
    parser.add_argument("--api-us-east-1", required=True, help="Base API endpoint, e.g. https://abc.execute-api.us-east-1.amazonaws.com")
    parser.add_argument("--api-eu-west-1", required=True, help="Base API endpoint, e.g. https://xyz.execute-api.eu-west-1.amazonaws.com")
    parser.add_argument("--set-password", action="store_true", help="Set the test user's permanent password before auth")
    return parser.parse_args()


def get_password(secret_id: str) -> str:
    secrets_manager = boto3.client("secretsmanager", region_name="us-east-1")
    response = secrets_manager.get_secret_value(SecretId=secret_id)
    return response["SecretString"].strip()


def get_jwt_token(args: argparse.Namespace) -> str:
    cognito = boto3.client("cognito-idp", region_name="us-east-1")
    password = get_password(args.password_secret_id)

    if args.set_password:
        cognito.admin_set_user_password(
            UserPoolId=args.cognito_user_pool_id,
            Username=args.username,
            Password=password,
            Permanent=True,
        )

    response = cognito.initiate_auth(
        ClientId=args.cognito_client_id,
        AuthFlow="USER_PASSWORD_AUTH",
        AuthParameters={"USERNAME": args.username, "PASSWORD": password},
    )

    return response["AuthenticationResult"]["IdToken"]


def invoke_endpoint(method: str, endpoint: str, id_token: str) -> ApiResult:
    headers = {"Authorization": f"Bearer {id_token}", "Content-Type": "application/json"}

    start = time.perf_counter()
    if method.upper() == "GET":
        response = requests.get(endpoint, headers=headers, timeout=30)
    else:
        response = requests.post(endpoint, headers=headers, json={}, timeout=30)
    end = time.perf_counter()

    response_json = {}
    try:
        response_json = response.json()
    except json.JSONDecodeError:
        response_json = {"raw": response.text}

    return ApiResult(
        endpoint=endpoint,
        status_code=response.status_code,
        latency_ms=(end - start) * 1000,
        response_json=response_json,
    )


def assert_region(result: ApiResult, expected_region: str) -> None:
    if result.status_code != 200:
        raise RuntimeError(f"Non-200 response from {result.endpoint}: {result.status_code}, body={result.response_json}")

    response_region = result.response_json.get("region")
    if response_region != expected_region:
        raise RuntimeError(
            f"Region assertion failed for {result.endpoint}: expected={expected_region}, actual={response_region}, body={result.response_json}"
        )


def run_concurrent_calls(id_token: str, method: str, route: str, endpoints: dict[str, str]) -> list[ApiResult]:
    tasks: list[tuple[str, str]] = []
    for region, base in endpoints.items():
        base_clean = base.rstrip("/")
        tasks.append((region, f"{base_clean}/{route.lstrip('/')}"))

    results: list[ApiResult] = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as executor:
        future_map = {
            executor.submit(invoke_endpoint, method, endpoint, id_token): region for region, endpoint in tasks
        }

        for future in concurrent.futures.as_completed(future_map):
            region = future_map[future]
            result = future.result()
            assert_region(result, region)
            results.append(result)

    return sorted(results, key=lambda r: r.endpoint)


def print_results(title: str, results: list[ApiResult]) -> None:
    print(f"\n=== {title} ===")
    for item in results:
        print(
            json.dumps(
                {
                    "endpoint": item.endpoint,
                    "statusCode": item.status_code,
                    "latencyMs": round(item.latency_ms, 2),
                    "response": item.response_json,
                },
                indent=2,
            )
        )


def main() -> None:
    args = parse_args()

    endpoints = {
        "us-east-1": args.api_us_east_1,
        "eu-west-1": args.api_eu_west_1,
    }

    token = get_jwt_token(args)
    print("Successfully retrieved Cognito JWT token.")

    greet_results = run_concurrent_calls(token, "GET", "/greet", endpoints)
    print_results("Concurrent /greet results", greet_results)

    dispatch_results = run_concurrent_calls(token, "POST", "/dispatch", endpoints)
    print_results("Concurrent /dispatch results", dispatch_results)

    print("\nAll assertions passed.")


if __name__ == "__main__":
    main()
