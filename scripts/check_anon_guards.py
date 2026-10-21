"""Calls every team- or owner-only database function with only the
publishable key, and fails if any of them does anything but refuse.

Usage: python scripts/check_anon_guards.py   (reads SUPABASE_URL and
SUPABASE_ANON_KEY from .env)

Exists because, until 2026-10-21, is_team_admin() returned NULL for a caller
with no session, and `if not public.is_team_admin() then raise` does not fire
on NULL: anonymous callers walked through start_trial, record_payment,
current_visit_code and others. Run it after any migration that adds or
changes a guarded function.
"""

import http.client
import json
import os
import sys
import urllib.error
import urllib.request
from typing import cast

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
NOBODY = "00000000-0000-0000-0000-000000000000"

# function -> arguments. Each must answer 42501 (insufficient privilege).
GUARDED: dict[str, dict[str, object]] = {
    "start_trial": {"p_business": NOBODY},
    "record_payment": {
        "p_business": NOBODY,
        "p_tier": "basic",
        "p_months": 1,
        "p_amount_ec": 0,
        "p_reference": "probe",
    },
    "advance_subscriptions": {},
    "current_visit_code": {"p_business": NOBODY},
    "respond_to_review_request": {"p_request": NOBODY, "p_approve": True},
    "record_redemption": {"p_ad_id": NOBODY},
    "review_audit": {},
    "check_in": {"p_business": NOBODY, "p_code": "AAAAAA"},
    "submit_review": {"p_business": NOBODY, "p_rating": 5, "p_body": "probe"},
    "report_review": {"p_review": NOBODY, "p_reason": "probe"},
    "register_push_token": {"p_token": "probe"},
    "request_claim": {
        "p_business": NOBODY,
        "p_name": "probe",
        "p_phone": "2685550000",
        "p_role": "probe",
    },
    "decide_claim": {"p_claim": NOBODY, "p_approve": True},
}


def env() -> dict[str, str]:
    values: dict[str, str] = {}
    with open(os.path.join(ROOT, ".env"), encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                key, value = line.split("=", 1)
                values[key.strip()] = value.strip()
    return values


def call(url: str, key: str, name: str, args: dict[str, object]) -> str:
    """The response body, success or error."""
    request = urllib.request.Request(
        f"{url}/rest/v1/rpc/{name}",
        data=json.dumps(args).encode(),
        headers={"apikey": key, "Content-Type": "application/json"},
        method="POST",
    )
    try:
        # urlopen is typed as returning Any; for an http URL it is this.
        response = cast(http.client.HTTPResponse, urllib.request.urlopen(request))
        try:
            body: bytes = response.read()
        finally:
            response.close()
    except urllib.error.HTTPError as error:
        body = error.read()
    return body.decode()[:120]


def main() -> int:
    e = env()
    failures = 0
    for name, args in GUARDED.items():
        body = call(e["SUPABASE_URL"], e["SUPABASE_ANON_KEY"], name, args)
        refused = '"42501"' in body
        print(f"{'ok  ' if refused else 'OPEN'} {name}: {body}")
        failures += 0 if refused else 1
    print("all guarded" if failures == 0 else f"{failures} function(s) let an anonymous caller through")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
