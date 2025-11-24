"""Placeholder secrets loader for MVP."""

from custody.custodian_ledger import default_custody_ledger


def load() -> None:
    ledger = default_custody_ledger()
    ledger.record(
        "SECRETS_LOAD",
        {
            "source": "notion",
            "status": "placeholder",
        },
    )


if __name__ == "__main__":
    load()
