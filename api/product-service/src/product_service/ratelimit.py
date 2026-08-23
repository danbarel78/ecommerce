"""App-level rate limiting via slowapi (token bucket per client IP).

This is the application-tier defense; the edge-tier defense is the AWS WAF rate-based
rule (infra/modules/security). Both layers are intentional (ARCHITECTURE.md §4.1.2 / Track B)."""

from slowapi import Limiter
from slowapi.util import get_remote_address

from product_service.config import get_settings

limiter = Limiter(key_func=get_remote_address, default_limits=[get_settings().rate_limit])
