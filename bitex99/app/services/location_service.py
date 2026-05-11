import uuid
import logging
from datetime import UTC, datetime
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload
from app.models.delivery_partner import DeliveryPartner
from app.models.partner_location import PartnerLocation
from app.models.delivery_assignment import DeliveryAssignment
from app.models.delivery_otp import DeliveryOtp
from app.models.order import Order
from app.utils.flutter_mapper import map_order_to_flutter

logger = logging.getLogger(__name__)

async def update_location(
    partner_id: uuid.UUID,
    latitude: float,
    longitude: float,
    speed_kmph: float | None,
    heading_degrees: int | None,
    accuracy_meters: float | None,
    db: AsyncSession,
    redis
) -> dict:
    if not (-90 <= latitude <= 90) or not (-180 <= longitude <= 180):
        return {"error": "Invalid coordinates", "received": False}

    partner = await db.scalar(select(DeliveryPartner).where(DeliveryPartner.id == partner_id))
    if partner:
        partner.current_latitude = latitude
        partner.current_longitude = longitude
        partner.last_location_at = datetime.now(UTC)
    
    location_log = PartnerLocation(
        partner_id=partner_id,
        latitude=latitude,
        longitude=longitude,
        speed_kmph=speed_kmph,
        heading_degrees=heading_degrees,
        accuracy_meters=accuracy_meters,
        recorded_at=datetime.now(UTC)
    )
    db.add(location_log)
    
    active_statuses = ['ASSIGNED', 'ACCEPTED', 'REACHED_RESTAURANT', 'PICKED_UP', 'REACHED_CUSTOMER']
    assignment = await db.scalar(
        select(DeliveryAssignment).where(
            DeliveryAssignment.partner_id == partner_id,
            DeliveryAssignment.status.in_(active_statuses)
        )
    )
    
    await db.flush()

    if assignment:
        try:
            from app.main import manager
            order = await db.scalar(
                select(Order)
                .options(selectinload(Order.items), selectinload(Order.restaurant))
                .where(Order.id == assignment.order_id)
            )
            otp = await db.scalar(
                select(DeliveryOtp).where(DeliveryOtp.assignment_id == assignment.id)
            )
            if order:
                if partner:
                    assignment.partner = partner
                payload = map_order_to_flutter(order, list(order.items or []), otp, assignment)
                payload["partnerLatitude"] = latitude
                payload["partnerLongitude"] = longitude
                payload["partner_location"] = {
                    "latitude": latitude,
                    "longitude": longitude,
                    "speed_kmph": speed_kmph,
                    "heading_degrees": heading_degrees,
                }
                await manager.send_to_user(
                    str(order.user_id),
                    {
                        "event": "PARTNER_LOCATION_UPDATE",
                        "order": payload,
                        "partner_location": payload["partner_location"],
                    },
                )
        except Exception as e:
            logger.warning("Failed to broadcast partner location: %s", e)

    return {"received": True, "active_assignment": str(assignment.id) if assignment else None}

def calculate_eta(lat1: float, lng1: float, lat2: float, lng2: float) -> int:
    import math
    R = 6371
    dlat = math.radians(lat2 - lat1)
    dlng = math.radians(lng2 - lng1)
    a = math.sin(dlat / 2) * math.sin(dlat / 2) + \
        math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * \
        math.sin(dlng / 2) * math.sin(dlng / 2)
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    distance_km = R * c
    return max(1, int((distance_km / 20) * 60))
