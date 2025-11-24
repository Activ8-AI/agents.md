"""Placeholder Slack signal relay."""

from custody.custodian_ledger import default_custody_ledger


def notify(channel: str, text: str) -> None:
    ledger = default_custody_ledger()
    ledger.record(
        "SLACK_SIGNAL",
        {
            "channel": channel,
            "text": text,
        },
    )
