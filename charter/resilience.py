"""Resilience helpers: retries, watchguards, and status reporting."""

from __future__ import annotations

import random
import time
from dataclasses import dataclass
from datetime import datetime, timedelta
from typing import Callable, Iterable, Tuple, TypeVar

from .config import DEFAULT_BACKOFF_SECONDS, UTC
from .evidence import read_state

T = TypeVar("T")


@dataclass
class RetryPlan:
    attempts: int
    backoff: Tuple[int, ...] = DEFAULT_BACKOFF_SECONDS


def run_with_backoff(func: Callable[[], T], plan: RetryPlan | None = None) -> T:
    plan = plan or RetryPlan(attempts=len(DEFAULT_BACKOFF_SECONDS), backoff=DEFAULT_BACKOFF_SECONDS)
    attempt = 0
    last_error: Exception | None = None

    while attempt < plan.attempts:
        try:
            return func()
        except Exception as err:  # noqa: BLE001 - propagate after retries
            last_error = err
            if attempt == plan.attempts - 1:
                raise
            sleep_for = plan.backoff[min(attempt, len(plan.backoff) - 1)]
            jitter = random.uniform(0, 0.5)
            time.sleep(sleep_for + jitter)
            attempt += 1

    if last_error:
        raise last_error
    raise RuntimeError("run_with_backoff exited unexpectedly")


def stale_governors(threshold_minutes: int) -> Iterable[str]:
    state = read_state()
    cutoff = datetime.utcnow().replace(tzinfo=UTC) - timedelta(minutes=threshold_minutes)
    for governor, payload in state.items():
        updated_at = datetime.fromisoformat(payload["updated_at"])
        if updated_at < cutoff:
            yield governor
