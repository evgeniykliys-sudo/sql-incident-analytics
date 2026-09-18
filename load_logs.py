import json
import os
import re
from pathlib import Path

import psycopg2
from dotenv import load_dotenv

load_dotenv()

RAW_LOGS_PATH = Path(__file__).parent / "raw_logs.txt"

# Строка из `docker compose logs -t`: "simulator-1  | 2026-09-18T08:40:44.012045527Z {json}"
LINE_RE = re.compile(r"\|\s+(\S+)\s+(\{.*\})\s*$")


def parse_logs(path: Path):
    requests_rows = []
    incident_events = []

    for line in path.read_text(encoding="utf-8").splitlines():
        match = LINE_RE.search(line)
        if not match:
            continue

        timestamp, payload_raw = match.groups()
        payload = json.loads(payload_raw)

        if "event" in payload:
            incident_events.append((timestamp, payload["event"]))
        elif "request_id" in payload:
            requests_rows.append(
                (
                    payload["request_id"],
                    timestamp,
                    payload["status"],
                    payload["duration_ms"],
                    payload.get("error_type"),
                    payload["incident_mode"],
                )
            )

    return requests_rows, incident_events


def pair_incidents(events: list[tuple[str, str]]) -> list[tuple[str, str | None]]:
    """Сшивает incident_started/incident_resolved в пары (начало, конец)."""
    incidents = []
    open_start = None
    for timestamp, event in events:
        if event == "incident_started":
            open_start = timestamp
        elif event == "incident_resolved" and open_start:
            incidents.append((open_start, timestamp))
            open_start = None
    if open_start:
        incidents.append((open_start, None))
    return incidents


def load():
    requests_rows, incident_events = parse_logs(RAW_LOGS_PATH)
    incidents = pair_incidents(incident_events)

    conn = psycopg2.connect(
        host=os.getenv("PGHOST", "localhost"),
        port=os.getenv("PGPORT", "5432"),
        dbname=os.getenv("PGDATABASE", "incidents"),
        user=os.getenv("PGUSER", "postgres"),
        password=os.getenv("PGPASSWORD", "postgres"),
    )
    cur = conn.cursor()

    cur.execute(Path(__file__).parent.joinpath("schema.sql").read_text(encoding="utf-8"))

    cur.executemany(
        """
        INSERT INTO requests (request_id, logged_at, status, duration_ms, error_type, incident_mode)
        VALUES (%s, %s, %s, %s, %s, %s)
        """,
        requests_rows,
    )

    cur.executemany(
        "INSERT INTO incidents (started_at, resolved_at) VALUES (%s, %s)",
        incidents,
    )

    conn.commit()
    print(f"Загружено: {len(requests_rows)} запросов, {len(incidents)} инцидентов")
    cur.close()
    conn.close()


if __name__ == "__main__":
    load()
