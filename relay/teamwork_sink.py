"""Placeholder Teamwork sink that records receipt."""

from custody.custodian_ledger import default_custody_ledger


def ingest(task_id: str, payload: dict) -> None:
    ledger = default_custody_ledger()
    ledger.record(
        "TEAMWORK_SINK",
        {
            "task_id": task_id,
            "payload": payload,
        },
    )
