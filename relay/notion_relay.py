"""Placeholder Notion relay that records custody events for MVP."""

from custody.custodian_ledger import default_custody_ledger


def sync(page_id: str, payload: dict) -> None:
    ledger = default_custody_ledger()
    ledger.record(
        "NOTION_RELAY",
        {
            "page_id": page_id,
            "payload": payload,
        },
    )
