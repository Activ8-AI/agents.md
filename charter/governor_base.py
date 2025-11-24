"""Base classes for governor sweeps."""

from __future__ import annotations

import hashlib
import os
from dataclasses import dataclass, field
from datetime import datetime
from typing import Any, Dict, List

from .evidence import update_state, write_evidence
from .logging_spine import record_custodian_event, record_genesis_trace
from .policy_loader import PolicyEnvelope, load_policy


class GovernorError(RuntimeError):
    """Custom error raised by governors."""


@dataclass
class ValidationResult:
    name: str
    passed: bool
    details: Dict[str, Any] = field(default_factory=dict)


@dataclass
class GovernorReport:
    governor: str
    domain_policy: PolicyEnvelope
    copilot_policy: PolicyEnvelope
    token_fingerprint: str
    started_at: str
    finished_at: str
    validations: List[ValidationResult]

    @property
    def status(self) -> str:
        return "pass" if all(v.passed for v in self.validations) else "fail"

    def as_dict(self) -> Dict[str, Any]:
        return {
            "governor": self.governor,
            "domain_policy": self.domain_policy.as_dict(),
            "copilot_policy": self.copilot_policy.as_dict(),
            "token_fingerprint": self.token_fingerprint,
            "started_at": self.started_at,
            "finished_at": self.finished_at,
            "validations": [
                {"name": v.name, "passed": v.passed, "details": v.details}
                for v in self.validations
            ],
            "status": self.status,
        }


class Governor:
    """Shared implementation for a policy-enforced sweep."""

    required_policy_keys = ("metadata", "controls", "guardrails")

    def __init__(self, name: str, domain_policy: str, copilot_policy: str, token_env: str):
        self.name = name
        self.domain_policy_path = domain_policy
        self.copilot_policy_path = copilot_policy
        self.token_env = token_env

    def run(self) -> GovernorReport:
        started_at = datetime.utcnow().isoformat() + "Z"
        domain_policy = load_policy(self.domain_policy_path)
        copilot_policy = load_policy(self.copilot_policy_path)
        token = self._require_token()
        token_fingerprint = hashlib.sha256(token.encode("utf-8")).hexdigest()[:12]

        validations = []
        validations.extend(self._validate_policy("domain", domain_policy))
        validations.extend(self._validate_policy("copilot", copilot_policy))
        validations.append(self._validate_version_sync(domain_policy, copilot_policy))

        finished_at = datetime.utcnow().isoformat() + "Z"
        report = GovernorReport(
            governor=self.name,
            domain_policy=domain_policy,
            copilot_policy=copilot_policy,
            token_fingerprint=token_fingerprint,
            started_at=started_at,
            finished_at=finished_at,
            validations=validations,
        )

        evidence_path = write_evidence(self.name, report.as_dict())
        update_state(self.name, report.status, evidence_path)
        record_custodian_event({"governor": self.name, "status": report.status})
        record_genesis_trace(
            {
                "governor": self.name,
                "domain_policy_sha": domain_policy.sha256,
                "copilot_policy_sha": copilot_policy.sha256,
            }
        )
        return report

    def _require_token(self) -> str:
        token = os.getenv(self.token_env)
        if not token:
            raise GovernorError(f"Missing token for {self.name}: {self.token_env}")
        return token

    def _validate_policy(self, label: str, policy: PolicyEnvelope) -> List[ValidationResult]:
        payload = policy.payload
        missing_keys = [key for key in self.required_policy_keys if key not in payload]
        passed = not missing_keys
        return [
            ValidationResult(
                name=f"{label}_required_keys",
                passed=passed,
                details={"missing": missing_keys, "policy": policy.name},
            )
        ]

    def _validate_version_sync(
        self, domain_policy: PolicyEnvelope, copilot_policy: PolicyEnvelope
    ) -> ValidationResult:
        domain_version = domain_policy.payload.get("metadata", {}).get("version")
        copilot_version = copilot_policy.payload.get("metadata", {}).get("version")
        passed = domain_version == copilot_version
        return ValidationResult(
            name="version_lock",
            passed=passed,
            details={"domain_version": domain_version, "copilot_version": copilot_version},
        )
