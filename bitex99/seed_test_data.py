import asyncio
import os
from datetime import UTC, date, datetime, time
from pathlib import Path

from dotenv import load_dotenv
from sqlalchemy import select

os.environ["DEBUG"] = "false"
load_dotenv(Path(__file__).resolve().parent / ".env")

from app.database import AsyncSessionLocal
from app.models.delivery_partner import DeliveryPartner, VehicleType
from app.models.kyc_document import DocStatus as KycDocStatus
from app.models.kyc_document import DocType as KycDocType
from app.models.kyc_document import KycDocument
from app.models.menu import MenuCategory, MenuItem
from app.models.restaurant import Restaurant
from app.models.restaurant_document import DocStatus as RestaurantDocStatus
from app.models.restaurant_document import DocType as RestaurantDocType
from app.models.restaurant_document import RestaurantDocument
from app.models.restaurant_partner import BusinessType, RestaurantPartner
from app.models.restaurant_timing import RestaurantTiming
from app.models.user import User


KYC_FILE_URL = "/uploads/kyc/test/sample.jpg"
RESTAURANT_DOC_FILE_URL = "/uploads/restaurant/test/sample.jpg"

REQUIRED_KYC_DOCS = [
    KycDocType.AADHAAR_FRONT,
    KycDocType.AADHAAR_BACK,
    KycDocType.PAN_CARD,
    KycDocType.DRIVING_LICENSE_FRONT,
    KycDocType.DRIVING_LICENSE_BACK,
    KycDocType.VEHICLE_RC,
    KycDocType.VEHICLE_INSURANCE,
    KycDocType.BANK_PASSBOOK,
    KycDocType.PROFILE_PHOTO,
]

REQUIRED_RESTAURANT_DOCS = [
    RestaurantDocType.FSSAI_LICENSE,
    RestaurantDocType.PAN_CARD,
    RestaurantDocType.BANK_CANCELLED_CHEQUE,
    RestaurantDocType.OWNER_AADHAAR_FRONT,
    RestaurantDocType.OWNER_AADHAAR_BACK,
    RestaurantDocType.RESTAURANT_PHOTO_FRONT,
]

RESTAURANTS = [
    {
        "name": "Spice Garden",
        "slug": "spice-garden",
        "city": "Mumbai",
        "cuisine_types": ["North Indian", "Biryani"],
        "is_open": True,
        "rating": 4.3,
        "delivery_fee": 30,
        "min_order_amount": 199,
        "avg_delivery_time": 35,
        "phone": "+912211111111",
        "owner_phone": "+919222211111",
        "owner_name": "Amit Sharma",
        "categories": {
            "Mains": [
                ("Butter Chicken", 280, False),
                ("Dal Makhani", 180, True),
            ],
            "Breads": [
                ("Naan", 40, True),
            ],
        },
    },
    {
        "name": "Dosa Express",
        "slug": "dosa-express",
        "city": "Mumbai",
        "cuisine_types": ["South Indian"],
        "is_open": True,
        "rating": 4.6,
        "delivery_fee": 20,
        "min_order_amount": 99,
        "avg_delivery_time": 25,
        "phone": "+912222222222",
        "owner_phone": "+919222222222",
        "owner_name": "Suresh Iyer",
        "categories": {
            "Dosas": [
                ("Masala Dosa", 80, True),
                ("Plain Dosa", 60, True),
            ],
            "Beverages": [
                ("Filter Coffee", 30, True),
            ],
        },
    },
]


async def upsert_user(db, *, phone: str, name: str, role: str, partner_status=None, restaurant_status=None) -> User:
    user = await db.scalar(select(User).where(User.phone == phone))
    if user is None:
        user = User(phone=phone)
        db.add(user)
        await db.flush()
    user.name = name
    user.role = role
    user.partner_status = partner_status
    user.restaurant_status = restaurant_status
    user.is_active = True
    user.is_verified = True
    return user


async def upsert_delivery_agent(db) -> DeliveryPartner:
    user = await upsert_user(
        db,
        phone="+919111111111",
        name="Ravi Kumar",
        role="DELIVERY_PARTNER",
        partner_status="KYC_APPROVED",
    )
    partner = await db.scalar(select(DeliveryPartner).where(DeliveryPartner.user_id == user.id))
    if partner is None:
        partner = DeliveryPartner(user_id=user.id)
        db.add(partner)
        await db.flush()

    partner.fe_id = "ZFE00099"
    partner.city = "Mumbai"
    partner.vehicle_type = VehicleType.BIKE
    partner.vehicle_number = "MH01AB9999"
    partner.is_online = False
    partner.referral_code = partner.referral_code or "ZFE00099REF"

    now = datetime.now(UTC)
    for doc_type in REQUIRED_KYC_DOCS:
        doc = await db.scalar(
            select(KycDocument).where(
                KycDocument.partner_id == partner.id,
                KycDocument.doc_type == doc_type,
            )
        )
        if doc is None:
            doc = KycDocument(partner_id=partner.id, doc_type=doc_type)
            db.add(doc)
        doc.file_url = KYC_FILE_URL
        doc.file_name = "sample.jpg"
        doc.status = KycDocStatus.APPROVED
        doc.rejection_reason = None
        doc.verified_at = now
    return partner


async def upsert_restaurant(db, data: dict) -> Restaurant:
    owner = await upsert_user(
        db,
        phone=data["owner_phone"],
        name=data["owner_name"],
        role="RESTAURANT_PARTNER",
        restaurant_status="DOCS_APPROVED",
    )

    restaurant = await db.scalar(select(Restaurant).where(Restaurant.phone == data["phone"]))
    if restaurant is None:
        restaurant = await db.scalar(select(Restaurant).where(Restaurant.slug == data["slug"]))
    if restaurant is None:
        restaurant = Restaurant(name=data["name"], slug=data["slug"], city=data["city"], full_address=f"{data['name']}, Mumbai")
        db.add(restaurant)
        await db.flush()

    restaurant.name = data["name"]
    restaurant.slug = data["slug"]
    restaurant.city = data["city"]
    restaurant.full_address = f"{data['name']}, Mumbai"
    restaurant.phone = data["phone"]
    restaurant.cuisine_types = data["cuisine_types"]
    restaurant.is_open = data["is_open"]
    restaurant.rating = data["rating"]
    restaurant.delivery_fee = data["delivery_fee"]
    restaurant.min_order_amount = data["min_order_amount"]
    restaurant.avg_delivery_time = data["avg_delivery_time"]
    restaurant.total_reviews = 100
    restaurant.is_pure_veg = all(item[2] for items in data["categories"].values() for item in items)
    restaurant.has_offers = False

    partner = await db.scalar(select(RestaurantPartner).where(RestaurantPartner.user_id == owner.id))
    if partner is None:
        partner = await db.scalar(select(RestaurantPartner).where(RestaurantPartner.restaurant_id == restaurant.id))
    if partner is None:
        partner = RestaurantPartner(user_id=owner.id, restaurant_id=restaurant.id, owner_name=data["owner_name"], business_type=BusinessType.RESTAURANT, fssai_number="12345678901234")
        db.add(partner)
        await db.flush()

    partner.user_id = owner.id
    partner.restaurant_id = restaurant.id
    partner.owner_name = data["owner_name"]
    partner.business_type = BusinessType.RESTAURANT
    partner.commission_rate = 20
    partner.fssai_number = "12345678901234"
    partner.fssai_expiry = date(2027, 12, 31)
    partner.pan_number = "ABCDE1234F"
    partner.bank_account_number = "1234567890"
    partner.bank_ifsc = "HDFC0001234"
    partner.bank_account_name = data["owner_name"]

    await upsert_timings(db, restaurant)
    await upsert_restaurant_documents(db, partner)
    await upsert_menu(db, restaurant, data["categories"])
    return restaurant


async def upsert_timings(db, restaurant: Restaurant) -> None:
    for day in range(7):
        timing = await db.scalar(
            select(RestaurantTiming).where(
                RestaurantTiming.restaurant_id == restaurant.id,
                RestaurantTiming.day_of_week == day,
            )
        )
        if timing is None:
            timing = RestaurantTiming(restaurant_id=restaurant.id, day_of_week=day)
            db.add(timing)
        timing.opens_at = time(10, 0)
        timing.closes_at = time(23, 0)
        timing.is_closed = False


async def upsert_restaurant_documents(db, partner: RestaurantPartner) -> None:
    now = datetime.now(UTC)
    for doc_type in REQUIRED_RESTAURANT_DOCS:
        doc = await db.scalar(
            select(RestaurantDocument).where(
                RestaurantDocument.partner_id == partner.id,
                RestaurantDocument.doc_type == doc_type,
            )
        )
        if doc is None:
            doc = RestaurantDocument(partner_id=partner.id, doc_type=doc_type)
            db.add(doc)
        doc.file_url = RESTAURANT_DOC_FILE_URL
        doc.file_name = "sample.jpg"
        doc.status = RestaurantDocStatus.APPROVED
        doc.rejection_reason = None
        doc.verified_at = now


async def upsert_menu(db, restaurant: Restaurant, categories: dict[str, list[tuple[str, int, bool]]]) -> None:
    for display_order, (category_name, items) in enumerate(categories.items(), start=1):
        category = await db.scalar(
            select(MenuCategory).where(
                MenuCategory.restaurant_id == restaurant.id,
                MenuCategory.name == category_name,
            )
        )
        if category is None:
            category = MenuCategory(restaurant_id=restaurant.id, name=category_name)
            db.add(category)
            await db.flush()
        category.display_order = display_order
        category.is_active = True

        for item_name, price, is_veg in items:
            item = await db.scalar(
                select(MenuItem).where(
                    MenuItem.restaurant_id == restaurant.id,
                    MenuItem.name == item_name,
                )
            )
            if item is None:
                item = MenuItem(restaurant_id=restaurant.id, category_id=category.id, name=item_name, price=price)
                db.add(item)
            item.category_id = category.id
            item.description = ""
            item.price = price
            item.discounted_price = None
            item.image_url = ""
            item.is_veg = is_veg
            item.is_available = True
            item.preparation_time = 15
            item.tags = []


async def seed() -> None:
    async with AsyncSessionLocal() as db:
        await upsert_delivery_agent(db)
        for restaurant in RESTAURANTS:
            await upsert_restaurant(db, restaurant)
        await db.commit()
    print("Seeded test data: 1 delivery agent, 2 restaurants, menus, KYC docs, restaurant docs.")


if __name__ == "__main__":
    asyncio.run(seed())
