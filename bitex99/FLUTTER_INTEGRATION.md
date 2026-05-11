# Flutter ↔ BiteX99 API Integration Guide

## Base URL

```
Development: http://{YOUR_IP}:8000/api/flutter/v1
```

Replace `{YOUR_IP}` with your machine IP:
- **Windows**: Run `ipconfig` → find **IPv4 Address** (e.g., `192.168.1.105`)
- **Example**: `http://192.168.1.105:8000/api/flutter/v1`

> **Note**: Do NOT use `localhost` or `127.0.0.1` — Flutter mobile apps cannot reach
> these addresses from a physical device. Use the actual LAN IP.

---

## Quick Setup: Find Your IP

```
GET /api/flutter/v1/config
```

Returns:
```json
{
  "apiBase": "http://10.176.225.215:8000/api/flutter/v1",
  "wsBase": "ws://10.176.225.215:8000/api/v1/ws",
  "uploadBase": "http://10.176.225.215:8000/uploads",
  "version": "1.0.0",
  "environment": "development"
}
```

Use `apiBase` directly in your Flutter `ApiService`.

---

## Authentication

All protected endpoints require:
```
Authorization: Bearer {token}
```

Token obtained from `POST /auth/verify-otp` → `response.token`.

### Auth Flow

```
Step 1: POST /auth/send-otp
        Body: { "phone": "9876543210" }
        → OTP appears in uvicorn terminal (dev mode)

Step 2: POST /auth/verify-otp
        Body: { "phone": "9876543210", "otp": "123456",
                "role": "customer", "name": "Rahul", "town": "KR Nagar" }
        → Returns token, refreshToken, user object

Step 3: Save token to SharedPreferences/SecureStorage
Step 4: Use "Authorization: Bearer {token}" in all subsequent requests
```

---

## Role Values

| Flutter Role | Backend Role |
|---|---|
| `"customer"` | `CUSTOMER` |
| `"restaurant"` | `RESTAURANT_PARTNER` |
| `"agent"` | `DELIVERY_PARTNER` |
| `"admin"` | `ADMIN` |

Send the Flutter role string when calling `/auth/verify-otp`.

---

## Status Values

### Order Statuses

| Flutter Status | Backend Status |
|---|---|
| `"received"` | `PLACED` |
| `"preparing"` | `CONFIRMED` / `PREPARING` |
| `"pickup_ready"` | `READY_FOR_PICKUP` |
| `"delivering"` | `OUT_FOR_DELIVERY` |
| `"delivered"` | `DELIVERED` |
| `"cancelled"` | `CANCELLED` / `FAILED` |

### Restaurant Statuses

| Flutter Status | Backend Status |
|---|---|
| `"pending"` | `PENDING_DOCS` / `DOCS_SUBMITTED` |
| `"active"` | `DOCS_APPROVED` |
| `"rejected"` | `DOCS_REJECTED` / `SUSPENDED` |

### Agent KYC Statuses

| Flutter Status | Backend Status |
|---|---|
| `"notSubmitted"` | `PENDING_KYC` |
| `"pending"` | `KYC_SUBMITTED` |
| `"approved"` | `KYC_APPROVED` |
| `"rejected"` | `KYC_REJECTED` |

---

## Field Mappings

| Flutter Field | Backend Field |
|---|---|
| `town` | `city` |
| `shopName` | `name` |
| `landmark` | `delivery_address_snapshot.full_address` |
| `pickupCode` | `delivery_otp.otp` |
| `deliveryOtp` | `delivery_otp.otp` (same field) |
| `agentId` | `delivery_assignment.partner_id` |
| `available` (menu) | `is_available` |
| `isOpen` | `is_open` |

---

## Endpoint Reference

### Auth

| Method | Endpoint | Auth | Description |
|---|---|---|---|
| POST | `/auth/send-otp` | No | Send OTP to phone |
| POST | `/auth/verify-otp` | No | Verify OTP, get tokens |
| POST | `/auth/logout` | Yes | Invalidate session |
| GET | `/users/{uid}` | Yes | Get user profile |

### Restaurants

| Method | Endpoint | Auth | Description |
|---|---|---|---|
| GET | `/restaurants?town=...` | No | List restaurants by town |
| GET | `/restaurants/{id}` | No | Get single restaurant |
| POST | `/restaurants` | Yes (RESTAURANT_PARTNER) | Create restaurant |
| PUT | `/restaurants/{id}/status` | Yes (ADMIN) | Approve/reject restaurant |
| PUT | `/restaurants/{id}/online-status` | Yes (RESTAURANT_PARTNER) | Toggle open/closed |
| GET | `/restaurants/{id}/orders` | Yes | Get restaurant's orders |

### Menu

| Method | Endpoint | Auth | Description |
|---|---|---|---|
| GET | `/restaurants/{id}/menu` | No | Get menu |
| POST | `/restaurants/{id}/menu` | Yes (RESTAURANT_PARTNER) | Add menu item |
| PUT | `/restaurants/{id}/menu/{itemId}` | Yes | Update menu item |
| DELETE | `/restaurants/{id}/menu/{itemId}` | Yes | Delete menu item |

### Orders

| Method | Endpoint | Auth | Description |
|---|---|---|---|
| POST | `/orders` | Yes (CUSTOMER) | Create order |
| GET | `/orders/{id}` | Yes | Get order details |
| GET | `/orders?customerId=...&status=...` | Yes | List orders |
| PUT | `/orders/{id}/status` | Yes (RESTAURANT_PARTNER) | Update order status |
| PUT | `/orders/{id}/agent` | Yes (DELIVERY_PARTNER) | Accept delivery |
| PUT | `/orders/{id}/complete` | Yes (DELIVERY_PARTNER) | Complete delivery |

### Agent KYC

| Method | Endpoint | Auth | Description |
|---|---|---|---|
| POST | `/agents/kyc` | Yes (DELIVERY_PARTNER) | Submit KYC |
| GET | `/agents/{id}/kyc-status` | Yes | Get KYC status |
| PUT | `/agents/{id}/kyc-status` | Yes (ADMIN) | Update KYC status |
| PUT | `/agents/{id}/online-status` | Yes (DELIVERY_PARTNER) | Go online/offline |
| GET | `/agents/{id}/earnings` | Yes | Get earnings |

### Admin

| Method | Endpoint | Auth | Description |
|---|---|---|---|
| GET | `/admin/restaurants/pending` | Yes (ADMIN) | Pending restaurants |
| PUT | `/admin/restaurants/{id}/approve` | Yes (ADMIN) | Approve restaurant |
| PUT | `/admin/restaurants/{id}/reject` | Yes (ADMIN) | Reject restaurant |
| GET | `/admin/agents/pending` | Yes (ADMIN) | Pending KYC agents |
| PUT | `/admin/agents/{id}/approve` | Yes (ADMIN) | Approve agent KYC |
| PUT | `/admin/agents/{id}/reject` | Yes (ADMIN) | Reject agent KYC |

### Utilities

| Method | Endpoint | Auth | Description |
|---|---|---|---|
| POST | `/upload/image` | Yes | Upload image (multipart or base64) |
| GET | `/config` | No | Get backend URL config |

---

## Image Upload

### Format A — Multipart (recommended for Flutter)

```dart
var request = http.MultipartRequest(
  'POST', Uri.parse('$baseUrl/upload/image'));
request.headers['Authorization'] = 'Bearer $token';
request.files.add(await http.MultipartFile.fromPath('file', filePath));
request.fields['type'] = 'restaurant'; // or 'kyc', 'menu'
var response = await request.send();
```

### Format B — Base64 JSON

```dart
final bytes = await File(filePath).readAsBytes();
final base64 = base64Encode(bytes);
final response = await http.post(
  Uri.parse('$baseUrl/upload/image'),
  headers: {
    'Authorization': 'Bearer $token',
    'Content-Type': 'application/json',
  },
  body: jsonEncode({
    'imageBase64': base64,
    'imageName': 'photo.jpg',
    'type': 'restaurant',
  }),
);
```

**Response**:
```json
{
  "url": "/uploads/restaurant/{user_id}/timestamp_photo.jpg",
  "fullUrl": "http://10.176.225.215:8000/uploads/restaurant/.../photo.jpg",
  "success": true
}
```

---

## Replacing Firebase with FastAPI

### Firebase Auth → FastAPI OTP

```dart
// OLD (Firebase):
FirebaseAuth.instance.verifyPhoneNumber(
  phoneNumber: '+91$phone',
  verificationCompleted: ...,
  ...
)

// NEW (FastAPI):
// Step 1: Send OTP
await http.post(
  Uri.parse('$baseUrl/auth/send-otp'),
  headers: {'Content-Type': 'application/json'},
  body: jsonEncode({'phone': phone}),
);
// OTP appears in uvicorn terminal in dev mode

// Step 2: Verify OTP
final response = await http.post(
  Uri.parse('$baseUrl/auth/verify-otp'),
  headers: {'Content-Type': 'application/json'},
  body: jsonEncode({
    'phone': phone,
    'otp': otpCode,
    'role': 'customer',
    'name': userName,
    'town': selectedTown,
  }),
);
final data = jsonDecode(response.body);
final token = data['token'];
// Save token to SecureStorage
```

### Firestore Queries → REST Endpoints

```dart
// OLD (Firestore stream):
FirebaseFirestore.instance
  .collection('restaurants')
  .where('town', isEqualTo: town)
  .snapshots()
  .listen((snapshot) => ...);

// NEW (FastAPI polling or single fetch):
final response = await http.get(
  Uri.parse('$baseUrl/restaurants?town=$town&status=active'),
  headers: {'Authorization': 'Bearer $token'},
);
final data = jsonDecode(response.body);
final restaurants = data['restaurants'] as List;

// For real-time updates, poll every 5 seconds:
Timer.periodic(Duration(seconds: 5), (_) async {
  final res = await http.get(Uri.parse('$baseUrl/orders/$orderId'), ...);
  // Update UI
});
```

---

## Real-Time Updates

The backend uses WebSockets. For Flutter, you have two options:

### Option 1 — Polling (Simple)

```dart
Timer.periodic(Duration(seconds: 5), (_) async {
  final response = await http.get(
    Uri.parse('$baseUrl/orders/$orderId'),
    headers: {'Authorization': 'Bearer $token'},
  );
  final order = jsonDecode(response.body);
  setState(() => currentStatus = order['status']);
});
```

### Option 2 — WebSocket (Real-time)

```dart
// Order status WebSocket
final wsUrl = 'ws://{YOUR_IP}:8000/api/v1/ws/partner/orders?token=$token';
final channel = WebSocketChannel.connect(Uri.parse(wsUrl));
channel.stream.listen((message) {
  final data = jsonDecode(message);
  if (data['event'] == 'NEW_ORDER') {
    // Refresh order list
  }
});
```

---

## Order Creation Flow

```dart
// 1. POST /orders
final response = await http.post(
  Uri.parse('$baseUrl/orders'),
  headers: {
    'Authorization': 'Bearer $token',
    'Content-Type': 'application/json',
  },
  body: jsonEncode({
    'restaurantId': restaurantId,
    'town': 'KR Nagar',
    'items': [
      {'itemId': itemId, 'name': 'Butter Chicken', 'quantity': 1, 'price': 299.0, 'totalPrice': 299.0},
    ],
    'totalAmount': 329.0,
    'paymentMethod': 'cash', // or 'upi'
    'landmark': 'Near Bus Stand',
  }),
);
final order = jsonDecode(response.body);
final orderId = order['orderId'];
final status = order['status']; // "received"
final pickupCode = order['pickupCode']; // null until agent assigned
```

---

## Error Format

All errors return:
```json
{
  "success": false,
  "message": "Invalid OTP",
  "error_code": "INVALID_OTP"
}
```

Common error codes:
- `OTP_COOLDOWN` — Wait before requesting new OTP
- `INVALID_OTP` — Wrong OTP entered
- `OTP_EXPIRED` — OTP timed out, request new one
- `ROLE_CONFLICT` — Phone already registered with different role
- `RESTAURANT_NOT_APPROVED` — Restaurant not yet approved by admin
- `KYC_NOT_APPROVED` — Agent KYC not yet approved

---

## Backend Architecture

```
Flutter App
   ↓
/api/flutter/v1/*    (Compatibility Layer — field/status mapping)
   ↓
Service Layer        (Business logic — auth, orders, assignments)
   ↓
PostgreSQL + Redis   (Storage + OTP/sessions)
```

**Key principle**: The backend is the **single source of truth**. Flutter only sends/receives HTTP requests — no client-side state sync.

---

## FLUTTER_INTEGRATION STATUS

```
Auth endpoints:       /api/flutter/v1/auth/* ✅
Restaurant endpoints: /api/flutter/v1/restaurants/* ✅
Menu endpoints:       /api/flutter/v1/.../menu/* ✅
Order endpoints:      /api/flutter/v1/orders/* ✅
Agent endpoints:      /api/flutter/v1/agents/* ✅
Admin endpoints:      /api/flutter/v1/admin/* ✅
Upload endpoint:      /api/flutter/v1/upload/image ✅
Config endpoint:      /api/flutter/v1/config ✅

Status mapping:       Flutter ↔ Backend ✅
Role mapping:         Flutter ↔ Backend ✅
Field mapping:        town↔city, shopName↔name ✅

Flutter base URL: http://{YOUR_IP}:8000/api/flutter/v1
```
