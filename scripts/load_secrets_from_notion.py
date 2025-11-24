from __future__ import annotations

import json
from pathlib import Path
from typing import Dict


def load_secrets() -> Dict[str, str]:
    secrets_path = Path("configs/global_config.yaml")
    if not secrets_path.exists():
        return {}
    # For now, just return file contents as a single key
    return {"raw": secrets_path.read_text()}


if __name__ == "__main__":
    print(json.dumps(load_secrets(), indent=2))
