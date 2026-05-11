from __future__ import annotations

from typing import Any


def _value(value: Any) -> Any:
    return value.value if hasattr(value, "value") else value


def strip_plus91(phone: str | None) -> str:
    return phone.replace("+91", "") if phone else ""


def add_plus91(phone: str | None) -> str | None:
    if not phone:
        return phone
    phone = phone.strip()
    if phone.startswith("+91"):
        return phone
    if phone.startswith("91") and len(phone) == 12:
        return "+" + phone
    return "+91" + phone


def map_role_to_flutter(backend_role: str | None) -> str:
    mapping = {
        "CUSTOMER": "customer",
        "DELIVERY_PARTNER": "agent",
        "RESTAURANT_PARTNER": "restaurant",
        "ADMIN": "admin",
    }
    return mapping.get(str(_value(backend_role)), "customer")


def map_role_to_backend(flutter_role: str | None) -> str:
    mapping = {
        "customer": "CUSTOMER",
        "agent": "DELIVERY_PARTNER",
        "restaurant": "RESTAURANT_PARTNER",
        "admin": "ADMIN",
    }
    return mapping.get((flutter_role or "customer").lower(), "CUSTOMER")


def map_kyc_status_to_flutter(partner_status: str | None) -> str:
    mapping = {
        None: "notSubmitted",
        "PENDING_KYC": "notSubmitted",
        "KYC_SUBMITTED": "pending",
        "KYC_APPROVED": "approved",
        "KYC_REJECTED": "rejected",
    }
    return mapping.get(str(_value(partner_status)) if partner_status is not None else None, "notSubmitted")


def map_restaurant_status_to_flutter(restaurant_status: str | None) -> str:
    mapping = {
        None: "notRegistered",
        "PENDING_DOCS": "pending",
        "DOCS_SUBMITTED": "pending",
        "DOCS_APPROVED": "active",
        "DOCS_REJECTED": "rejected",
        "SUSPENDED": "rejected",
    }
    return mapping.get(str(_value(restaurant_status)) if restaurant_status is not None else None, "pending")


def map_order_status_to_flutter(backend_status: str | None) -> str:
    mapping = {
        "PLACED": "received",
        "CONFIRMED": "confirmed",
        "PREPARING": "preparing",
        "READY_FOR_PICKUP": "pickup_ready",
        "OUT_FOR_DELIVERY": "delivering",
        "DELIVERED": "delivered",
        "CANCELLED": "cancelled",
        "FAILED": "cancelled",
    }
    return mapping.get(str(_value(backend_status)), "received")


def map_order_status_to_backend(flutter_status: str | None) -> str:
    mapping = {
        "received": "PLACED",
        "confirmed": "CONFIRMED",
        "preparing": "CONFIRMED",
        "pickup_ready": "READY_FOR_PICKUP",
        "delivering": "OUT_FOR_DELIVERY",
        "delivered": "DELIVERED",
        "cancelled": "CANCELLED",
    }
    return mapping.get((flutter_status or "received").lower(), "PLACED")


def map_order_to_flutter(order, order_items, delivery_otp=None, assignment=None) -> dict:
    restaurant = getattr(order, "__dict__", {}).get("restaurant")
    snapshot = order.delivery_address_snapshot or {}
    partner = None
    if assignment is not None:
        partner = getattr(assignment, "__dict__", {}).get("partner")
    partner_user = None
    if partner is not None:
        partner_user = getattr(partner, "__dict__", {}).get("user")

    def as_float(value: Any) -> float | None:
        if value is None:
            return None
        try:
            return float(value)
        except (TypeError, ValueError):
            return None

    items = [
        {
            "itemId": str(item.menu_item_id) if item.menu_item_id else "",
            "name": item.name,
            "quantity": int(item.quantity),
            "price": float(item.price),
            "totalPrice": float(item.price) * int(item.quantity),
        }
        for item in order_items
    ]
    restaurant_payload = {
        "id": str(order.restaurant_id),
        "name": getattr(restaurant, "name", "") or "",
        "address": getattr(restaurant, "full_address", "") or "",
        "full_address": getattr(restaurant, "full_address", "") or "",
        "latitude": as_float(getattr(restaurant, "latitude", None)),
        "longitude": as_float(getattr(restaurant, "longitude", None)),
    }
    address_payload = {
        "full_address": snapshot.get("full_address", ""),
        "landmark": snapshot.get("landmark", ""),
        "latitude": snapshot.get("latitude"),
        "longitude": snapshot.get("longitude"),
    }
    partner_payload = {
        "id": str(assignment.partner_id) if assignment else None,
        "name": getattr(partner_user, "name", "") if partner_user else "",
        "phone": getattr(partner_user, "phone", "") if partner_user else "",
        "vehicle_number": getattr(partner, "vehicle_number", "") if partner else "",
        "rating": as_float(getattr(partner, "rating", None)) or 0,
    }
    partner_location = {
        "latitude": as_float(getattr(partner, "current_latitude", None)) if partner else None,
        "longitude": as_float(getattr(partner, "current_longitude", None)) if partner else None,
    }
    return {
        "id": str(order.id),
        "customerId": str(order.user_id),
        "restaurantId": str(order.restaurant_id),
        "agentId": str(assignment.partner_id) if assignment else None,
        "town": getattr(restaurant, "city", None) or snapshot.get("city", ""),
        "items": items,
        "orderItems": items,
        "totalAmount": float(order.total_amount),
        "paymentMethod": str(_value(order.payment_method)).lower(),
        "landmark": snapshot.get("full_address", ""),
        "status": map_order_status_to_flutter(order.status),
        "pickupCode": delivery_otp.otp if delivery_otp else None,
        "deliveryOtp": delivery_otp.otp if delivery_otp else None,
        "restaurantName": restaurant_payload["name"],
        "restaurantAddress": restaurant_payload["address"],
        "restaurantLatitude": restaurant_payload["latitude"],
        "restaurantLongitude": restaurant_payload["longitude"],
        "customerLatitude": address_payload["latitude"],
        "customerLongitude": address_payload["longitude"],
        "partnerName": partner_payload["name"],
        "partnerPhone": partner_payload["phone"],
        "partnerVehicleNumber": partner_payload["vehicle_number"],
        "partnerRating": partner_payload["rating"],
        "partnerLatitude": partner_location["latitude"],
        "partnerLongitude": partner_location["longitude"],
        "itemsTotal": float(order.items_total),
        "deliveryFee": float(order.delivery_fee),
        "totalPaid": float(order.total_amount),
        "estimatedMinutes": order.preparation_time or getattr(restaurant, "avg_delivery_time", None) or 0,
        "preparation_time": order.preparation_time,
        "assignment_id": str(assignment.id) if assignment else None,
        "delivery_stage": str(_value(assignment.status)) if assignment else None,
        "restaurant": restaurant_payload,
        "delivery_address": address_payload,
        "partner": partner_payload,
        "partner_location": partner_location,
        "payment_summary": {
            "items_total": float(order.items_total),
            "delivery_fee": float(order.delivery_fee),
            "total_paid": float(order.total_amount),
        },
        "createdAt": order.created_at.isoformat() if order.created_at else None,
        "updatedAt": order.updated_at.isoformat() if order.updated_at else None,
    }
