"""Agent hub activation script logging Prime/Backup/Governance status."""

from __future__ import annotations

import yaml

from custody.custodian_ledger import default_custody_ledger


def _config() -> dict:
    with open("configs/global_config.yaml", "r", encoding="utf-8") as handle:
        return yaml.safe_load(handle)


def activate_agents() -> None:
    config = _config()
    ledger = default_custody_ledger()
    for role in ("Prime", "Backup", "Governance"):
        ledger.record(
            "AGENT_ACTIVATION",
            {
                "role": role,
                "identity": config["primary_identity"],
            },
        )


if __name__ == "__main__":
    activate_agents()
