"""
Assignment engine — SPEC2.md Section 7.

Haversine nearest-partner query using PostgreSQL math functions.
acos() argument is clamped with LEAST(1.0, GREATEST(-1.0, ...))
to prevent domain errors when partner and restaurant coordinates are identical.

Change 3: rejected-partner exclusion via Redis SET (rejected_partners:{order_id}).
"""

import logging
import uuid
from dataclasses import dataclass
from typing import Any

from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

logger = logging.getLogger(__name__)


@dataclass
class PartnerWithDistance:
    """Partner record with computed distance_km attached."""
    id: uuid.UUID
    user_id: uuid.UUID
    fe_id: str | None
    city: str
    vehicle_type: str | None
    vehicle_number: str | None
    vehicle_model: str | None
    is_online: bool
    current_latitude: float | None
    current_longitude: float | None
    rating: float
    total_deliveries: int
    acceptance_rate: float
    completion_rate: float
    total_earnings: float
    wallet_balance: float
    referral_code: str | None
    distance_km: float


# ── Base Haversine query (no rejection filter) ────────────────────────────────

HAVERSINE_QUERY = """
SELECT
    dp.id,
    dp.user_id,
    dp.fe_id,
    dp.city,
    dp.vehicle_type,
    dp.vehicle_number,
    dp.vehicle_model,
    dp.is_online,
    dp.current_latitude,
    dp.current_longitude,
    dp.rating,
    dp.total_deliveries,
    dp.acceptance_rate,
    dp.completion_rate,
    dp.total_earnings,
    dp.wallet_balance,
    dp.referral_code,
    (6371 * acos(LEAST(1.0, GREATEST(-1.0,
      cos(radians(:rest_lat)) * cos(radians(dp.current_latitude))
      * cos(radians(dp.current_longitude) - radians(:rest_lng))
      + sin(radians(:rest_lat)) * sin(radians(dp.current_latitude))
    )))) AS distance_km
FROM delivery_partners dp
WHERE dp.is_online = TRUE
  AND dp.last_location_at > now() - INTERVAL '10 minutes'
  AND NOT EXISTS (
    SELECT 1 FROM delivery_assignments da
    WHERE da.partner_id = dp.id
    AND da.status IN (
      'ASSIGNED','ACCEPTED','REACHED_RESTAURANT',
      'PICKED_UP','REACHED_CUSTOMER'
    )
  )
ORDER BY distance_km ASC
LIMIT :limit
"""

# ── Haversine query with rejected-partner exclusion ───────────────────────────

HAVERSINE_QUERY_WITH_EXCLUSIONS = """
SELECT
    dp.id,
    dp.user_id,
    dp.fe_id,
    dp.city,
    dp.vehicle_type,
    dp.vehicle_number,
    dp.vehicle_model,
    dp.is_online,
    dp.current_latitude,
    dp.current_longitude,
    dp.rating,
    dp.total_deliveries,
    dp.acceptance_rate,
    dp.completion_rate,
    dp.total_earnings,
    dp.wallet_balance,
    dp.referral_code,
    (6371 * acos(LEAST(1.0, GREATEST(-1.0,
      cos(radians(:rest_lat)) * cos(radians(dp.current_latitude))
      * cos(radians(dp.current_longitude) - radians(:rest_lng))
      + sin(radians(:rest_lat)) * sin(radians(dp.current_latitude))
    )))) AS distance_km
FROM delivery_partners dp
WHERE dp.is_online = TRUE
  AND dp.last_location_at > now() - INTERVAL '10 minutes'
  AND NOT EXISTS (
    SELECT 1 FROM delivery_assignments da
    WHERE da.partner_id = dp.id
    AND da.status IN (
      'ASSIGNED','ACCEPTED','REACHED_RESTAURANT',
      'PICKED_UP','REACHED_CUSTOMER'
    )
  )
  AND dp.id::text NOT IN (
    SELECT unnest(ARRAY[:rejected_ids]::text[])
  )
ORDER BY distance_km ASC
LIMIT :limit
"""


def _parse_partners(rows: list) -> list[PartnerWithDistance]:
    partners = []
    for row in rows:
        partners.append(PartnerWithDistance(
            id=row.id,
            user_id=row.user_id,
            fe_id=row.fe_id,
            city=row.city,
            vehicle_type=row.vehicle_type,
            vehicle_number=row.vehicle_number,
            vehicle_model=row.vehicle_model,
            is_online=row.is_online,
            current_latitude=float(row.current_latitude) if row.current_latitude else None,
            current_longitude=float(row.current_longitude) if row.current_longitude else None,
            rating=float(row.rating),
            total_deliveries=row.total_deliveries,
            acceptance_rate=float(row.acceptance_rate),
            completion_rate=float(row.completion_rate),
            total_earnings=float(row.total_earnings),
            wallet_balance=float(row.wallet_balance),
            referral_code=row.referral_code,
            distance_km=round(float(row.distance_km), 2),
        ))
    return partners


async def find_nearest_partners(
    restaurant_lat: float,
    restaurant_lng: float,
    city: str,
    db: AsyncSession,
    limit: int = 5,
    rejected_ids: set[str] | None = None,
) -> list[PartnerWithDistance]:
    """
    Find nearest online, available delivery partners using Haversine formula.

    Args:
        rejected_ids: Set of partner UUID strings to exclude (from Redis
                      `rejected_partners:{order_id}` key). If None or empty
                      the fast query without the NOT IN clause is used.

    Returns list sorted by distance ascending.
    """
    params: dict[str, Any] = {
        "rest_lat": restaurant_lat,
        "rest_lng": restaurant_lng,
        "limit": limit,
    }

    if rejected_ids:
        # Convert byte strings from Redis to str
        str_ids = [
            r.decode() if isinstance(r, bytes) else str(r)
            for r in rejected_ids
        ]
        params["rejected_ids"] = str_ids
        result = await db.execute(text(HAVERSINE_QUERY_WITH_EXCLUSIONS), params)
    else:
        result = await db.execute(text(HAVERSINE_QUERY), params)

    rows = result.fetchall()
    partners = _parse_partners(rows)

    logger.info(
        "Found %d eligible partners by real GPS near %s (rest: %.4f, %.4f) excluded=%d",
        len(partners), city, restaurant_lat, restaurant_lng,
        len(rejected_ids) if rejected_ids else 0,
    )
    return partners
