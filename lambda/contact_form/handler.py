"""
contact_form Lambda
--------------------
Triggered by API Gateway (HTTP API, payload format 2.0) on POST /contact.
Validates the submitted fields and sends the message via SES SendEmail.

Environment variables (set by Terraform — see infra/lambda.tf):
  SENDER_EMAIL    - SES-verified "from" address
  RECIPIENT_EMAIL - where the message should land (your inbox)
  ALLOWED_ORIGIN  - your site's origin, for the CORS header
"""

import json
import os
import re

import boto3

ses = boto3.client("ses")

EMAIL_RE = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")
MAX_FIELD_LENGTH = 5000


def _response(status_code: int, body: dict) -> dict:
    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": os.environ.get("ALLOWED_ORIGIN", "*"),
        },
        "body": json.dumps(body),
    }


def _validate(payload: dict) -> str | None:
    """Returns an error message, or None if the payload is valid."""
    for field in ("name", "email", "message"):
        value = payload.get(field, "")
        if not isinstance(value, str) or not value.strip():
            return f"Field '{field}' is required."
        if len(value) > MAX_FIELD_LENGTH:
            return f"Field '{field}' is too long."

    if not EMAIL_RE.match(payload["email"].strip()):
        return "Field 'email' is not a valid email address."

    return None


def handler(event, context):
    try:
        payload = json.loads(event.get("body") or "{}")
    except json.JSONDecodeError:
        return _response(400, {"error": "Request body must be valid JSON."})

    error = _validate(payload)
    if error:
        return _response(400, {"error": error})

    name = payload["name"].strip()
    email = payload["email"].strip()
    message = payload["message"].strip()

    sender = os.environ["SENDER_EMAIL"]
    recipient = os.environ["RECIPIENT_EMAIL"]

    try:
        ses.send_email(
            Source=sender,
            Destination={"ToAddresses": [recipient]},
            ReplyToAddresses=[email],
            Message={
                "Subject": {"Data": f"Portfolio contact form — {name}"},
                "Body": {
                    "Text": {
                        "Data": f"From: {name} <{email}>\n\n{message}",
                    }
                },
            },
        )
    except Exception as exc:  # noqa: BLE001 — surfaced to CloudWatch for the alarm
        print(f"SES send_email failed: {exc}")
        return _response(502, {"error": "Could not send the message. Try again shortly."})

    return _response(200, {"status": "sent"})
