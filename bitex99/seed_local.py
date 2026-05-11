import os
import subprocess
import uuid
from pathlib import Path


PSQL = os.environ.get("PSQL_PATH", r"C:\Program Files\PostgreSQL\18\bin\psql.exe")
DB_NAME = os.environ.get("BITEX_DB", "bitex")
DB_USER = os.environ.get("BITEX_DB_USER", "postgres")
DB_PASSWORD = os.environ.get("PGPASSWORD", "1234567890")
NS = uuid.UUID("1df9b3d2-477f-4ff3-8fd6-dfb48cc78234")


def sid(*parts: str) -> str:
    return str(uuid.uuid5(NS, ":".join(parts)))


def q(value):
    if value is None:
        return "NULL"
    if isinstance(value, bool):
        return "TRUE" if value else "FALSE"
    if isinstance(value, (int, float)):
        return str(value)
    return "'" + str(value).replace("'", "''") + "'"


def arr(values):
    return "ARRAY[" + ", ".join(q(v) for v in values) + "]::varchar[]"


KYC_DOCS = [
    "AADHAAR_FRONT",
    "AADHAAR_BACK",
    "PAN_CARD",
    "DRIVING_LICENSE_FRONT",
    "DRIVING_LICENSE_BACK",
    "VEHICLE_RC",
    "VEHICLE_INSURANCE",
    "BANK_PASSBOOK",
    "PROFILE_PHOTO",
]

RESTAURANT_DOCS = [
    "FSSAI_LICENSE",
    "GST_CERTIFICATE",
    "PAN_CARD",
    "BANK_CANCELLED_CHEQUE",
    "OWNER_AADHAAR_FRONT",
    "OWNER_AADHAAR_BACK",
    "SHOP_ACT_LICENSE",
    "PARTNERSHIP_DEED",
    "MENU_PHOTO",
    "RESTAURANT_PHOTO_FRONT",
    "RESTAURANT_PHOTO_INTERIOR",
]

RESTAURANTS = [
    {
        "key": "hotel-annapurna-kr-nagar",
        "name": "Hotel Annapurna",
        "owner_phone": "+919222222222",
        "owner": "Shanthi Lal",
        "restaurant_phone": "+918222222222",
        "city": "KR Nagar",
        "full_address": "Main Road, KR Nagar, Mysuru - 571602",
        "lat": 12.4219,
        "lng": 76.0200,
        "cuisines": ["South Indian"],
        "rating": 4.4,
        "delivery_fee": 20,
        "min_order": 99,
        "avg_delivery": 25,
        "is_open": True,
        "is_pure_veg": True,
        "menu": {
            "Breakfast": [("Idli Vada Combo", 50, True), ("Masala Dosa", 60, True), ("Plain Dosa", 45, True), ("Pongal", 40, True)],
            "Meals": [("Veg Meals", 90, True), ("Special Thali", 120, True)],
            "Beverages": [("Filter Coffee", 20, True), ("Tea", 15, True)],
        },
        "offer": ("20% OFF up to Rs 40", "PERCENT", 20, 40, 99),
    },
    {
        "key": "sri-venkateshwara-tiffin-centre-hunsur",
        "name": "Sri Venkateshwara Tiffin Centre",
        "owner_phone": "+919333333333",
        "owner": "Manjunath K",
        "restaurant_phone": "+918333333333",
        "city": "Hunsur",
        "full_address": "Bus Stand Road, Hunsur, Mysuru - 571105",
        "lat": 12.3048,
        "lng": 76.2908,
        "cuisines": ["South Indian", "North Indian"],
        "rating": 4.2,
        "delivery_fee": 25,
        "min_order": 80,
        "avg_delivery": 30,
        "is_open": True,
        "is_pure_veg": False,
        "menu": {
            "Tiffin": [("Idli (2pcs)", 30, True), ("Vada", 25, True), ("Dosa", 45, True)],
            "Meals": [("Veg Thali", 80, True), ("Chicken Curry Rice", 110, False)],
            "Snacks": [("Mirchi Bajji", 30, True), ("Gobi Manchurian", 60, True)],
            "Beverages": [("Coffee", 15, True), ("Lassi", 30, True)],
        },
    },
]


def upsert_user_sql(phone, name, role, city=None, partner_status=None, restaurant_status=None):
    user_id = sid("user", phone)
    return f"""
INSERT INTO users (id, phone, name, role, city, partner_status, restaurant_status, is_active, is_verified)
VALUES ({q(user_id)}::uuid, {q(phone)}, {q(name)}, {q(role)}, {q(city)}, {q(partner_status)}, {q(restaurant_status)}, TRUE, TRUE)
ON CONFLICT (phone) DO NOTHING;
UPDATE users
SET name = {q(name)}, role = {q(role)}, city = {q(city)}, partner_status = {q(partner_status)},
    restaurant_status = {q(restaurant_status)}, is_active = TRUE, is_verified = TRUE, updated_at = now()
WHERE phone = {q(phone)};
"""


def build_sql():
    lines = ["BEGIN;"]

    lines.append(upsert_user_sql("+919111111111", "Ravi Kumar", "DELIVERY_PARTNER", "Hunsur", "KYC_APPROVED"))
    agent_partner = sid("delivery_partner", "+919111111111")
    lines.append(f"""
DELETE FROM delivery_partners
WHERE user_id = (SELECT id FROM users WHERE phone = '+919111111111') OR fe_id = 'ZFE00001';
UPDATE delivery_partners
SET fe_id = NULL, referral_code = NULL
WHERE fe_id = 'ZFE00001' AND user_id <> (SELECT id FROM users WHERE phone = '+919111111111');
INSERT INTO delivery_partners (id, user_id, fe_id, city, vehicle_type, vehicle_number, is_online, current_latitude, current_longitude, last_location_at, referral_code)
VALUES ({q(agent_partner)}::uuid, (SELECT id FROM users WHERE phone = '+919111111111'), 'ZFE00001', 'Hunsur', 'BIKE', 'KA09AB1234', FALSE, 12.3050000, 76.2910000, now(), 'ZFE00001REF')
ON CONFLICT (user_id) DO NOTHING;
UPDATE delivery_partners
SET fe_id = 'ZFE00001', city = 'Hunsur', vehicle_type = 'BIKE', vehicle_number = 'KA09AB1234',
    current_latitude = 12.3050000, current_longitude = 76.2910000, last_location_at = now()
WHERE user_id = (SELECT id FROM users WHERE phone = '+919111111111');
""")
    for doc in KYC_DOCS:
        lines.append(f"""
INSERT INTO kyc_documents (id, partner_id, doc_type, file_url, file_name, status, verified_at)
VALUES ({q(sid("kyc", agent_partner, doc))}::uuid, {q(agent_partner)}::uuid, {q(doc)}::doctype, '/uploads/kyc/test/sample.jpg', 'sample.jpg', 'APPROVED'::docstatus, now())
ON CONFLICT (partner_id, doc_type) DO NOTHING;
UPDATE kyc_documents
SET file_url = '/uploads/kyc/test/sample.jpg', file_name = 'sample.jpg', status = 'APPROVED'::docstatus,
    rejection_reason = NULL, verified_at = now()
WHERE partner_id = {q(agent_partner)}::uuid AND doc_type = {q(doc)}::doctype;
""")

    for restaurant in RESTAURANTS:
        lines.append(upsert_user_sql(restaurant["owner_phone"], restaurant["owner"], "RESTAURANT_PARTNER", restaurant["city"], None, "DOCS_APPROVED"))
        rest_id = sid("restaurant", restaurant["key"])
        partner_id = sid("restaurant_partner", restaurant["key"])
        has_offer = "offer" in restaurant
        description = f"{restaurant['name']} serving {', '.join(restaurant['cuisines'])} in {restaurant['city']}."
        lines.append(f"""
INSERT INTO restaurants (id, name, slug, description, cuisine_types, city, full_address, latitude, longitude, phone, rating, total_reviews, avg_delivery_time, min_order_amount, delivery_fee, is_open, is_pure_veg, has_offers)
VALUES ({q(rest_id)}::uuid, {q(restaurant["name"])}, {q(restaurant["key"])}, {q(description)}, {arr(restaurant["cuisines"])}, {q(restaurant["city"])}, {q(restaurant["full_address"])},
        {restaurant["lat"]}, {restaurant["lng"]}, {q(restaurant["restaurant_phone"])}, {restaurant["rating"]}, 100, {restaurant["avg_delivery"]}, {restaurant["min_order"]}, {restaurant["delivery_fee"]}, {q(restaurant["is_open"])}, {q(restaurant["is_pure_veg"])}, {q(has_offer)})
ON CONFLICT (slug) DO NOTHING;
UPDATE restaurants
SET name = {q(restaurant["name"])}, description = {q(description)}, cuisine_types = {arr(restaurant["cuisines"])}, city = {q(restaurant["city"])},
    full_address = {q(restaurant["full_address"])}, latitude = {restaurant["lat"]}, longitude = {restaurant["lng"]},
    phone = {q(restaurant["restaurant_phone"])}, rating = {restaurant["rating"]}, total_reviews = 100,
    avg_delivery_time = {restaurant["avg_delivery"]}, min_order_amount = {restaurant["min_order"]}, delivery_fee = {restaurant["delivery_fee"]},
    is_open = {q(restaurant["is_open"])}, is_pure_veg = {q(restaurant["is_pure_veg"])}, has_offers = {q(has_offer)}
WHERE slug = {q(restaurant["key"])};

INSERT INTO restaurant_partners (id, user_id, restaurant_id, owner_name, business_type, commission_rate, bank_account_number, bank_ifsc, bank_account_name, pan_number, fssai_number, fssai_expiry)
VALUES ({q(partner_id)}::uuid, (SELECT id FROM users WHERE phone = {q(restaurant["owner_phone"])}), {q(rest_id)}::uuid, {q(restaurant["owner"])}, 'RESTAURANT'::business_type_enum, 20.00, '1234567890', 'HDFC0001234', {q(restaurant["owner"])}, 'ABCDE1234F', '12345678901234', '2027-12-31')
ON CONFLICT (user_id) DO NOTHING;
UPDATE restaurant_partners
SET restaurant_id = {q(rest_id)}::uuid, owner_name = {q(restaurant["owner"])}, business_type = 'RESTAURANT'::business_type_enum,
    commission_rate = 20.00, bank_account_number = '1234567890', bank_ifsc = 'HDFC0001234',
    bank_account_name = {q(restaurant["owner"])}, pan_number = 'ABCDE1234F', fssai_number = '12345678901234',
    fssai_expiry = '2027-12-31'
WHERE user_id = (SELECT id FROM users WHERE phone = {q(restaurant["owner_phone"])});
""")
        for doc in RESTAURANT_DOCS:
            lines.append(f"""
INSERT INTO restaurant_documents (id, partner_id, doc_type, file_url, file_name, status, verified_at)
VALUES ({q(sid("restaurant_doc", partner_id, doc))}::uuid, {q(partner_id)}::uuid, {q(doc)}::restaurant_doc_type_enum, '/uploads/kyc/test/sample.jpg', 'sample.jpg', 'APPROVED'::restaurant_doc_status_enum, now())
ON CONFLICT (partner_id, doc_type) DO NOTHING;
UPDATE restaurant_documents
SET file_url = '/uploads/kyc/test/sample.jpg', file_name = 'sample.jpg',
    status = 'APPROVED'::restaurant_doc_status_enum, rejection_reason = NULL, verified_at = now()
WHERE partner_id = {q(partner_id)}::uuid AND doc_type = {q(doc)}::restaurant_doc_type_enum;
""")
        for day in range(7):
            lines.append(f"""
INSERT INTO restaurant_timings (id, restaurant_id, day_of_week, opens_at, closes_at, is_closed)
VALUES ({q(sid("restaurant_timing", rest_id, str(day)))}::uuid, {q(rest_id)}::uuid, {day}, '07:00', '22:30', FALSE)
ON CONFLICT (restaurant_id, day_of_week) DO NOTHING;
UPDATE restaurant_timings SET opens_at = '07:00', closes_at = '22:30', is_closed = FALSE
WHERE restaurant_id = {q(rest_id)}::uuid AND day_of_week = {day};
""")
        for display_order, (category, items) in enumerate(restaurant["menu"].items(), 1):
            cat_id = sid("category", restaurant["key"], category)
            lines.append(f"""
INSERT INTO menu_categories (id, restaurant_id, name, display_order, is_active)
VALUES ({q(cat_id)}::uuid, {q(rest_id)}::uuid, {q(category)}, {display_order}, TRUE)
ON CONFLICT (id) DO NOTHING;
UPDATE menu_categories SET name = {q(category)}, display_order = {display_order}, is_active = TRUE
WHERE id = {q(cat_id)}::uuid;
""")
            for index, (item, price, is_veg) in enumerate(items, 1):
                item_id = sid("item", restaurant["key"], category, item)
                tags = arr(["Local favorite"] if index == 1 else [])
                item_desc = f"Fresh {item} from {restaurant['name']}."
                lines.append(f"""
INSERT INTO menu_items (id, restaurant_id, category_id, name, description, price, discounted_price, image_url, is_veg, is_available, preparation_time, tags)
VALUES ({q(item_id)}::uuid, {q(rest_id)}::uuid, {q(cat_id)}::uuid, {q(item)}, {q(item_desc)}, {price}, NULL, '', {q(is_veg)}, TRUE, 15, {tags})
ON CONFLICT (id) DO NOTHING;
UPDATE menu_items
SET category_id = {q(cat_id)}::uuid, name = {q(item)}, description = {q(item_desc)}, price = {price}, discounted_price = NULL,
    image_url = '', is_veg = {q(is_veg)}, is_available = TRUE, preparation_time = 15, tags = {tags}
WHERE id = {q(item_id)}::uuid;
""")
        if has_offer:
            title, offer_type, value, max_discount, min_order = restaurant["offer"]
            offer_id = sid("offer", restaurant["key"], title)
            lines.append(f"""
INSERT INTO restaurant_offers (id, restaurant_id, title, offer_type, discount_value, max_discount, min_order_amount, valid_from, valid_until, is_active, usage_count)
VALUES ({q(offer_id)}::uuid, {q(rest_id)}::uuid, {q(title)}, {q(offer_type)}::restaurant_offer_type_enum, {value}, {max_discount}, {min_order}, now(), now() + interval '180 days', TRUE, 0)
ON CONFLICT (id) DO NOTHING;
UPDATE restaurant_offers
SET title = {q(title)}, offer_type = {q(offer_type)}::restaurant_offer_type_enum, discount_value = {value}, max_discount = {max_discount},
    min_order_amount = {min_order}, valid_from = now(), valid_until = now() + interval '180 days', is_active = TRUE
WHERE id = {q(offer_id)}::uuid;
""")

    lines.append("COMMIT;")
    lines.append("SELECT name, city, is_open FROM restaurants ORDER BY city, name;")
    lines.append("SELECT COUNT(*) FROM menu_items;")
    return "\n".join(lines)


def main():
    sql_path = Path(__file__).with_name("_seed_local.sql")
    sql_path.write_text(build_sql(), encoding="utf-8")
    env = os.environ.copy()
    env["PGPASSWORD"] = DB_PASSWORD
    try:
        subprocess.run(
            [PSQL, "-U", DB_USER, "-d", DB_NAME, "-v", "ON_ERROR_STOP=1", "-f", str(sql_path)],
            check=True,
            env=env,
        )
    finally:
        try:
            sql_path.unlink()
        except OSError:
            pass


if __name__ == "__main__":
    main()
