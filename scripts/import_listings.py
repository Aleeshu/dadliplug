"""Bulk-import the first listings from a spreadsheet (plan.md Phase 10).

Every row becomes a *pre-built* listing: hidden from customers until the
team publishes it, with a private preview link for the pitch. Nothing goes
public by accident, and a bad row is caught before anything is written.

Usage:
    python scripts/import_listings.py listings.csv            # check only
    python scripts/import_listings.py listings.csv --apply    # write

The CSV columns are the header of scripts/listings_template.csv. Export from
Google Sheets or Excel as CSV (UTF-8). Writing goes through
`supabase db query --linked`, so it needs the Supabase CLI logged in to the
project, as for migrations.
"""

import csv
import json
import os
import re
import subprocess
import sys
import tempfile
from dataclasses import dataclass, field

CATEGORIES = {
    "food",
    "shopping",
    "services",
    "health_beauty",
    "entertainment",
    "automotive",
    "real_estate",
    "education",
    "other",
}
TAGS = {
    "cash_only",
    "accepts_cards",
    "accepts_usd",
    "parking",
    "accessibility",
    "family_friendly",
    "wifi",
    "outdoor_seating",
}
TIERS = {"growing", "basic", "featured"}
DAYS = {"mon": 1, "tue": 2, "wed": 3, "thu": 4, "fri": 5, "sat": 6, "sun": 7}

# Antigua and Barbuda, generously. A pin outside this is a typo (often a
# swapped latitude and longitude, or a missing minus sign).
LAT_RANGE = (16.9, 17.8)
LNG_RANGE = (-62.0, -61.6)

COLUMNS = [
    "name",
    "category",
    "area",
    "description",
    "phone",
    "whatsapp",
    "address",
    "how_to_find_us",
    "latitude",
    "longitude",
    "days",
    "opens",
    "closes",
    "price_range",
    "tags",
    "instagram",
    "facebook",
    "website",
    "plan",
]


@dataclass
class Row:
    line: int
    values: dict[str, object]
    errors: list[str] = field(default_factory=list)


def parse_days(raw: str) -> list[int]:
    """'Mon-Sat', 'Mon,Wed,Fri', 'Daily' -> ISO weekdays."""
    text = raw.strip().lower()
    if not text:
        return []
    if text in {"daily", "every day", "mon-sun"}:
        return list(range(1, 8))
    out: set[int] = set()
    for part in re.split(r"[,\s]+", text):
        if not part:
            continue
        if "-" in part:
            a, b = (p[:3] for p in part.split("-", 1))
            if a not in DAYS or b not in DAYS:
                raise ValueError(f"unknown day range '{part}'")
            start, end = DAYS[a], DAYS[b]
            day = start
            while True:
                out.add(day)
                if day == end:
                    break
                day = day % 7 + 1
        else:
            key = part[:3]
            if key not in DAYS:
                raise ValueError(f"unknown day '{part}'")
            out.add(DAYS[key])
    return sorted(out)


def parse_time(raw: str) -> float:
    """'09:00', '9', '9:30', '21:00' -> fractional hours."""
    m = re.fullmatch(r"(\d{1,2})(?::(\d{2}))?", raw.strip())
    if not m:
        raise ValueError(f"time '{raw}' should look like 09:00")
    hour, minute = int(m.group(1)), int(m.group(2) or 0)
    if hour > 24 or minute > 59:
        raise ValueError(f"time '{raw}' is not a time")
    return hour + minute / 60


def phone_digits(raw: str) -> str:
    digits = re.sub(r"\D", "", raw)
    # Antigua is +1 268. A local 7-digit number gets both; "268 555 0199"
    # gets the 1, or it dials as a number in another country.
    if len(digits) == 7:
        return "1268" + digits
    if len(digits) == 10 and digits.startswith("268"):
        return "1" + digits
    return digits


def check(line: int, raw: dict[str, str]) -> Row:
    get = lambda k: (raw.get(k) or "").strip()  # noqa: E731
    row = Row(line, {})
    v = row.values

    v["name"] = get("name")
    if not v["name"]:
        row.errors.append("name is empty")

    category = get("category").lower().replace(" ", "_").replace("&", "")
    category = {"health_and_beauty": "health_beauty", "healthbeauty": "health_beauty"}.get(category, category)
    if category not in CATEGORIES:
        row.errors.append(f"category '{get('category')}' is not one of {sorted(CATEGORIES)}")
    v["category"] = category

    v["area"] = get("area")
    v["description"] = get("description")
    if not v["area"]:
        row.errors.append("area is empty")
    if not v["description"]:
        row.errors.append("description is empty")

    for key in ("phone", "whatsapp"):
        value = get(key)
        if value:
            digits = phone_digits(value)
            if len(digits) < 10:
                row.errors.append(f"{key} '{value}' is too short")
            v[key] = "+" + digits if key == "phone" else digits
        else:
            v[key] = None
    if not v["phone"] and not v["whatsapp"]:
        row.errors.append("needs a phone or WhatsApp number: the team verifies by calling it")

    for key in ("address", "how_to_find_us", "price_range", "instagram", "facebook", "website"):
        v[key] = get(key) or None
    for key in ("instagram", "facebook"):
        if v[key]:
            v[key] = str(v[key]).lstrip("@").rstrip("/").split("/")[-1]

    lat, lng = get("latitude"), get("longitude")
    if lat or lng:
        try:
            v["latitude"], v["longitude"] = float(lat), float(lng)
            if not (LAT_RANGE[0] <= v["latitude"] <= LAT_RANGE[1]) or not (
                LNG_RANGE[0] <= v["longitude"] <= LNG_RANGE[1]
            ):
                row.errors.append(
                    f"pin {lat},{lng} is not in Antigua or Barbuda "
                    "(latitude about 17.1, longitude about -61.8)"
                )
        except ValueError:
            row.errors.append(f"latitude/longitude '{lat}','{lng}' are not numbers")
    else:
        # Online-only: no pin, and kept off the leaderboard by the app.
        v["latitude"] = v["longitude"] = None

    try:
        days = parse_days(get("days"))
        opens = parse_time(get("opens") or "9:00")
        closes = parse_time(get("closes") or "17:00")
        v["hours"] = {"days": days, "opensAt": opens, "closesAt": closes}
    except ValueError as error:
        row.errors.append(str(error))
        v["hours"] = {"days": [], "opensAt": 9, "closesAt": 17}

    tags = [t.strip().lower().replace(" ", "_") for t in re.split(r"[;,]", get("tags")) if t.strip()]
    unknown = [t for t in tags if t not in TAGS]
    if unknown:
        row.errors.append(f"unknown tags {unknown}; known: {sorted(TAGS)}")
    v["tags"] = [t for t in tags if t in TAGS]

    plan = (get("plan") or "growing").lower()
    if plan not in TIERS:
        row.errors.append(f"plan '{plan}' is not one of {sorted(TIERS)}")
    v["plan"] = plan
    return row


def sql_literal(value: object) -> str:
    if value is None:
        return "null"
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (int, float)):
        return repr(value)
    if isinstance(value, dict):
        return "'" + json.dumps(value).replace("'", "''") + "'::jsonb"
    if isinstance(value, list):
        return "array[" + ",".join(sql_literal(x) for x in value) + "]::text[]"
    return "'" + str(value).replace("'", "''") + "'"


def to_sql(rows: list[Row]) -> str:
    cols = [
        "name", "category", "area", "description", "phone", "whatsapp",
        "address", "how_to_find_us", "latitude", "longitude", "hours",
        "price_range", "tags", "instagram", "facebook", "website",
    ]
    values = []
    for r in rows:
        v = r.values
        values.append(
            "("
            + ", ".join(sql_literal(v[c]) for c in cols)
            + f", {sql_literal(v['plan'])}, {sql_literal(v['plan'])}, true)"
        )
    # Skips a listing whose name already exists, so a re-run after fixing one
    # bad row does not duplicate the good ones.
    return (
        "insert into public.businesses ("
        + ", ".join(cols)
        + ", tier, subscription_status, is_prospect)\nselect * from (values\n  "
        + ",\n  ".join(values)
        + "\n) as v(" + ", ".join(cols) + ", tier, subscription_status, is_prospect)\n"
        + "where not exists (select 1 from public.businesses b where lower(b.name) = lower(v.name))\n"
        + "returning name;\n"
    )


def main() -> int:
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    apply = "--apply" in sys.argv
    if len(args) != 1:
        print(__doc__)
        return 2

    with open(args[0], encoding="utf-8-sig", newline="") as f:
        reader = csv.DictReader(f)
        missing = [c for c in ("name", "category", "area", "description") if c not in (reader.fieldnames or [])]
        if missing:
            print(f"The CSV is missing columns {missing}. Start from scripts/listings_template.csv.")
            return 1
        rows = [check(i + 2, r) for i, r in enumerate(reader) if any((x or "").strip() for x in r.values())]

    names = [str(r.values["name"]).lower() for r in rows]
    for r in rows:
        if names.count(str(r.values["name"]).lower()) > 1:
            r.errors.append("the same name appears twice in this file")

    bad = [r for r in rows if r.errors]
    for r in bad:
        for e in r.errors:
            print(f"line {r.line} ({r.values.get('name') or '?'}): {e}")
    print(f"{len(rows)} rows, {len(rows) - len(bad)} ok, {len(bad)} with problems.")
    if bad:
        print("Nothing written. Fix the rows above and run again.")
        return 1
    if not rows:
        return 0
    if not apply:
        print("Check passed. Run again with --apply to add them as pre-built (hidden) listings.")
        return 0

    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    with tempfile.NamedTemporaryFile("w", suffix=".sql", delete=False, encoding="utf-8") as tmp:
        tmp.write(to_sql(rows))
        path = tmp.name
    try:
        result = subprocess.run(
            ["supabase", "db", "query", "--linked", "-f", path],
            cwd=root, capture_output=True, text=True, shell=os.name == "nt",
        )
    finally:
        os.unlink(path)
    if result.returncode != 0:
        print(result.stderr or result.stdout)
        return 1
    added = len(re.findall(r'"name":', result.stdout))
    print(f"Added {added} pre-built listings; {len(rows) - added} already existed and were skipped.")
    print("They are hidden. In the app: Team -> Listings -> ... -> Copy preview link / Publish.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
