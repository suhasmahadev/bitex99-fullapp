from datetime import UTC, datetime, time

from fastapi import APIRouter
from sqlalchemy import func, or_, select

from app.dependencies import AdminUser, DB
from app.models.delivery_partner import DeliveryPartner
from app.models.order import Order
from app.models.restaurant import Restaurant
from app.models.restaurant_partner import RestaurantPartner
from app.models.user import User

router = APIRouter(prefix="/api/v1/admin", tags=["Admin"])


def _value(value):
    return value.value if hasattr(value, "value") else value


def _number(value):
    return float(value or 0)


@router.get("/stats")
async def get_admin_stats(admin: AdminUser, db: DB):
    today_start = datetime.combine(datetime.now(UTC).date(), time.min, tzinfo=UTC)

    total_users = await db.scalar(select(func.count(User.id)))
    total_delivery_partners = await db.scalar(select(func.count(DeliveryPartner.id)))
    approved_delivery_partners = await db.scalar(
        select(func.count(User.id)).where(User.partner_status == "KYC_APPROVED")
    )
    pending_kyc = await db.scalar(
        select(func.count(User.id)).where(User.partner_status == "KYC_SUBMITTED")
    )
    total_restaurants = await db.scalar(
        select(func.count(Restaurant.id)).where(Restaurant.is_open == True)
    )
    pending_restaurant_docs = await db.scalar(
        select(func.count(RestaurantPartner.id))
        .join(User, User.id == RestaurantPartner.user_id)
        .where(
            or_(
                User.restaurant_status.is_(None),
                User.restaurant_status.notin_(
                    ["DOCS_APPROVED", "DOCS_REJECTED", "SUSPENDED"]
                ),
            )
        )
    )
    orders_today = await db.scalar(
        select(func.count(Order.id)).where(Order.created_at >= today_start)
    )
    revenue_today = await db.scalar(
        select(func.sum(Order.total_amount)).where(
            Order.status == "DELIVERED",
            Order.created_at >= today_start,
        )
    )

    return {
        "total_users": total_users or 0,
        "total_delivery_partners": total_delivery_partners or 0,
        "approved_delivery_partners": approved_delivery_partners or 0,
        "pending_kyc": pending_kyc or 0,
        "total_restaurants": total_restaurants or 0,
        "pending_restaurant_docs": pending_restaurant_docs or 0,
        "orders_today": orders_today or 0,
        "revenue_today": _number(revenue_today),
    }


@router.get("/orders/recent")
async def get_recent_orders(admin: AdminUser, db: DB):
    stmt = (
        select(Order, Restaurant, User)
        .join(Restaurant, Restaurant.id == Order.restaurant_id)
        .join(User, User.id == Order.user_id)
        .order_by(Order.created_at.desc())
        .limit(10)
    )
    rows = (await db.execute(stmt)).all()
    return [
        {
            "order_id": order.id,
            "restaurant": restaurant.name,
            "customer": user.name or user.phone,
            "amount": _number(order.total_amount),
            "status": _value(order.status),
            "created_at": order.created_at,
        }
        for order, restaurant, user in rows
    ]


@router.get("/partners/active")
async def get_active_partners(admin: AdminUser, db: DB):
    stmt = (
        select(DeliveryPartner, User)
        .join(User, User.id == DeliveryPartner.user_id)
        .where(DeliveryPartner.is_online == True)
        .order_by(DeliveryPartner.last_location_at.desc().nullslast())
    )
    rows = (await db.execute(stmt)).all()
    return [
        {
            "partner_id": partner.id,
            "fe_id": partner.fe_id,
            "name": user.name,
            "phone": user.phone,
            "city": partner.city,
            "current_lat": _number(partner.current_latitude) if partner.current_latitude is not None else None,
            "current_lng": _number(partner.current_longitude) if partner.current_longitude is not None else None,
            "last_location_at": partner.last_location_at,
        }
        for partner, user in rows
    ]



# -- Surge management endpoints ------------------------------------------------

from fastapi import Depends, HTTPException
from datetime import timedelta
from sqlalchemy import not_, exists, func
from app.models.delivery_assignment import DeliveryAssignment, AssignmentStatus
from app.models.order import OrderStatus
import redis.asyncio as aioredis
from app.redis_client import get_redis

SURGE_CITIES = ["KR Nagar", "Hunsur"]
_SURGE_PAY_MAP = {"MILD": 10, "MEDIUM": 20, "HIGH": 30}


@router.get("/surge/status", summary="Get surge status for all cities")
async def get_surge_status(
    admin: AdminUser,
    db: DB,
    redis_client: aioredis.Redis = Depends(get_redis),
):
    """Return per-city surge info: live ratio, Redis keys, total surge pay."""
    now_utc = datetime.now(UTC)
    stale_cutoff = now_utc - timedelta(minutes=5)
    active_statuses = [
        AssignmentStatus.ASSIGNED.value,
        AssignmentStatus.ACCEPTED.value,
        AssignmentStatus.REACHED_RESTAURANT.value,
        AssignmentStatus.PICKED_UP.value,
        AssignmentStatus.REACHED_CUSTOMER.value,
    ]
    result = []
    for city in SURGE_CITIES:
        auto_raw   = await redis_client.get(f"surge:AUTO:{city}")
        manual_raw = await redis_client.get(f"surge:MANUAL:{city}")
        rain_raw   = await redis_client.get(f"surge:RAIN:{city}")
        if isinstance(auto_raw, bytes):   auto_raw   = auto_raw.decode()
        if isinstance(manual_raw, bytes): manual_raw = manual_raw.decode()
        if isinstance(rain_raw, bytes):   rain_raw   = rain_raw.decode()

        assigned_order_ids = select(DeliveryAssignment.order_id).where(
            DeliveryAssignment.status.in_(active_statuses)
        )
        orders_waiting = await db.scalar(
            select(func.count(Order.id))
            .where(
                Order.status.in_([OrderStatus.PLACED, OrderStatus.CONFIRMED]),
                Order.id.not_in(assigned_order_ids),
            )
            .join(Restaurant, Order.restaurant_id == Restaurant.id)
            .where(Restaurant.city == city)
        ) or 0

        online_partners = await db.scalar(
            select(func.count(DeliveryPartner.id)).where(
                DeliveryPartner.is_online == True,
                DeliveryPartner.city == city,
                DeliveryPartner.last_location_at > stale_cutoff,
                not_(exists(
                    select(DeliveryAssignment.id).where(
                        DeliveryAssignment.partner_id == DeliveryPartner.id,
                        DeliveryAssignment.status.in_(active_statuses),
                    )
                )),
            )
        ) or 0

        ratio = 999.0 if online_partners == 0 else round(orders_waiting / online_partners, 2)
        surge_pay = max(_SURGE_PAY_MAP.get(auto_raw or "", 0), 10 if manual_raw else 0)
        total_surge_pay = surge_pay + (20 if rain_raw else 0)

        result.append({
            "city": city,
            "auto_level":      auto_raw,
            "manual_active":   bool(manual_raw),
            "rain_active":     bool(rain_raw),
            "orders_waiting":  orders_waiting,
            "online_partners": online_partners,
            "ratio":           ratio,
            "total_surge_pay": total_surge_pay,
        })
    return {"cities": result}


@router.post("/surge/rain/enable", summary="Enable rain bonus for a city")
async def enable_rain_surge(
    admin: AdminUser,
    body: dict,
    redis_client: aioredis.Redis = Depends(get_redis),
):
    city: str = body.get("city", "")
    duration_minutes: int = int(body.get("duration_minutes", 120))
    if city not in SURGE_CITIES:
        raise HTTPException(status_code=400, detail=f"city must be one of {SURGE_CITIES}")
    await redis_client.set(f"surge:RAIN:{city}", "1", ex=duration_minutes * 60)
    return {"message": f"Rain bonus enabled for {city} for {duration_minutes} minutes",
            "rain_pay": 20, "city": city, "duration_minutes": duration_minutes}


@router.post("/surge/rain/disable", summary="Disable rain bonus for a city")
async def disable_rain_surge(
    admin: AdminUser,
    body: dict,
    redis_client: aioredis.Redis = Depends(get_redis),
):
    city: str = body.get("city", "")
    if city not in SURGE_CITIES:
        raise HTTPException(status_code=400, detail=f"city must be one of {SURGE_CITIES}")
    await redis_client.delete(f"surge:RAIN:{city}")
    return {"message": f"Rain bonus disabled for {city}", "city": city}
