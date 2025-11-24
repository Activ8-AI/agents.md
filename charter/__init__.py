"""
Meta Mega Codex Charter utilities package.

Importing this package ensures that the shared artifact and logging directories
exist so that every layer (doctrine through operations) can rely on them.
"""

from .config import ARTIFACT_DIR, CACHE_DIR, LOG_DIR, REPO_ROOT  # noqa: F401

__all__ = ["ARTIFACT_DIR", "CACHE_DIR", "LOG_DIR", "REPO_ROOT"]
