"""
FastAPI application factory with lifespan, middleware, routers, and OpenAPI config.
"""
import asyncio
import logging
from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI
from fastapi.responses import HTMLResponse

from app.config import get_settings
from app.exceptions import register_exception_handlers
from app.middleware import register_middleware
from app.redis_client import close_redis, init_redis
from app.routers import admin, auth, users, addresses, restaurants, menu, cart, orders, reviews, coupons
from app.routers.delivery import kyc, profile as delivery_profile, admin_kyc, duty, assignments, location, earnings, payouts, support, incentives
from app.routers.restaurant import profile as restaurant_profile, documents as restaurant_documents, admin_restaurant
from app.routers.restaurant import menu as restaurant_menu, orders as restaurant_orders
from app.routers.restaurant import analytics as restaurant_analytics, payouts as restaurant_payouts
from app.routers.restaurant import offers as restaurant_offers, reviews as restaurant_reviews
from app.routers import flutter_api
from fastapi.staticfiles import StaticFiles

settings = get_settings()

logging.basicConfig(
    level=logging.DEBUG if settings.DEBUG else logging.INFO,
    format="%(asctime)s | %(levelname)-8s | %(name)s | %(message)s",
)
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("🚀  %s v%s starting…", settings.APP_NAME, settings.APP_VERSION)
    await init_redis()
    
    import asyncio
    from sqlalchemy.ext.asyncio import AsyncSession
    from app.database import AsyncSessionLocal
    from app.models.delivery_partner import DeliveryPartner
    from app.models.partner_location import PartnerLocation
    from app.models.partner_shift import PartnerShift
    from datetime import UTC, datetime, timedelta
    from sqlalchemy import select, delete

    async def cleanup_task():
        while True:
            try:
                await asyncio.sleep(300) # every 5 mins
                async with AsyncSessionLocal() as db:
                    now_utc = datetime.now(UTC)
                    await db.execute(delete(PartnerLocation).where(PartnerLocation.recorded_at < now_utc - timedelta(hours=24)))
                    
                    stale_time = now_utc - timedelta(minutes=10)
                    stale_partners = await db.scalars(
                        select(DeliveryPartner).where(
                            DeliveryPartner.is_online == True,
                            DeliveryPartner.last_location_at < stale_time
                        )
                    )
                    for p in stale_partners:
                        p.is_online = False
                        logger.info(f"Partner {p.fe_id} auto-offlined — stale GPS")
                        shift = await db.scalar(
                            select(PartnerShift).where(
                                PartnerShift.partner_id == p.id,
                                PartnerShift.ended_at.is_(None)
                            )
                        )
                        if shift:
                            shift.ended_at = now_utc
                            
                    await db.commit()
            except Exception as e:
                logger.error(f"Cleanup task error: {e}")

    # ── Auto-surge background task (Change 2) ─────────────────────────────
    from app.redis_client import get_redis as _get_redis

    async def auto_surge_check():
        """
        Every 10 minutes: compute order/partner ratio per city and set
        surge:AUTO:{city} key in Redis.  Key: "MILD" | "MEDIUM" | "HIGH"
        TTL: 660 s (10 min + 1 min buffer).
        """
        CITIES = ["KR Nagar", "Hunsur"]
        while True:
            await asyncio.sleep(600)
            try:
                _redis = await _get_redis()
                async with AsyncSessionLocal() as db:
                    from app.models.order import Order, OrderStatus
                    from app.models.delivery_assignment import DeliveryAssignment, AssignmentStatus
                    from app.models.delivery_partner import DeliveryPartner
                    from app.models.restaurant import Restaurant
                    from sqlalchemy import select, func, not_, exists

                    for city in CITIES:
                        # Orders waiting: PLACED or CONFIRMED, in this city,
                        # with no active accepted delivery assignment
                        active_statuses = [
                            AssignmentStatus.ASSIGNED.value,
                            AssignmentStatus.ACCEPTED.value,
                            AssignmentStatus.REACHED_RESTAURANT.value,
                            AssignmentStatus.PICKED_UP.value,
                            AssignmentStatus.REACHED_CUSTOMER.value,
                        ]
                        assigned_order_ids = select(DeliveryAssignment.order_id).where(
                            DeliveryAssignment.status.in_(active_statuses)
                        )
                        orders_waiting = await db.scalar(
                            select(func.count(Order.id)).where(
                                Order.status.in_([OrderStatus.PLACED, OrderStatus.CONFIRMED]),
                                Order.id.not_in(assigned_order_ids),
                            ).join(
                                Restaurant, Order.restaurant_id == Restaurant.id
                            ).where(Restaurant.city == city)
                        ) or 0

                        # Online partners with fresh GPS, no active assignment
                        stale_cutoff = datetime.now(UTC) - timedelta(minutes=5)
                        online_partners = await db.scalar(
                            select(func.count(DeliveryPartner.id)).where(
                                DeliveryPartner.is_online == True,
                                DeliveryPartner.city == city,
                                DeliveryPartner.last_location_at > stale_cutoff,
                                not_(
                                    exists(
                                        select(DeliveryAssignment.id).where(
                                            DeliveryAssignment.partner_id == DeliveryPartner.id,
                                            DeliveryAssignment.status.in_(active_statuses),
                                        )
                                    )
                                ),
                            )
                        ) or 0

                        ratio = 999.0 if online_partners == 0 else orders_waiting / online_partners
                        surge_key = f"surge:AUTO:{city}"

                        if ratio > 4.5:
                            await _redis.set(surge_key, "HIGH", ex=660)
                            logger.info("Auto-surge HIGH for %s (ratio=%.1f)", city, ratio)
                        elif ratio > 3.0:
                            await _redis.set(surge_key, "MEDIUM", ex=660)
                            logger.info("Auto-surge MEDIUM for %s (ratio=%.1f)", city, ratio)
                        elif ratio > 2.0:
                            await _redis.set(surge_key, "MILD", ex=660)
                            logger.info("Auto-surge MILD for %s (ratio=%.1f)", city, ratio)
                        else:
                            await _redis.delete(surge_key)
                            logger.debug("Auto-surge cleared for %s (ratio=%.1f)", city, ratio)
            except Exception as e:
                logger.error("Auto-surge check error: %s", e)

    task = asyncio.create_task(cleanup_task())
    surge_task = asyncio.create_task(auto_surge_check())
    yield
    task.cancel()
    surge_task.cancel()
    await close_redis()
    logger.info("🛑  %s shut down", settings.APP_NAME)


app = FastAPI(
    title=settings.APP_NAME,
    version=settings.APP_VERSION,
    description="Production-grade Zomato customer API: OTP auth, restaurant discovery, cart, orders, reviews.",
    docs_url="/docs",
    redoc_url="/redoc",
    lifespan=lifespan,
    redirect_slashes=False,
)

register_middleware(app)
register_exception_handlers(app)

# ── Routers ───────────────────────────────────────────────────────────────────
app.include_router(auth.router)
app.include_router(users.router)
app.include_router(addresses.router)
app.include_router(restaurants.router)
app.include_router(menu.router)
app.include_router(cart.router)
app.include_router(orders.router)
app.include_router(reviews.router)
app.include_router(coupons.router)
app.include_router(admin.router)
app.include_router(kyc.router)
app.include_router(delivery_profile.router)
app.include_router(admin_kyc.router)
app.include_router(duty.router)
app.include_router(assignments.router)
app.include_router(location.router)
app.include_router(earnings.router)
app.include_router(payouts.router)
app.include_router(support.router)
app.include_router(incentives.router)

app.include_router(restaurant_profile.router)
app.include_router(restaurant_documents.router)
app.include_router(admin_restaurant.router)
app.include_router(restaurant_menu.router)
app.include_router(restaurant_orders.router)
app.include_router(restaurant_analytics.router)
app.include_router(restaurant_payouts.router)
app.include_router(restaurant_offers.router)
app.include_router(restaurant_reviews.router)

# ── Flutter Compatibility Layer ───────────────────────────────────────────────
app.include_router(flutter_api.router)

import os
os.makedirs("uploads", exist_ok=True)
app.mount("/uploads", StaticFiles(directory="uploads"), name="uploads")
app.mount("/static", StaticFiles(directory="static"), name="static")

from fastapi import WebSocket, WebSocketDisconnect, Query
from app.utils.jwt import verify_access_token
from datetime import UTC, datetime

class ConnectionManager:
    def __init__(self):
        self.partner_order_connections = {}
        self.partner_location_connections = {}
        self.restaurant_connections = {}   # restaurant_id (str) → WebSocket
        self.user_connections = {}         # user_id (str) → WebSocket

    async def send_to_partner(self, partner_id, message):
        ws = self.partner_order_connections.get(str(partner_id))
        if ws:
            try:
                await ws.send_json(message)
            except Exception:
                self.partner_order_connections.pop(str(partner_id), None)

    async def send_to_user(self, user_id, message):
        ws = self.user_connections.get(str(user_id))
        if ws:
            try:
                await ws.send_json(message)
            except Exception:
                self.user_connections.pop(str(user_id), None)

    async def send_to_restaurant(self, restaurant_id, message):
        ws = self.restaurant_connections.get(str(restaurant_id))
        if ws:
            try:
                await ws.send_json(message)
            except Exception:
                self.restaurant_connections.pop(str(restaurant_id), None)

manager = ConnectionManager()
app.state.connection_manager = manager

@app.websocket("/api/v1/ws/partner/location")
async def partner_location_ws(websocket: WebSocket, token: str = Query(...)):
    from app.services import location_service
    from app.database import AsyncSessionLocal
    from app.redis_client import get_redis

    await websocket.accept()
    partner_id = None

    try:
        payload = verify_access_token(token)
        role = payload.get("role", "")
        partner_id = payload.get("partner_id")

        if role != "DELIVERY_PARTNER":
            await websocket.send_json({"event": "ERROR", "code": 4003, "message": f"Wrong role:{role}"})
            await websocket.close(code=4003, reason="Wrong role")
            return

        if not partner_id:
            await websocket.send_json({"event": "ERROR", "code": 4003, "message": "No partner on account"})
            await websocket.close(code=4003, reason="No partner on account")
            return
    except Exception:
        await websocket.send_json({"event": "ERROR", "code": 4001, "message": "Invalid token"})
        await websocket.close(code=4001, reason="Invalid token")
        return
    
    async with AsyncSessionLocal() as db:
        from app.models.delivery_partner import DeliveryPartner
        from sqlalchemy import select
        partner = await db.scalar(select(DeliveryPartner).where(DeliveryPartner.id == partner_id))
        if not partner or not partner.is_online:
            await websocket.send_json({"event": "ERROR", "code": 4003, "message": "Partner offline"})
            await websocket.close(code=4001, reason="Partner offline")
            return

    partner_key = str(partner_id)
    manager.partner_location_connections[partner_key] = websocket
    await websocket.send_json({"event": "CONNECTED", "message": "Location tracking active"})
    
    redis = get_redis()
    
    try:
        while True:
            data = await websocket.receive_json()
            lat = data.get('latitude', 0)
            lng = data.get('longitude', 0)
            async with AsyncSessionLocal() as db:
                from app.models.delivery_partner import DeliveryPartner
                from sqlalchemy import update
                await db.execute(
                    update(DeliveryPartner)
                    .where(DeliveryPartner.id == partner_id)
                    .values(
                        current_latitude=lat,
                        current_longitude=lng,
                        last_location_at=datetime.now(UTC),
                    )
                )
                await location_service.update_location(
                    partner_id,
                    lat,
                    lng,
                    data.get('speed_kmph'),
                    data.get('heading_degrees'),
                    data.get('accuracy_meters'),
                    db,
                    redis
                )
                await db.commit()
            await websocket.send_json({
                "event": "LOCATION_RECEIVED",
                "timestamp": datetime.now(UTC).isoformat()
            })
    except (WebSocketDisconnect, asyncio.CancelledError):
        pass
    except Exception as e:
        logger.error("Partner location WS error for %s: %s", partner_id, e, exc_info=True)
    finally:
        if partner_id:
            manager.partner_location_connections.pop(str(partner_id), None)


@app.websocket("/api/v1/ws/partner/orders")
async def partner_orders_ws(websocket: WebSocket, token: str = Query(...)):
    from app.redis_client import get_redis

    await websocket.accept()
    partner_id = None

    try:
        payload = verify_access_token(token)
        role = payload.get("role", "")
        partner_id = payload.get("partner_id")

        if role != "DELIVERY_PARTNER":
            await websocket.send_json({"event": "ERROR", "code": 4003, "message": f"Wrong role:{role}"})
            await websocket.close(code=4003, reason="Wrong role")
            return

        if not partner_id:
            await websocket.send_json({"event": "ERROR", "code": 4003, "message": "No partner on account"})
            await websocket.close(code=4003, reason="No partner on account")
            return
    except Exception:
        await websocket.send_json({"event": "ERROR", "code": 4001, "message": "Invalid token"})
        await websocket.close(code=4001, reason="Invalid token")
        return

    partner_key = str(partner_id)
    manager.partner_order_connections[partner_key] = websocket
    await websocket.send_json({"event": "CONNECTED"})
    
    redis = get_redis()
    val = await redis.get(f"assignment_pending:{partner_key}")
    if val:
        assignment_id = val.decode() if isinstance(val, bytes) else str(val)
        try:
            from app.database import AsyncSessionLocal
            from app.services.assignment_service import AssignmentService
            import uuid as _uuid
            async with AsyncSessionLocal() as db:
                payload = await AssignmentService(db, redis).assignment_offer_payload(
                    _uuid.UUID(assignment_id)
                )
            if payload:
                await websocket.send_json({"event": "NEW_ORDER", "assignment": payload})
            else:
                await websocket.send_json({"event": "NEW_ORDER"})
        except Exception:
            await websocket.send_json({"event": "NEW_ORDER"})
        
    try:
        while True:
            try:
                await asyncio.wait_for(websocket.receive_text(), timeout=30)
            except asyncio.TimeoutError:
                await websocket.send_json({"event": "PING"})
            except WebSocketDisconnect:
                break
    except (WebSocketDisconnect, asyncio.CancelledError):
        pass
    except Exception as e:
        logger.error("Partner orders WS error for %s: %s", partner_id, e, exc_info=True)
    finally:
        if partner_id:
            manager.partner_order_connections.pop(str(partner_id), None)


@app.websocket("/api/v1/ws/restaurant/orders")
async def restaurant_orders_ws(websocket: WebSocket, token: str = Query(...)):
    """Restaurant real-time order feed."""
    import json as _json
    import uuid as _uuid
    from app.redis_client import get_redis

    await websocket.accept()
    restaurant_id = None

    try:
        payload = verify_access_token(token)
        role = payload.get("role", "")
        restaurant_id = payload.get("restaurant_id")
    except Exception:
        await websocket.send_json({"event": "ERROR", "code": 4001, "message": "Invalid token"})
        await websocket.close(code=4001, reason="Invalid token")
        return

    logger.info(
        "Restaurant WS: role=%s restaurant_id=%s user=%s",
        role, restaurant_id, payload.get("sub"),
    )

    if role != "RESTAURANT_PARTNER":
        await websocket.send_json({"event": "ERROR", "code": 4003, "message": f"Wrong role:{role}"})
        await websocket.close(code=4003, reason="Wrong role")
        return

    if not restaurant_id or restaurant_id == "None":
        await websocket.send_json({"event": "ERROR", "code": 4003, "message": "No restaurant on account"})
        await websocket.close(code=4003, reason="No restaurant associated with account")
        return

    logger.info("Restaurant WS accepted: restaurant_id=%s", restaurant_id)

    try:
        manager.restaurant_connections[str(restaurant_id)] = websocket
        await websocket.send_json({"event": "CONNECTED"})

        redis = get_redis()

        # Drain buffered pending orders
        key = f"restaurant:pending:{restaurant_id}"
        while True:
            order_json = await redis.lpop(key)
            if not order_json:
                break
            try:
                await websocket.send_json(_json.loads(order_json))
            except Exception:
                break

        # Send current PLACED orders immediately
        async with AsyncSessionLocal() as db:
            from app.services.order_management_service import OrderManagementService
            svc = OrderManagementService(db)
            live = await svc.get_live_orders(_uuid.UUID(str(restaurant_id)))
            if live.get("placed"):
                await websocket.send_json({"event": "PENDING_ORDERS", "orders": live["placed"]})

        # Keep-alive ping loop
        while True:
            try:
                await asyncio.wait_for(websocket.receive_text(), timeout=30)
            except asyncio.TimeoutError:
                await websocket.send_json({"event": "PING"})
            except WebSocketDisconnect:
                break
    except (WebSocketDisconnect, asyncio.CancelledError):
        pass
    except Exception as e:
        logger.error("Restaurant WS crash for %s: %s", restaurant_id, e, exc_info=True)
    finally:
        manager.restaurant_connections.pop(str(restaurant_id), None)


@app.websocket("/api/v1/ws/orders/{order_id}")
async def customer_order_ws(websocket: WebSocket, order_id: str, token: str = Query(...)):
    """Customer order tracking feed."""
    from app.database import AsyncSessionLocal
    from app.models.order import Order
    from sqlalchemy import select
    import uuid as _uuid

    await websocket.accept()
    user_id = None

    try:
        payload = verify_access_token(token)
        role = payload.get("role", "")
        if role != "CUSTOMER":
            await websocket.send_json({"event": "ERROR", "code": 4003, "message": f"Wrong role:{role}"})
            await websocket.close(code=4003, reason="Wrong role")
            return
    except Exception:
        await websocket.send_json({"event": "ERROR", "code": 4001, "message": "Invalid token"})
        await websocket.close(code=4001, reason="Invalid token")
        return

    try:
        oid = _uuid.UUID(str(order_id))
    except (TypeError, ValueError):
        await websocket.send_json({"event": "ERROR", "code": 4003, "message": "Invalid order ID"})
        await websocket.close(code=4003, reason="Invalid order ID")
        return

    async with AsyncSessionLocal() as db:
        order = await db.scalar(select(Order).where(Order.id == oid))
        if not order:
            await websocket.send_json({"event": "ERROR", "code": 4004, "message": "Order not found"})
            await websocket.close(code=4004, reason="Order not found")
            return
        user_id = str(order.user_id)
        if payload.get("sub") != user_id:
            await websocket.send_json({"event": "ERROR", "code": 4003, "message": "Not your order"})
            await websocket.close(code=4003, reason="Not your order")
            return

    manager.user_connections[user_id] = websocket
    await websocket.send_json({"event": "CONNECTED", "order_id": str(oid)})

    try:
        while True:
            try:
                await asyncio.wait_for(websocket.receive_text(), timeout=30)
            except asyncio.TimeoutError:
                await websocket.send_json({"event": "PING"})
            except WebSocketDisconnect:
                break
    except (WebSocketDisconnect, asyncio.CancelledError):
        pass
    except Exception as e:
        logger.error("Customer order WS error for %s: %s", order_id, e, exc_info=True)
    finally:
        if user_id:
            manager.user_connections.pop(user_id, None)
# ── Health ────────────────────────────────────────────────────────────────────
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import text
from fastapi import Depends
from app.database import AsyncSessionLocal, get_db
from app.redis_client import get_redis
import redis.asyncio as aioredis

@app.get("/api/v1/health", tags=["Health"], include_in_schema=True)
async def health(
    db: AsyncSession = Depends(get_db),
    redis: aioredis.Redis = Depends(get_redis),
) -> dict:
    from datetime import UTC, datetime
    db_status = "ok"
    redis_status = "ok"

    try:
        await db.execute(text("SELECT 1"))
    except Exception as e:
        logger.error("DB health check failed: %s", e)
        db_status = "error"

    try:
        await redis.ping()
    except Exception as e:
        logger.error("Redis health check failed: %s", e)
        redis_status = "error"

    overall = "ok" if db_status == "ok" and redis_status == "ok" else "degraded"
    return {
        "success": True,
        "data": {
            "status": overall,
            "db": db_status,
            "redis": redis_status,
            "version": settings.APP_VERSION,
            "timestamp": datetime.now(UTC).isoformat(),
        },
    }


# ── Frontend test UI ──────────────────────────────────────────────────────────
_STATIC = Path(__file__).parent.parent / "static" / "index.html"


@app.get("/", response_class=HTMLResponse, include_in_schema=False)
async def frontend() -> HTMLResponse:
    return HTMLResponse(content=_STATIC.read_text(encoding="utf-8"))
