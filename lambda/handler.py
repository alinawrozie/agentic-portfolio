"""
Contact form handler.

Triggered by API Gateway (HTTP API, payload format 2.0) on POST /contact.
Validates the submitted fields, then sends an email via SES.

Environment variables (set by Terraform in infra/lambda.tf):
    SENDER_EMAIL     - SES-verified "from" address
    RECIPIENT_EMAIL  - where contact form submissions are delivered
    ALLOWED_ORIGIN   - the single origin allowed to call this function (CORS)
"""

import json
import os
import re
import logging

import boto3
from botocore.exceptions import ClientError

logger = logging.getLogger()
logger.setLevel(logging.INFO)

ses_client = boto3.client("ses")

SENDER_EMAIL = os.environ["SENDER_EMAIL"]
RECIPIENT_EMAIL = os.environ["RECIPIENT_EMAIL"]
ALLOWED_ORIGIN = os.environ["ALLOWED_ORIGIN"]

EMAIL_RE = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")

MAX_NAME_LEN = 100
MAX_EMAIL_LEN = 254
MAX_MESSAGE_LEN = 5000


def _cors_headers():
    return {
        "Access-Control-Allow-Origin": ALLOWED_ORIGIN,
        "Access-Control-Allow-Methods": "POST, OPTIONS",
        "Access-Control-Allow-Headers": "content-type",
    }


def _response(status_code, body_dict):
    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json",
            **_cors_headers(),
        },
        "body": json.dumps(body_dict),
    }


def _validate(payload):
    """Returns a list of human-readable error strings; empty list = valid."""
    errors = []

    name = (payload.get("name") or "").strip()
    email = (payload.get("email") or "").strip()
    message = (payload.get("message") or "").strip()

    if not name:
        errors.append("Name is required.")
    elif len(name) > MAX_NAME_LEN:
        errors.append(f"Name must be {MAX_NAME_LEN} characters or fewer.")

    if not email:
        errors.append("Email is required.")
    elif len(email) > MAX_EMAIL_LEN or not EMAIL_RE.match(email):
        errors.append("Email address is not valid.")

    if not message:
        errors.append("Message is required.")
    elif len(message) > MAX_MESSAGE_LEN:
        errors.append(f"Message must be {MAX_MESSAGE_LEN} characters or fewer.")

    return errors, name, email, message


def lambda_handler(event, context):
    # API Gateway HTTP APIs send an explicit OPTIONS preflight request for
    # CORS; respond to it directly without touching SES.
    method = event.get("requestContext", {}).get("http", {}).get("method", "")
    if method == "OPTIONS":
        return _response(200, {})

    try:
        payload = json.loads(event.get("body") or "{}")
    except json.JSONDecodeError:
        return _response(400, {"error": "Request body must be valid JSON."})

    errors, name, email, message = _validate(payload)
    if errors:
        return _response(400, {"error": "Validation failed.", "details": errors})

    # Basic header injection guard: strip newlines from fields that end up
    # in the email body/subject, since this is user-supplied input.
    safe_name = name.replace("\n", " ").replace("\r", " ")
    safe_email = email.replace("\n", " ").replace("\r", " ")

    subject = f"Portfolio contact form: {safe_name}"
    body_text = (
        f"New contact form submission\n\n"
        f"Name: {safe_name}\n"
        f"Email: {safe_email}\n\n"
        f"Message:\n{message}\n"
    )

    try:
        ses_client.send_email(
            Source=SENDER_EMAIL,
            Destination={"ToAddresses": [RECIPIENT_EMAIL]},
            Message={
                "Subject": {"Data": subject, "Charset": "UTF-8"},
                "Body": {"Text": {"Data": body_text, "Charset": "UTF-8"}},
            },
            ReplyToAddresses=[safe_email],
        )
    except ClientError as e:
        logger.error("SES send_email failed: %s", e.response.get("Error", {}).get("Message", str(e)))
        return _response(502, {"error": "Could not send message. Please try again later."})

    return _response(200, {"message": "Thanks - your message has been sent."})
