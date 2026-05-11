"""
Surge detector — SPEC2.md Section 14 + SPEC request.

Tier 4 city (Hunsur / KR Nagar) earning rules.
Peak hours: 12-14 lunch, 19-21 dinner (IST).
Surge levels set by auto background task (surge:AUTO:{city})
or manual admin toggle (surge:MANUAL:{city}).
Rain bonus via surge:RAIN:{city} key — stacks on top of surge.
"""

import logging
from datetime import datetime, timezone, timedelta

import redis.asyncio as aioredis

logger = logging.getLogger(__name__)

# IST offset: UTC+5:30
IST = timezone(timedelta(hours=5, minutes=30))

# ── Tier 4 earning constants ──────────────────────────────────────────────────
EARNING_RULES = {
    "BASE_PAY": 20.00,           # Tier 4 city flat rate
    "FREE_DISTANCE_KM": 2.0,     # first 2 km included in base
    "RATE_PER_KM": 6.00,         # ₹6 per km beyond 2 km
    "PEAK_BONUS": 8.00,          # lunch + dinner peak
    "RAIN_BONUS": 20.00,         # manual admin toggle
    "MILD_SURGE": 10.00,         # demand ratio 2.0–3.0
    "MEDIUM_SURGE": 20.00,       # demand ratio 3.0–4.5
    "HIGH_SURGE": 30.00,         # demand ratio >4.5
}

_SURGE_PAY_MAP = {
    "MILD":   EARNING_RULES["MILD_SURGE"],
    "MEDIUM": EARNING_RULES["MEDIUM_SURGE"],
    "HIGH":   EARNING_RULES["HIGH_SURGE"],
}


# ── Peak-hour helper ──────────────────────────────────────────────────────────

def is_peak_hour() -> bool:
    """Return True during lunch (12-14 IST) or dinner (19-21 IST)."""
    hour = datetime.now(IST).hour
    return (12 <= hour < 14) or (19 <= hour < 21)


# ── Surge active check (legacy / admin toggle) ────────────────────────────────

async def is_surge_active(city: str, redis: aioredis.Redis) -> bool:
    """True if any surge key (MANUAL or AUTO) is set for the city."""
    manual = await redis.get(f"surge:MANUAL:{city}")
    if manual:
        return True
    auto = await redis.get(f"surge:AUTO:{city}")
    if auto:
        return True
    return is_peak_hour()


# ── Core surge-pay calculation (used by earnings_service) ────────────────────

async def get_surge_pay(city: str, redis: aioredis.Redis) -> float:
    """
    Return combined surge + rain pay for the city.

    Logic:
      1. Fetch surge:AUTO:{city}  → "MILD" | "MEDIUM" | "HIGH" | None
      2. Fetch surge:MANUAL:{city} → any value → always = MILD (₹10 floor)
      3. Take the HIGHER of auto_pay vs manual_pay
      4. Fetch surge:RAIN:{city}  → add ₹20 on top (stacks)
    """
    # Auto surge level
    auto_raw = await redis.get(f"surge:AUTO:{city}")
    if isinstance(auto_raw, bytes):
        auto_raw = auto_raw.decode()
    auto_pay = _SURGE_PAY_MAP.get(auto_raw or "", 0.0)

    # Manual surge (admin-toggled) → always at least MILD (₹10)
    manual_raw = await redis.get(f"surge:MANUAL:{city}")
    manual_pay = EARNING_RULES["MILD_SURGE"] if manual_raw else 0.0

    surge_pay = max(auto_pay, manual_pay)

    # Rain bonus stacks independently
    rain_raw = await redis.get(f"surge:RAIN:{city}")
    rain_pay = EARNING_RULES["RAIN_BONUS"] if rain_raw else 0.0

    total = surge_pay + rain_pay
    logger.debug(
        "get_surge_pay(%s): auto=%s(₹%.0f) manual=%s(₹%.0f) rain=%s(₹%.0f) → ₹%.0f",
        city, auto_raw, auto_pay, bool(manual_raw), manual_pay,
        bool(rain_raw), rain_pay, total,
    )
    return total
