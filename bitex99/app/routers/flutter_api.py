from __future__ import annotations

import base64
import os
import socket
import time
import uuid
from datetime import UTC, datetime, timedelta
from pathlib import Path
from typing import Any

from fastapi import APIRouter, Depends, File, Form, HTTPException, Request, UploadFile
from fastapi.responses import JSONResponse
from pydantic import BaseModel
from sqlalchemy import delete, func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.config import get_settings
from app.database import get_db
from app.dependencies import get_current_user, redis_dep, require_restaurant_partner
from app.models.address import Address, AddressLabel
from app.models.cart import CartItem
from app.models.delivery_assignment import AssignmentStatus, DeliveryAssignment
from app.models.delivery_otp import DeliveryOtp
from app.models.delivery_partner import DeliveryPartner
from app.models.kyc_document import DocStatus as KycDocStatus
from app.models.kyc_document import DocType as KycDocType
from app.models.kyc_document import KycDocument
from app.models.menu import MenuCategory, MenuItem
from app.models.order import Order, OrderItem, OrderStatus, PaymentMethod
from app.models.partner_earnings import PartnerEarnings
from app.models.partner_shift import PartnerShift
from app.models.restaurant import Restaurant
from app.models.restaurant_document import DocStatus as RestaurantDocStatus
from app.models.restaurant_document import DocType as RestaurantDocType
from app.models.restaurant_document import RestaurantDocument
from app.models.restaurant_partner import BusinessType, RestaurantPartner
from app.models.user import User
from app.schemas.address import CreateAddressRequest
from app.schemas.auth import SendOTPRequest, VerifyOTPRequest
from app.schemas.cart import AddToCartRequest
from app.schemas.cart import UpdateQuantityRequest
from app.schemas.order import CancelOrderRequest, PlaceOrderRequest
from app.schemas.review import CreateReviewRequest
from app.schemas.restaurant_partner import RestaurantSetupRequest
from app.services.assignment_service import AssignmentService
from app.services.auth_service import AuthService
from app.services.address_service import AddressService
from app.services.cart_service import CartConflictError, CartService, ItemUnavailableError
from app.services.menu_management_service import MenuManagementService
from app.services.order_management_service import OrderManagementService
from app.services.order_service import OrderService, OrderServiceError
from app.services.restaurant_partner_service import RestaurantPartnerService
from app.services.restaurant_service import RestaurantService
from app.services.review_service import ReviewService
from app.utils import otp as otp_utils
from app.utils.flutter_mapper import (
    add_plus91,
    map_kyc_status_to_flutter,
    map_order_status_to_backend,
    map_order_status_to_flutter,
    map_order_to_flutter,
    map_restaurant_status_to_flutter,
    map_role_to_backend,
    map_role_to_flutter,
    strip_plus91,
)
from app.dependencies import require_admin
from app.routers.admin import get_surge_status, enable_rain_surge, disable_rain_surge

router = APIRouter(prefix="/api/flutter/v1", tags=["Flutter Compatibility"])


class SendOtpBody(BaseModel):
    phone: str


class VerifyOtpBody(BaseModel):
    phone: str
    otp: str
    name: str | None = None
    role: str = "customer"
    town: str | None = None


class LogoutBody(BaseModel):
    token: str | None = None


class RefreshBody(BaseModel):
    refresh_token: str


class RestaurantCreateBody(BaseModel):
    shopName: str
    ownerName: str
    phone: str
    email: str | None = None
    town: str
    address: str
    cuisineType: str
    cuisineTypes: list[str] | None = None
    fssaiNumber: str
    status: str | None = "pending"
    restaurantImageUrl: str | None = None


class StatusBody(BaseModel):
    status: str
    rejectionReason: str | None = None


class OnlineRestaurantBody(BaseModel):
    isOpen: bool


class MenuCreateBody(BaseModel):
    name: str
    description: str | None = ""
    price: float
    category: str
    available: bool = True
    imageUrl: str | None = ""
    isSpecial: bool = False
    preparationTime: int | None = 15
    isVeg: bool = True


class MenuUpdateBody(BaseModel):
    available: bool | None = None
    price: float | None = None
    name: str | None = None
    description: str | None = None
    imageUrl: str | None = None
    preparationTime: int | None = None


class FlutterOrderItem(BaseModel):
    itemId: str
    name: str | None = None
    quantity: int
    price: float | None = None
    totalPrice: float | None = None


class OrderCreateBody(BaseModel):
    customerId: str | None = None
    restaurantId: str
    town: str | None = None
    items: list[FlutterOrderItem]
    totalAmount: float | None = None
    paymentMethod: str = "cash"
    landmark: str
    latitude: float | None = None
    longitude: float | None = None


class OrderStatusBody(BaseModel):
    status: str


class OrderAgentBody(BaseModel):
    agentId: str | None = None
    status: str = "delivering"


class CompleteOrderBody(BaseModel):
    deliveredOtp: str
    agentId: str | None = None


class AgentKycBody(BaseModel):
    agentId: str | None = None
    step1: dict[str, Any] = {}
    step2: dict[str, Any] = {}
    step3: dict[str, Any] = {}
    step4: dict[str, Any] = {}


class AgentOnlineBody(BaseModel):
    isOnline: bool
    latitude: float | None = None
    longitude: float | None = None


class DutyStartBody(BaseModel):
    latitude: float
    longitude: float


class ImageBase64Body(BaseModel):
    imageBase64: str
    imageName: str
    type: str = "misc"


class CartItemBody(BaseModel):
    menu_item_id: uuid.UUID
    quantity: int = 1


class FlutterAddressBody(BaseModel):
    label: str = "OTHER"
    full_address: str
    landmark: str | None = None
    latitude: float | None = None
    longitude: float | None = None
    is_default: bool = False
    flat_number: str | None = None
    contact_name: str | None = None
    contact_phone: str | None = None


class NotificationRegisterBody(BaseModel):
    fcm_token: str
    platform: str


class UserPatchBody(BaseModel):
    name: str | None = None
    email: str | None = None
    dob: str | None = None
    anniversary: str | None = None
    gender: str | None = None
    profile_picture: str | None = None


class FlutterPlaceOrderBody(BaseModel):
    delivery_address_id: uuid.UUID | None = None
    payment_method: str | None = None
    coupon_code: str | None = None
    restaurantId: str | None = None
    town: str | None = None
    items: list[FlutterOrderItem] | None = None
    totalAmount: float | None = None
    paymentMethod: str | None = None
    landmark: str | None = None
    latitude: float | None = None
    longitude: float | None = None


def _as_uuid(value: str | uuid.UUID) -> uuid.UUID:
    if isinstance(value, uuid.UUID):
        return value
    try:
        return uuid.UUID(str(value))
    except ValueError as exc:
        raise HTTPException(status_code=400, detail="Invalid UUID") from exc


def _optional_uuid(value: str | uuid.UUID) -> uuid.UUID | None:
    if isinstance(value, uuid.UUID):
        return value
    try:
        return uuid.UUID(str(value))
    except ValueError:
        return None


async def _resolve_restaurant(db: AsyncSession, identifier: str | uuid.UUID) -> Restaurant:
    """Accept new UUID ids and legacy Flutter ids (owner user id or phone)."""
    value = str(identifier).strip()
    restaurant = None
    maybe_uuid = _optional_uuid(identifier)

    if maybe_uuid:
        restaurant = await db.scalar(select(Restaurant).where(Restaurant.id == maybe_uuid))
        if not restaurant:
            partner = await db.scalar(
                select(RestaurantPartner).where(
                    or_(
                        RestaurantPartner.user_id == maybe_uuid,
                        RestaurantPartner.id == maybe_uuid,
                    )
                )
            )
            if partner:
                restaurant = await db.scalar(select(Restaurant).where(Restaurant.id == partner.restaurant_id))
    else:
        phones = {value, strip_plus91(value), add_plus91(value)}
        phones.discard("")
        restaurant = await db.scalar(select(Restaurant).where(Restaurant.phone.in_(phones)))

    if not restaurant:
        raise HTTPException(status_code=404, detail="Restaurant not found")
    return restaurant


async def _resolve_restaurant_id(db: AsyncSession, identifier: str | uuid.UUID) -> uuid.UUID:
    return (await _resolve_restaurant(db, identifier)).id


def _enum_value(value: Any) -> str:
    return value.value if hasattr(value, "value") else str(value)


def _dt(value: Any) -> str | None:
    return value.isoformat() if value else None


def _redis_text(value: Any) -> str | None:
    if value is None:
        return None
    if isinstance(value, bytes):
        return value.decode()
    return str(value)


def _local_ip() -> str:
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        sock.connect(("8.8.8.8", 80))
        ip = sock.getsockname()[0]
        sock.close()
        return ip
    except Exception:
        return "127.0.0.1"


async def _current_partner(db: AsyncSession, user: User) -> DeliveryPartner:
    partner = await db.scalar(select(DeliveryPartner).where(DeliveryPartner.user_id == user.id))
    if not partner:
        raise HTTPException(status_code=404, detail="Delivery partner profile not found")
    return partner


async def _current_restaurant_partner(db: AsyncSession, user: User) -> RestaurantPartner:
    partner = await db.scalar(select(RestaurantPartner).where(RestaurantPartner.user_id == user.id))
    if not partner:
        raise HTTPException(status_code=404, detail="Restaurant partner profile not found")
    return partner


def _require_role(user: User, *roles: str) -> None:
    if user.role not in roles:
        raise HTTPException(status_code=403, detail=f"Requires one of roles: {', '.join(roles)}")


async def _get_delivery_otp_for_order(db: AsyncSession, order_id: uuid.UUID) -> DeliveryOtp | None:
    return await db.scalar(
        select(DeliveryOtp)
        .join(DeliveryAssignment, DeliveryAssignment.id == DeliveryOtp.assignment_id)
        .where(DeliveryAssignment.order_id == order_id)
    )


async def _get_assignment_for_order(db: AsyncSession, order_id: uuid.UUID) -> DeliveryAssignment | None:
    return await db.scalar(select(DeliveryAssignment).where(DeliveryAssignment.order_id == order_id))


async def _load_order(db: AsyncSession, order_id: uuid.UUID) -> Order:
    order = await db.scalar(
        select(Order)
        .options(selectinload(Order.items), selectinload(Order.restaurant))
        .where(Order.id == order_id)
    )
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")
    return order


async def _order_flutter(db: AsyncSession, order: Order) -> dict:
    otp = await _get_delivery_otp_for_order(db, order.id)
    assignment = await _get_assignment_for_order(db, order.id)
    order_items = list(order.items or [])
    if not order_items:
        rows = await db.scalars(select(OrderItem).where(OrderItem.order_id == order.id))
        order_items = rows.all()
    return map_order_to_flutter(order, order_items, otp, assignment)


async def _restaurant_docs(db: AsyncSession, partner_id: uuid.UUID | None) -> dict[str, str]:
    if not partner_id:
        return {}
    rows = await db.scalars(select(RestaurantDocument).where(RestaurantDocument.partner_id == partner_id))
    docs = {}
    for doc in rows.all():
        docs[_enum_value(doc.doc_type)] = doc.file_url
    return docs


async def _restaurant_flutter(db: AsyncSession, restaurant: Restaurant) -> dict:
    partner = await db.scalar(select(RestaurantPartner).where(RestaurantPartner.restaurant_id == restaurant.id))
    user = None
    if partner:
        user = await db.scalar(select(User).where(User.id == partner.user_id))
    docs = await _restaurant_docs(db, partner.id if partner else None)
    return {
        "id": str(restaurant.id),
        "shopName": restaurant.name,
        "ownerName": partner.owner_name if partner else "",
        "phone": strip_plus91(restaurant.phone),
        "email": user.email if user and user.email else "",
        "town": restaurant.city,
        "address": restaurant.full_address,
        "cuisineType": ", ".join(restaurant.cuisine_types or []),
        "fssaiNumber": partner.fssai_number if partner else "",
        "upiId": "",
        "status": map_restaurant_status_to_flutter(user.restaurant_status if user else None),
        "fssaiPhotoUrl": docs.get("FSSAI_LICENSE", ""),
        "kitchenPhotoUrl": docs.get("RESTAURANT_PHOTO_INTERIOR", ""),
        "signboardPhotoUrl": docs.get("RESTAURANT_PHOTO_FRONT", ""),
        "restaurantImageUrl": restaurant.image_url or "",
        "isOpen": restaurant.is_open,
        "rating": float(restaurant.rating or 0),
        "totalRatings": int(restaurant.total_reviews or 0),
        "deliveryFee": float(restaurant.delivery_fee or 0),
        "minOrderAmount": float(restaurant.min_order_amount or 0),
        "avgDeliveryTime": restaurant.avg_delivery_time,
    }


def _menu_item_flutter(item: MenuItem, category_name: str | None = None) -> dict:
    tags = item.tags or []
    return {
        "id": str(item.id),
        "restaurantId": str(item.restaurant_id),
        "name": item.name,
        "description": item.description or "",
        "price": float(item.effective_price),
        "originalPrice": float(item.price),
        "category": category_name or (item.category.name if getattr(item, "category", None) else ""),
        "available": item.is_available,
        "imageUrl": item.image_url or "",
        "isSpecial": "Bestseller" in tags,
        "preparationTime": item.preparation_time or 15,
        "isVeg": item.is_veg,
    }


async def _find_or_create_category(db: AsyncSession, restaurant_id: uuid.UUID, name: str) -> MenuCategory:
    category = await db.scalar(
        select(MenuCategory).where(
            MenuCategory.restaurant_id == restaurant_id,
            func.lower(MenuCategory.name) == name.lower(),
            MenuCategory.is_active == True,
        )
    )
    if category:
        return category
    category = MenuCategory(restaurant_id=restaurant_id, name=name, display_order=0, is_active=True)
    db.add(category)
    await db.flush()
    return category


def _user_flutter(user: User) -> dict:
    return {
        "uid": str(user.id),
        "name": user.name,
        "phone": strip_plus91(user.phone),
        "role": map_role_to_flutter(user.role),
        "town": getattr(user, "city", None),
        "status": "active" if user.is_active else "inactive",
        "createdAt": _dt(user.created_at),
        "kycStatus": map_kyc_status_to_flutter(user.partner_status),
        "restaurantStatus": map_restaurant_status_to_flutter(user.restaurant_status),
    }


def _cart_flutter(cart_response: Any) -> dict:
    if hasattr(cart_response, "model_dump"):
        payload = cart_response.model_dump(mode="json")
    else:
        payload = cart_response
    data = payload.get("data", payload)
    return {
        "restaurant": data.get("restaurant"),
        "items": data.get("items", []),
        "subtotal": data.get("cart_subtotal", data.get("items_total", 0)),
        "delivery_fee": data.get("delivery_fee", 0),
        "grand_total": data.get("grand_total", 0),
        "item_count": data.get("item_count", 0),
    }


def _address_flutter(address: Address) -> dict:
    return {
        "id": str(address.id),
        "label": _enum_value(address.label),
        "full_address": address.full_address,
        "landmark": address.landmark,
        "latitude": float(address.latitude) if address.latitude is not None else None,
        "longitude": float(address.longitude) if address.longitude is not None else None,
        "lat": float(address.latitude) if address.latitude is not None else None,
        "lng": float(address.longitude) if address.longitude is not None else None,
        "is_default": address.is_default,
        "flat_number": "",
        "contact_name": "",
        "contact_phone": "",
    }


@router.get("/config")
async def config() -> dict:
    ip = _local_ip()
    return {
        "apiBase": f"http://{ip}:8000/api/flutter/v1",
        "wsBase": f"ws://{ip}:8000/api/v1/ws",
        "uploadBase": f"http://{ip}:8000/uploads",
        "version": "1.0.0",
        "environment": "development",
    }


@router.post("/auth/send-otp")
async def send_otp(body: SendOtpBody, redis=Depends(redis_dep)) -> dict:
    phone = add_plus91(body.phone)
    await otp_utils.send_otp(redis, SendOTPRequest(phone=phone).phone)
    return {"success": True, "message": "OTP sent"}


@router.post("/auth/verify-otp")
async def verify_otp(body: VerifyOtpBody, db: AsyncSession = Depends(get_db), redis=Depends(redis_dep)) -> dict:
    phone = add_plus91(body.phone)
    role = body.role.lower()
    if role == "admin" and phone != get_settings().ADMIN_PHONE:
        raise HTTPException(status_code=403, detail="Admin login is restricted")
    request = VerifyOTPRequest(
        phone=phone,
        otp=body.otp,
        register_as_partner=role == "agent",
        register_as_restaurant=role == "restaurant",
    )
    await otp_utils.verify_otp(redis, request.phone, request.otp)
    response = await AuthService(db, redis).login_with_otp(
        phone=request.phone,
        register_as_partner=request.register_as_partner,
        register_as_restaurant=request.register_as_restaurant,
    )
    user = await db.scalar(select(User).where(User.id == response.user.id))
    if not user:
        raise HTTPException(status_code=404, detail="User not found after login")
    if body.name and response.is_new_user:
        user.name = body.name
    if body.town and hasattr(user, "city"):
        user.city = body.town
    if role in {"customer", "restaurant", "agent", "admin"}:
        user.role = map_role_to_backend(role)
        if role == "restaurant" and not user.restaurant_status:
            user.restaurant_status = "PENDING_DOCS"
        if role == "agent" and not user.partner_status:
            user.partner_status = "PENDING_KYC"
    await db.flush()
    return {
        "uid": str(user.id),
        "token": response.access_token,
        "refreshToken": response.refresh_token,
        "user": {
            "uid": str(user.id),
            "name": user.name,
            "phone": strip_plus91(user.phone),
            "role": map_role_to_flutter(user.role),
            "town": body.town,
            "status": "active",
            "kycStatus": map_kyc_status_to_flutter(user.partner_status),
            "restaurantStatus": map_restaurant_status_to_flutter(user.restaurant_status),
            "createdAt": _dt(user.created_at),
        },
        "isNewUser": response.is_new_user,
    }


@router.post("/auth/refresh")
async def refresh_token(body: RefreshBody, db: AsyncSession = Depends(get_db), redis=Depends(redis_dep)) -> dict:
    response = await AuthService(db, redis).refresh_tokens(body.refresh_token)
    return {
        "token": response.access_token,
        "refreshToken": response.refresh_token,
        "access_token": response.access_token,
        "refresh_token": response.refresh_token,
        "token_type": response.token_type,
    }


@router.post("/auth/logout")
async def logout(
    body: LogoutBody,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
    redis=Depends(redis_dep),
) -> dict:
    await AuthService(db, redis).logout(current_user.id)
    return {"success": True}


@router.get("/users/me")
async def get_me(current_user: User = Depends(get_current_user)) -> dict:
    return _user_flutter(current_user)


@router.patch("/users/me")
async def patch_me(
    body: UserPatchBody,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    if body.name is not None:
        current_user.name = body.name
    if body.email is not None:
        current_user.email = body.email
    if body.profile_picture is not None:
        current_user.profile_picture = body.profile_picture
    await db.flush()
    return _user_flutter(current_user)


@router.post("/notifications/register")
async def register_notification(
    body: NotificationRegisterBody,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    current_user.fcm_token = body.fcm_token
    await db.flush()
    return {"registered": True}


@router.get("/users/{uid}")
async def get_user(uid: str, current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)) -> dict:
    user = await db.scalar(select(User).where(User.id == _as_uuid(uid)))
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return _user_flutter(user)


@router.get("/restaurants")
async def restaurants(town: str, status: str = "active", db: AsyncSession = Depends(get_db)) -> dict:
    query = select(Restaurant).where(Restaurant.city.ilike(f"%{town}%"))
    if status == "active":
        query = query.where(Restaurant.is_open == True)
    rows = await db.scalars(query.order_by(Restaurant.rating.desc()))
    return {"restaurants": [await _restaurant_flutter(db, r) for r in rows.all()]}


@router.get("/restaurants/{restaurant_id}")
async def restaurant_detail(restaurant_id: str, db: AsyncSession = Depends(get_db)) -> dict:
    restaurant = await _resolve_restaurant(db, restaurant_id)
    return await _restaurant_flutter(db, restaurant)


@router.post("/restaurants")
async def create_restaurant(
    body: RestaurantCreateBody,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    _require_role(current_user, "RESTAURANT_PARTNER")
    setup = RestaurantSetupRequest(
        restaurant_name=body.shopName,
        business_type=BusinessType.RESTAURANT.value,
        cuisine_types=body.cuisineTypes or [body.cuisineType],
        city=body.town,
        full_address=body.address,
        phone=add_plus91(body.phone) or body.phone,
        owner_name=body.ownerName,
        fssai_number=(body.fssaiNumber if len(body.fssaiNumber) == 14 and body.fssaiNumber.isdigit() else "12345678901234"),
        fssai_expiry=datetime.now(UTC).date() + timedelta(days=365),
        pan_number="ABCDE1234F",
        bank_account_number="0000000000",
        bank_ifsc="HDFC0001234",
        bank_account_name=body.ownerName,
        min_order_amount=0,
        avg_delivery_time=45,
        delivery_fee=30,
    )
    result = await RestaurantPartnerService(db).setup_restaurant(current_user.id, setup)
    current_user.restaurant_status = "DOCS_SUBMITTED"
    restaurant = await db.scalar(select(Restaurant).where(Restaurant.id == result["restaurant_id"]))
    if restaurant and body.restaurantImageUrl:
        restaurant.image_url = body.restaurantImageUrl
    await db.commit()
    if restaurant:
        await db.refresh(restaurant)
    return await _restaurant_flutter(db, restaurant)


@router.put("/restaurants/{restaurant_id}/status")
async def update_restaurant_status(
    restaurant_id: str,
    body: StatusBody,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    _require_role(current_user, "ADMIN")
    rid = await _resolve_restaurant_id(db, restaurant_id)
    partner = await db.scalar(select(RestaurantPartner).where(RestaurantPartner.restaurant_id == rid))
    if not partner:
        raise HTTPException(status_code=404, detail="Restaurant partner not found")
    user = await db.scalar(select(User).where(User.id == partner.user_id))
    restaurant = await db.scalar(select(Restaurant).where(Restaurant.id == partner.restaurant_id))
    if body.status == "active":
        user.restaurant_status = "DOCS_APPROVED"
        restaurant.is_open = True
    elif body.status == "rejected":
        user.restaurant_status = "DOCS_REJECTED"
        restaurant.is_open = False
    else:
        raise HTTPException(status_code=400, detail="Unsupported status")
    await db.flush()
    return await _restaurant_flutter(db, restaurant)


@router.put("/restaurants/{restaurant_id}/online-status")
async def restaurant_online_status(
    restaurant_id: str,
    body: OnlineRestaurantBody,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    _require_role(current_user, "RESTAURANT_PARTNER")
    partner = await _current_restaurant_partner(db, current_user)
    rid = await _resolve_restaurant_id(db, restaurant_id)
    if partner.restaurant_id != rid:
        raise HTTPException(status_code=403, detail="Not your restaurant")
    result = await RestaurantPartnerService(db).toggle_open_status(current_user.id, body.isOpen)
    return {"isOpen": result["is_open"], "message": result["message"]}


@router.get("/restaurants/{restaurant_id}/orders")
async def restaurant_orders(
    restaurant_id: str,
    status: str | None = None,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    rid = await _resolve_restaurant_id(db, restaurant_id)
    query = (
        select(Order)
        .options(selectinload(Order.items), selectinload(Order.restaurant))
        .where(Order.restaurant_id == rid)
        .order_by(Order.created_at.desc())
    )
    if status:
        query = query.where(Order.status == map_order_status_to_backend(status))
    rows = await db.scalars(query)
    return {"orders": [await _order_flutter(db, order) for order in rows.all()]}


@router.get("/restaurants/{restaurant_id}/menu")
async def get_menu(restaurant_id: str, db: AsyncSession = Depends(get_db)) -> dict:
    rid = await _resolve_restaurant_id(db, restaurant_id)
    rows = await db.scalars(
        select(MenuItem)
        .options(selectinload(MenuItem.category))
        .where(MenuItem.restaurant_id == rid)
        .order_by(MenuItem.name.asc())
    )
    items = [item for item in rows.all() if not (item.tags and "_deleted" in item.tags)]
    return {"menu": [_menu_item_flutter(item) for item in items]}


@router.post("/restaurants/{restaurant_id}/menu")
async def create_menu_item(
    restaurant_id: str,
    body: MenuCreateBody,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    _require_role(current_user, "RESTAURANT_PARTNER")
    partner = await _current_restaurant_partner(db, current_user)
    rid = await _resolve_restaurant_id(db, restaurant_id)
    if partner.restaurant_id != rid:
        raise HTTPException(status_code=403, detail="Not your restaurant")
    category = await _find_or_create_category(db, rid, body.category)
    tags = ["Bestseller"] if body.isSpecial else []
    data = {
        "category_id": category.id,
        "name": body.name,
        "description": body.description,
        "price": body.price,
        "discounted_price": None,
        "image_url": body.imageUrl,
        "is_veg": body.isVeg,
        "is_available": body.available,
        "preparation_time": body.preparationTime,
        "tags": tags,
    }
    created = await MenuManagementService(db).create_item(rid, partner.id, data)
    item = await db.scalar(select(MenuItem).options(selectinload(MenuItem.category)).where(MenuItem.id == created["id"]))
    return _menu_item_flutter(item)


@router.put("/restaurants/{restaurant_id}/menu/{item_id}")
async def update_menu_item(
    restaurant_id: str,
    item_id: str,
    body: MenuUpdateBody,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    _require_role(current_user, "RESTAURANT_PARTNER")
    partner = await _current_restaurant_partner(db, current_user)
    rid = await _resolve_restaurant_id(db, restaurant_id)
    if partner.restaurant_id != rid:
        raise HTTPException(status_code=403, detail="Not your restaurant")
    data = {
        "is_available": body.available,
        "price": body.price,
        "name": body.name,
        "description": body.description,
        "image_url": body.imageUrl,
        "preparation_time": body.preparationTime,
    }
    await MenuManagementService(db).update_item(_as_uuid(item_id), partner.id, data)
    item = await db.scalar(select(MenuItem).options(selectinload(MenuItem.category)).where(MenuItem.id == _as_uuid(item_id)))
    return _menu_item_flutter(item)


@router.delete("/restaurants/{restaurant_id}/menu/{item_id}")
async def delete_menu_item(
    restaurant_id: str,
    item_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    _require_role(current_user, "RESTAURANT_PARTNER")
    partner = await _current_restaurant_partner(db, current_user)
    rid = await _resolve_restaurant_id(db, restaurant_id)
    if partner.restaurant_id != rid:
        raise HTTPException(status_code=403, detail="Not your restaurant")
    await MenuManagementService(db).delete_item(_as_uuid(item_id), partner.id)
    return {"success": True}


@router.get("/cart")
async def get_cart(current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)) -> dict:
    return _cart_flutter(await CartService(db).get_cart(current_user.id))


@router.post("/cart/add", response_model=None)
async def add_cart_item(
    body: CartItemBody,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict | JSONResponse:
    try:
        cart = await CartService(db).add_item(
            current_user.id,
            AddToCartRequest(menu_item_id=body.menu_item_id, quantity=body.quantity),
        )
        return _cart_flutter(cart)
    except CartConflictError as e:
        return JSONResponse(status_code=409, content=e.response.model_dump(mode="json"))
    except ItemUnavailableError:
        return JSONResponse(status_code=409, content={"error_code": "ITEM_UNAVAILABLE", "message": "Item unavailable"})


@router.post("/cart/update-quantity")
async def update_cart_quantity(
    body: CartItemBody,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    cart = await CartService(db).update_quantity(
        current_user.id,
        UpdateQuantityRequest(menu_item_id=body.menu_item_id, quantity=body.quantity),
    )
    return _cart_flutter(cart)


@router.post("/cart/clear")
async def clear_cart(current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)) -> dict:
    return _cart_flutter(await CartService(db).clear_cart(current_user.id))


@router.post("/cart/validate")
async def validate_cart(current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)) -> dict:
    rows = await db.scalars(
        select(CartItem)
        .options(selectinload(CartItem.menu_item), selectinload(CartItem.restaurant))
        .where(CartItem.user_id == current_user.id)
    )
    items = rows.all()
    invalid = [
        {"menu_item_id": str(item.menu_item_id), "name": item.menu_item.name}
        for item in items
        if not item.menu_item.is_available
    ]
    restaurant_is_open = all(item.restaurant.is_open for item in items)
    return {
        "is_valid": not invalid and restaurant_is_open,
        "invalid_items": invalid,
        "restaurant_is_open": restaurant_is_open,
    }


@router.get("/addresses")
async def get_addresses(current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)) -> dict:
    rows = await db.scalars(
        select(Address).where(Address.user_id == current_user.id).order_by(Address.is_default.desc(), Address.created_at.desc())
    )
    return {"addresses": [_address_flutter(address) for address in rows.all()]}


@router.post("/addresses")
async def create_address(
    body: FlutterAddressBody,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    address = await AddressService(db).create_address(
        current_user.id,
        CreateAddressRequest(
            label=body.label,
            full_address=body.full_address,
            landmark=body.landmark,
            latitude=body.latitude,
            longitude=body.longitude,
            is_default=body.is_default,
        ),
    )
    return _address_flutter(await db.scalar(select(Address).where(Address.id == address.id)))


@router.patch("/addresses/{address_id}/set-default")
async def set_default_address(
    address_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    address = await AddressService(db).set_default(current_user.id, _as_uuid(address_id))
    return _address_flutter(await db.scalar(select(Address).where(Address.id == address.id)))


@router.delete("/addresses/{address_id}")
async def delete_address(
    address_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    await AddressService(db).delete_address(current_user.id, _as_uuid(address_id))
    return {"deleted": True}


@router.post("/orders")
async def create_order(
    body: FlutterPlaceOrderBody,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    _require_role(current_user, "CUSTOMER", "ADMIN")
    if body.items is not None and body.restaurantId is not None:
        await _resolve_restaurant_id(db, body.restaurantId)
        await db.execute(delete(CartItem).where(CartItem.user_id == current_user.id))
        cart_service = CartService(db)
        for item in body.items:
            await cart_service.add_item(
                current_user.id,
                AddToCartRequest(menu_item_id=_as_uuid(item.itemId), quantity=item.quantity),
            )

    address = None
    if body.delivery_address_id:
        address = await db.scalar(
            select(Address).where(
                Address.id == body.delivery_address_id,
                Address.user_id == current_user.id,
            )
        )
    if not address:
        address = await db.scalar(select(Address).where(Address.user_id == current_user.id, Address.is_default == True))
    if not address and body.landmark:
        address = Address(
            user_id=current_user.id,
            label=AddressLabel.OTHER,
            full_address=body.landmark,
            landmark=body.landmark,
            latitude=body.latitude,
            longitude=body.longitude,
            is_default=True,
        )
        db.add(address)
        await db.flush()
    if not address:
        raise HTTPException(status_code=400, detail="Delivery address required")

    payment_raw = (body.payment_method or body.paymentMethod or "cash").lower()
    payment = PaymentMethod.UPI if payment_raw == "upi" else PaymentMethod.COD
    try:
        placed_orders = await OrderService(db).place_orders_for_cart(
            current_user.id,
            PlaceOrderRequest(
                delivery_address_id=address.id,
                payment_method=payment,
                coupon_code=body.coupon_code,
            ),
        )
    except OrderServiceError as e:
        return JSONResponse(status_code=e.status_code, content=e.body)
    orders = [await _load_order(db, placed.id) for placed in placed_orders]
    flutter_orders = [await _order_flutter(db, order) for order in orders]
    first = flutter_orders[0]
    return {
        "orderId": str(orders[0].id),
        "customerId": str(current_user.id),
        "orders": flutter_orders,
        **first,
    }


@router.get("/orders/{order_id}")
async def get_order(order_id: str, current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)) -> dict:
    order = await _load_order(db, _as_uuid(order_id))
    if current_user.role == "CUSTOMER" and order.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not your order")
    return await _order_flutter(db, order)


@router.post("/orders/{order_id}/cancel", response_model=None)
async def cancel_order(
    order_id: str,
    body: dict[str, str],
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict | JSONResponse:
    try:
        cancelled = await OrderService(db).cancel_order(
            current_user.id,
            _as_uuid(order_id),
            CancelOrderRequest(reason=body.get("reason", "Cancelled by customer")),
        )
    except OrderServiceError as e:
        return JSONResponse(status_code=e.status_code, content=e.body)
    return await _order_flutter(db, await _load_order(db, cancelled.id))


@router.get("/orders")
async def list_orders(
    customerId: str | None = None,
    restaurantId: str | None = None,
    town: str | None = None,
    status: str | None = None,
    agentId: str | None = None,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    query = select(Order).options(selectinload(Order.items), selectinload(Order.restaurant))
    if customerId:
        query = query.where(Order.user_id == _as_uuid(customerId))
    elif current_user.role == "CUSTOMER":
        query = query.where(Order.user_id == current_user.id)
    if restaurantId:
        query = query.where(Order.restaurant_id == await _resolve_restaurant_id(db, restaurantId))
    if town:
        query = query.join(Restaurant).where(Restaurant.city.ilike(f"%{town}%"))
    if status:
        query = query.where(Order.status == map_order_status_to_backend(status))
    if agentId == "null" and status == "pickup_ready":
        query = query.outerjoin(DeliveryAssignment, DeliveryAssignment.order_id == Order.id).where(
            or_(DeliveryAssignment.id.is_(None), DeliveryAssignment.status != AssignmentStatus.ACCEPTED)
        )
    elif agentId:
        query = query.join(DeliveryAssignment, DeliveryAssignment.order_id == Order.id).where(
            DeliveryAssignment.partner_id == _as_uuid(agentId)
        )
    rows = await db.scalars(query.order_by(Order.created_at.desc()))
    return {"orders": [await _order_flutter(db, order) for order in rows.unique().all()]}


@router.put("/orders/{order_id}/status")
async def update_order_status(
    order_id: str,
    body: OrderStatusBody,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
    redis=Depends(redis_dep),
) -> dict:
    _require_role(current_user, "RESTAURANT_PARTNER")
    partner = await _current_restaurant_partner(db, current_user)
    svc = OrderManagementService(db)
    if body.status == "preparing":
        result = await svc.accept_order(_as_uuid(order_id), partner.restaurant_id, 20, redis)
    elif body.status == "pickup_ready":
        order = await _load_order(db, _as_uuid(order_id))
        if _enum_value(order.status) == "CONFIRMED":
            await svc.mark_preparing(order.id, partner.restaurant_id)
        result = await svc.mark_ready(order.id, partner.restaurant_id)
    else:
        raise HTTPException(status_code=400, detail="Unsupported status")
    order = await _load_order(db, _as_uuid(result["id"]))
    return await _order_flutter(db, order)


@router.post("/restaurant/orders/{order_id}/accept")
async def flutter_accept_order(
    order_id: uuid.UUID,
    body: dict[str, Any],
    partner: RestaurantPartner = Depends(require_restaurant_partner),
    db: AsyncSession = Depends(get_db),
    redis=Depends(redis_dep),
) -> dict:
    prep_time = int(body.get("preparation_time") or body.get("preparationTime") or 20)
    result = await OrderManagementService(db).accept_order(
        order_id,
        partner.restaurant_id,
        prep_time,
        redis,
    )
    order = await _load_order(db, _as_uuid(result["id"]))
    return await _order_flutter(db, order)


@router.post("/restaurant/orders/{order_id}/preparing")
async def flutter_mark_order_preparing(
    order_id: uuid.UUID,
    body: dict[str, Any] | None = None,
    partner: RestaurantPartner = Depends(require_restaurant_partner),
    db: AsyncSession = Depends(get_db),
) -> dict:
    result = await OrderManagementService(db).mark_preparing(order_id, partner.restaurant_id)
    order = await _load_order(db, _as_uuid(result["id"]))
    return await _order_flutter(db, order)


@router.post("/restaurant/orders/{order_id}/ready")
async def flutter_mark_order_ready(
    order_id: uuid.UUID,
    body: dict[str, Any] | None = None,
    partner: RestaurantPartner = Depends(require_restaurant_partner),
    db: AsyncSession = Depends(get_db),
) -> dict:
    result = await OrderManagementService(db).mark_ready(order_id, partner.restaurant_id)
    order = await _load_order(db, _as_uuid(result["id"]))
    return await _order_flutter(db, order)


@router.post("/restaurant/orders/{order_id}/reject")
async def flutter_reject_order(
    order_id: uuid.UUID,
    body: dict[str, Any],
    partner: RestaurantPartner = Depends(require_restaurant_partner),
    db: AsyncSession = Depends(get_db),
) -> dict:
    reason = str(body.get("reason") or body.get("rejectionReason") or "Rejected")
    description = str(body.get("description") or "")
    result = await OrderManagementService(db).reject_order(
        order_id,
        partner.restaurant_id,
        reason,
        description,
    )
    order = await _load_order(db, _as_uuid(result["id"]))
    return await _order_flutter(db, order)


@router.put("/orders/{order_id}/agent")
async def accept_order_agent(
    order_id: str,
    body: OrderAgentBody,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
    redis=Depends(redis_dep),
) -> dict:
    _require_role(current_user, "DELIVERY_PARTNER")
    partner = await _current_partner(db, current_user)
    assignment = await _get_assignment_for_order(db, _as_uuid(order_id))
    if not assignment:
        raise HTTPException(status_code=404, detail="Assignment not found")
    result = await AssignmentService(db, redis).accept_assignment(assignment.id, partner)
    if "status_code" in result:
        raise HTTPException(status_code=result["status_code"], detail=result)
    order = await _load_order(db, _as_uuid(order_id))
    return await _order_flutter(db, order)


@router.put("/orders/{order_id}/complete")
async def complete_order(
    order_id: str,
    body: CompleteOrderBody,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
    redis=Depends(redis_dep),
) -> dict:
    _require_role(current_user, "DELIVERY_PARTNER")
    partner = await _current_partner(db, current_user)
    assignment = await _get_assignment_for_order(db, _as_uuid(order_id))
    if not assignment:
        raise HTTPException(status_code=404, detail="Assignment not found")
    result = await AssignmentService(db, redis).deliver(assignment.id, partner, body.deliveredOtp)
    if "status_code" in result:
        raise HTTPException(status_code=result["status_code"], detail=result)
    earnings = result.get("earnings", {})
    return {
        "orderId": order_id,
        "status": "delivered",
        "earnedAmount": earnings.get("total_earned", 0),
        "totalEarnings": float(partner.total_earnings or partner.wallet_balance or 0),
        "message": "Delivery completed successfully",
    }


@router.post("/reviews", response_model=None)
async def create_review(
    body: CreateReviewRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict | JSONResponse:
    try:
        review = await ReviewService(db).create_review(current_user.id, body)
        return review.model_dump(mode="json")
    except OrderServiceError as e:
        return JSONResponse(status_code=e.status_code, content=e.body)


@router.post("/agents/kyc")
async def submit_agent_kyc(
    body: AgentKycBody,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    _require_role(current_user, "DELIVERY_PARTNER")
    partner = await _current_partner(db, current_user)
    current_user.name = body.step1.get("fullName") or current_user.name
    partner.city = body.step1.get("address") or partner.city or ""
    vehicle_type = (body.step3.get("vehicleType") or "").upper().replace("BICYCLE", "CYCLE")
    if vehicle_type:
        partner.vehicle_type = vehicle_type
    partner.vehicle_number = body.step3.get("registrationNumber") or partner.vehicle_number
    doc_map = {
        "aadhaarPhotoUrl": KycDocType.AADHAAR_FRONT,
        "rcPhotoUrl": KycDocType.VEHICLE_RC,
        "insurancePhotoUrl": KycDocType.VEHICLE_INSURANCE,
    }
    for key, doc_type in doc_map.items():
        url = body.step2.get(key) or body.step3.get(key)
        if not url:
            continue
        doc = await db.scalar(select(KycDocument).where(KycDocument.partner_id == partner.id, KycDocument.doc_type == doc_type))
        if not doc:
            db.add(KycDocument(partner_id=partner.id, doc_type=doc_type, file_url=url, file_name=Path(url).name, status=KycDocStatus.PENDING))
        else:
            doc.file_url = url
            doc.status = KycDocStatus.PENDING
            doc.rejection_reason = None
    current_user.partner_status = "KYC_SUBMITTED"
    await db.flush()
    return {
        "agentId": str(current_user.id),
        "status": "pending",
        "submittedAt": datetime.now(UTC).isoformat(),
        "message": "KYC submitted for verification",
    }


@router.get("/agents/{agent_id}/kyc-status")
async def agent_kyc_status(agent_id: str, current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)) -> dict:
    user = await db.scalar(select(User).where(User.id == _as_uuid(agent_id)))
    if not user:
        raise HTTPException(status_code=404, detail="Agent not found")
    partner = await db.scalar(select(DeliveryPartner).where(DeliveryPartner.user_id == user.id))
    reason = None
    if partner:
        rejected = await db.scalar(select(KycDocument).where(KycDocument.partner_id == partner.id, KycDocument.status == KycDocStatus.REJECTED))
        reason = rejected.rejection_reason if rejected else None
    return {"agentId": agent_id, "status": map_kyc_status_to_flutter(user.partner_status), "rejectionReason": reason}


@router.put("/agents/{agent_id}/kyc-status")
async def update_agent_kyc_status(
    agent_id: str,
    body: StatusBody,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    _require_role(current_user, "ADMIN")
    user = await db.scalar(select(User).where(User.id == _as_uuid(agent_id)))
    if not user:
        raise HTTPException(status_code=404, detail="Agent not found")
    user.partner_status = "KYC_APPROVED" if body.status == "approved" else "KYC_REJECTED"
    if body.status == "rejected":
        partner = await db.scalar(select(DeliveryPartner).where(DeliveryPartner.user_id == user.id))
        if partner:
            doc = await db.scalar(select(KycDocument).where(KycDocument.partner_id == partner.id))
            if doc:
                doc.status = KycDocStatus.REJECTED
                doc.rejection_reason = body.rejectionReason
    await db.flush()
    return {"status": map_kyc_status_to_flutter(user.partner_status)}


@router.put("/agents/{agent_id}/online-status")
async def agent_online_status(
    agent_id: str,
    body: AgentOnlineBody,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    _require_role(current_user, "DELIVERY_PARTNER")
    partner = await _current_partner(db, current_user)
    partner.is_online = body.isOnline
    if body.latitude is not None:
        partner.current_latitude = body.latitude
    if body.longitude is not None:
        partner.current_longitude = body.longitude
    partner.last_location_at = datetime.now(UTC)
    await db.flush()
    return {"isOnline": body.isOnline, "status": "ONLINE" if body.isOnline else "OFFLINE"}


@router.post("/partner/duty/start")
async def flutter_start_duty(
    body: DutyStartBody,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    _require_role(current_user, "DELIVERY_PARTNER")
    if current_user.partner_status != "KYC_APPROVED":
        raise HTTPException(
            status_code=403,
            detail={
                "error_code": "KYC_NOT_APPROVED",
                "message": f"Your account is under verification. Status: {current_user.partner_status}",
                "partner_status": current_user.partner_status,
            },
        )
    partner = await _current_partner(db, current_user)
    if partner.is_online:
        raise HTTPException(
            status_code=409,
            detail={"error_code": "ALREADY_ONLINE", "message": "You are already online"},
        )

    partner.is_online = True
    partner.current_latitude = body.latitude
    partner.current_longitude = body.longitude
    partner.last_location_at = datetime.now(UTC)

    shift = PartnerShift(partner_id=partner.id, city=partner.city or "")
    db.add(shift)
    await db.flush()
    await db.refresh(shift)

    return {
        "isOnline": True,
        "status": "ONLINE",
        "shiftId": str(shift.id),
        "startedAt": _dt(shift.started_at),
        "message": "You are now online and can receive orders",
    }


@router.post("/partner/duty/stop")
async def flutter_stop_duty(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    _require_role(current_user, "DELIVERY_PARTNER")
    partner = await _current_partner(db, current_user)
    if not partner.is_online:
        raise HTTPException(
            status_code=409,
            detail={"error_code": "ALREADY_OFFLINE", "message": "You are already offline"},
        )

    active_statuses = [
        AssignmentStatus.ASSIGNED,
        AssignmentStatus.ACCEPTED,
        AssignmentStatus.PICKED_UP,
        AssignmentStatus.REACHED_RESTAURANT,
        AssignmentStatus.REACHED_CUSTOMER,
    ]
    active_assignment = await db.scalar(
        select(DeliveryAssignment).where(
            DeliveryAssignment.partner_id == partner.id,
            DeliveryAssignment.status.in_(active_statuses),
        )
    )
    if active_assignment:
        raise HTTPException(
            status_code=409,
            detail={
                "error_code": "ACTIVE_DELIVERY_IN_PROGRESS",
                "message": "Cannot go offline during an active delivery",
                "assignment_id": str(active_assignment.id),
            },
        )

    partner.is_online = False
    active_shift = await db.scalar(
        select(PartnerShift)
        .where(PartnerShift.partner_id == partner.id, PartnerShift.ended_at.is_(None))
        .order_by(PartnerShift.started_at.desc())
    )
    shift_summary = {
        "durationMinutes": 0,
        "deliveriesCompleted": 0,
        "earnings": 0.0,
        "startedAt": None,
        "endedAt": None,
    }
    if active_shift:
        now = datetime.now(UTC)
        active_shift.ended_at = now
        started = active_shift.started_at
        if started.tzinfo is None:
            started = started.replace(tzinfo=UTC)
        duration_minutes = int((now - started).total_seconds() / 60)
        active_shift.duration_minutes = duration_minutes
        earnings_sum = await db.scalar(
            select(func.coalesce(func.sum(PartnerEarnings.total_earned), 0)).where(
                PartnerEarnings.partner_id == partner.id,
                PartnerEarnings.earned_at >= active_shift.started_at,
            )
        )
        active_shift.earnings_in_shift = float(earnings_sum or 0)
        shift_summary = {
            "durationMinutes": duration_minutes,
            "deliveriesCompleted": active_shift.deliveries_in_shift,
            "earnings": float(active_shift.earnings_in_shift or 0),
            "startedAt": _dt(active_shift.started_at),
            "endedAt": now.isoformat(),
        }

    await db.flush()
    return {"isOnline": False, "status": "OFFLINE", "shiftSummary": shift_summary}


@router.get("/partner/duty/status")
async def flutter_duty_status(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    _require_role(current_user, "DELIVERY_PARTNER")
    partner = await _current_partner(db, current_user)
    return {
        "isOnline": partner.is_online,
        "latitude": float(partner.current_latitude) if partner.current_latitude is not None else None,
        "longitude": float(partner.current_longitude) if partner.current_longitude is not None else None,
        "lastLocationAt": _dt(partner.last_location_at),
    }


@router.get("/agents/{agent_id}")
async def get_agent_profile(agent_id: str, current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)) -> dict:
    user = await db.scalar(select(User).where(User.id == _as_uuid(agent_id)))
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    partner = await db.scalar(select(DeliveryPartner).where(DeliveryPartner.user_id == user.id))
    if not partner:
        raise HTTPException(status_code=404, detail="Partner profile not found")
    
    docs = await db.scalars(select(KycDocument).where(KycDocument.partner_id == partner.id))
    doc_map = {_enum_value(doc.doc_type): doc.file_url for doc in docs.all()}

    return {
        "uid": str(user.id),
        "name": user.name,
        "phone": strip_plus91(user.phone),
        "email": user.email or "",
        "city": partner.city,
        "vehicleType": partner.vehicle_type or "",
        "vehicleNumber": partner.vehicle_number or "",
        "feId": partner.fe_id or "",
        "walletBalance": float(partner.wallet_balance or 0),
        "isOnline": partner.is_online,
        "kycStatus": map_kyc_status_to_flutter(user.partner_status),
        "documents": doc_map,
    }


@router.get("/agents/{agent_id}/earnings")
async def agent_earnings(agent_id: str, period: str = "today", current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)) -> dict:
    user = await db.scalar(select(User).where(User.id == _as_uuid(agent_id)))
    partner = await db.scalar(select(DeliveryPartner).where(DeliveryPartner.user_id == user.id)) if user else None
    if not partner:
        raise HTTPException(status_code=404, detail="Partner not found")
    today_start = datetime.now(UTC).replace(hour=0, minute=0, second=0, microsecond=0)
    today_rows = await db.scalars(select(PartnerEarnings).where(PartnerEarnings.partner_id == partner.id, PartnerEarnings.earned_at >= today_start))
    today = today_rows.all()
    total = sum(float(e.total_earned) for e in today)
    deliveries = len(today)
    weekly = []
    for days_back in range(6, -1, -1):
        day_start = today_start - timedelta(days=days_back)
        day_end = day_start + timedelta(days=1)
        rows = await db.scalars(
            select(PartnerEarnings).where(
                PartnerEarnings.partner_id == partner.id,
                PartnerEarnings.earned_at >= day_start,
                PartnerEarnings.earned_at < day_end,
            )
        )
        day_items = rows.all()
        weekly.append({"day": day_start.strftime("%A"), "amount": sum(float(e.total_earned) for e in day_items), "deliveries": len(day_items)})
    return {
        "today": {
            "totalEarnings": total,
            "deliveries": deliveries,
            "averagePerOrder": round(total / deliveries, 2) if deliveries else 0,
            "tips": sum(float(e.tip_amount or 0) for e in today),
        },
        "weekly": weekly,
    }


@router.get("/admin/restaurants/pending")
async def admin_pending_restaurants(current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)) -> dict:
    _require_role(current_user, "ADMIN")
    rows = await db.scalars(
        select(Restaurant)
        .join(RestaurantPartner, RestaurantPartner.restaurant_id == Restaurant.id)
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
    return {"restaurants": [await _restaurant_flutter(db, restaurant) for restaurant in rows.all()]}


@router.put("/admin/restaurants/{restaurant_id}/approve")
async def admin_approve_restaurant(restaurant_id: str, current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)) -> dict:
    return await update_restaurant_status(restaurant_id, StatusBody(status="active"), current_user, db)


@router.put("/admin/restaurants/{restaurant_id}/reject")
async def admin_reject_restaurant(restaurant_id: str, body: StatusBody, current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)) -> dict:
    return await update_restaurant_status(restaurant_id, StatusBody(status="rejected", rejectionReason=body.rejectionReason), current_user, db)


@router.get("/admin/agents/pending")
async def admin_pending_agents(current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)) -> dict:
    _require_role(current_user, "ADMIN")
    partners = await db.scalars(
        select(DeliveryPartner).join(User, User.id == DeliveryPartner.user_id).where(User.partner_status == "KYC_SUBMITTED")
    )
    agents = []
    for partner in partners.all():
        user = await db.scalar(select(User).where(User.id == partner.user_id))
        docs = await db.scalars(select(KycDocument).where(KycDocument.partner_id == partner.id))
        doc_map = {_enum_value(doc.doc_type): doc.file_url for doc in docs.all()}
        agents.append({
            "agentId": str(partner.user_id),
            "name": user.name if user else "",
            "phone": strip_plus91(user.phone if user else ""),
            "vehicleDetails": {"vehicleType": partner.vehicle_type, "registrationNumber": partner.vehicle_number},
            "status": "pending",
            "photoUrls": {
                "aadhaar": doc_map.get("AADHAAR_FRONT", ""),
                "rc": doc_map.get("VEHICLE_RC", ""),
                "insurance": doc_map.get("VEHICLE_INSURANCE", ""),
            },
        })
    return {"agents": agents}


@router.put("/admin/agents/{agent_id}/approve")
async def admin_approve_agent(agent_id: str, current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)) -> dict:
    return await update_agent_kyc_status(agent_id, StatusBody(status="approved"), current_user, db)


@router.put("/admin/agents/{agent_id}/reject")
async def admin_reject_agent(agent_id: str, body: StatusBody, current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)) -> dict:
    return await update_agent_kyc_status(agent_id, StatusBody(status="rejected", rejectionReason=body.rejectionReason), current_user, db)


@router.get("/admin/surge/status")
async def flutter_get_surge_status(
    admin: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
    redis_client=Depends(redis_dep)
) -> dict:
    return await get_surge_status(admin=admin, db=db, redis_client=redis_client)


@router.get("/surge/status")
async def get_surge_status_public(
    city: str = "KR Nagar",
    redis_client=Depends(redis_dep),
) -> dict:
    manual = await redis_client.get(f"surge:MANUAL:{city}")
    auto = _redis_text(await redis_client.get(f"surge:AUTO:{city}"))
    rain = await redis_client.get(f"surge:RAIN:{city}")

    auto_pay = {"MILD": 10, "MEDIUM": 20, "HIGH": 30}.get(auto, 0)
    rain_pay = 20 if rain else 0
    manual_pay = 10 if manual else 0
    total = max(auto_pay, manual_pay) + rain_pay

    return {
        "city": city,
        "surge_active": total > 0,
        "total_bonus": total,
        "rain_active": bool(rain),
        "auto_level": auto or "NONE",
    }


@router.post("/admin/surge/rain/enable")
async def flutter_enable_rain_surge(
    body: dict,
    admin: User = Depends(require_admin),
    redis_client=Depends(redis_dep)
) -> dict:
    return await enable_rain_surge(admin=admin, body=body, redis_client=redis_client)


@router.post("/admin/surge/rain/disable")
async def flutter_disable_rain_surge(
    body: dict,
    admin: User = Depends(require_admin),
    redis_client=Depends(redis_dep)
) -> dict:
    return await disable_rain_surge(admin=admin, body=body, redis_client=redis_client)


@router.post("/upload/image")
async def upload_image(
    request: Request,
    file: UploadFile | None = File(None),
    upload_type: str | None = Form(None, alias="type"),
    current_user: User = Depends(get_current_user),
) -> dict:
    content_type = request.headers.get("content-type", "")
    if content_type.startswith("application/json"):
        data = ImageBase64Body.model_validate(await request.json())
        raw = data.imageBase64.split(",", 1)[-1]
        contents = base64.b64decode(raw)
        image_type = data.type
        image_name = data.imageName
    else:
        if file is None:
            raise HTTPException(status_code=400, detail="file is required")
        contents = await file.read()
        image_type = upload_type or "misc"
        image_name = file.filename or "image.bin"
    safe_type = "".join(ch for ch in image_type if ch.isalnum() or ch in ("-", "_")) or "misc"
    safe_name = Path(image_name).name.replace(" ", "_")
    directory = Path("uploads") / safe_type / str(current_user.id)
    directory.mkdir(parents=True, exist_ok=True)
    filename = f"{int(time.time())}_{safe_name}"
    path = directory / filename
    path.write_bytes(contents)
    url = f"/uploads/{safe_type}/{current_user.id}/{filename}"
    ip = _local_ip()
    return {"url": url, "fullUrl": f"http://{ip}:8000{url}", "success": True}
