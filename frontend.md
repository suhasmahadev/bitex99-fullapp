# Bitex99 Frontend - Complete IO & Backend Requirements Documentation

**Generated:** May 5, 2026  
**Purpose:** Complete description of all Flutter frontend pages, inputs, outputs, buttons, and backend API requirements for backend verification.

---

## Table of Contents

1. [Global/Onboarding Flow](#global-onboarding-flow)
2. [Customer Screens](#customer-screens)
3. [Restaurant Partner Screens](#restaurant-partner-screens)
4. [Delivery Agent Screens](#delivery-agent-screens)
5. [Admin Panel](#admin-panel)
6. [Data Models & Structures](#data-models--structures)
7. [API Endpoints Required](#api-endpoints-required)

---

# GLOBAL/ONBOARDING FLOW

## 1. Splash Screen

**File:** `screens/onboarding/splash_screen.dart`

### Purpose
Initial loading screen that checks user authentication status and routes to appropriate page.

### Behavior
- Displays fade animation for 1.5 seconds
- Checks if user is logged in via `AuthService`
- Fetches user profile from database using `getUserProfile(uid)`
- Routes based on user role:
  - `customer` → CustomerMain
  - `restaurant` → RestaurantPartnerPage (with async status check)
  - `agent` → AgentMain
  - Not logged in → LoginScreen

### Outputs/API Calls
- `AuthService.isLoggedIn` - Check authentication status
- `DatabaseService.getUserProfile(uid)` - Fetch user profile with role
- Firestore: `users/{uid}` - Read user document

### Expected Response
```json
{
  "uid": "user_phone",
  "name": "User Name",
  "phone": "9876543210",
  "role": "customer|restaurant|agent|admin",
  "town": "KR Nagar",
  "status": "active",
  "createdAt": "timestamp"
}
```

---

## 2. Onboarding Screen

**File:** `screens/onboarding/onboarding_screen.dart`

### Purpose
Select language and town before login.

### Inputs
- **Language Dropdown** - Select between "English" and "Kannada"
- **Town Selection Cards** - Click to select:
  - Available: "KR Nagar", "Hunsur"
  - Coming Soon: "Mysuru", "Periyapatna" (disabled/greyed out)

### Buttons
- **Continue Button** - Enabled only when town is selected

### Outputs
- Navigates to `LoginScreen` with selected `town` parameter
- No backend API call at this stage

---

## 3. Login Screen & OTP Verification

**File:** `screens/onboarding/login_screen.dart`

### Part A: Role Selection (After initial login)

#### Purpose
Allow user to choose which role they want to use.

#### Options
- **Customer Card** - "Order food from local restaurants"
- **Restaurant Partner Card** - "Manage orders, menu & earnings"
- **Delivery Agent Card** - "Deliver orders & earn rewards"

#### Behavior
- On card tap: Sets role in UserProvider, updates theme, navigates to respective main screen
- Updates `UserProvider.role`
- Updates `ThemeProvider.roleTheme(role)`

---

### Part B: Phone & OTP Flow

#### Inputs - Step 1: Basic Details

1. **First Name Text Field**
   - Placeholder: "Enter your first name"
   - Max length: Usually limited
   - Validation: Non-empty required

2. **Phone Number Text Field**
   - Placeholder: "Enter phone number (10 digits)"
   - Max length: 10 digits
   - Validation: Must be valid Indian mobile number
   - Prefix: Automatically adds +91

3. **Role Selection Radio Buttons**
   - Customer
   - Restaurant Partner
   - Delivery Agent

#### Buttons - Step 1
- **Send OTP Button** - Validates fields and calls `AuthService.verifyPhone()`

#### Outputs - Step 1
- **Backend API Call:**
  ```
  AuthService.verifyPhone(phone)
  ```
  - In demo mode: Generates random 6-digit OTP and displays in console
  - In production: Firebase Phone Auth sends OTP via SMS

#### Inputs - Step 2: OTP Entry

1. **OTP Input Fields** - 6 individual digit fields
   - Each field auto-advances to next on digit entry
   - Auto-focus management

#### Buttons - Step 2
- **Verify OTP Button** - Verifies OTP code
- **Resend OTP Button** - Resends OTP with 30-second countdown
- **Edit Details Button** - Goes back to step 1

#### Outputs - Step 2
- **Backend API Call:**
  ```
  AuthService.signInWithOtp(otp)
  ```
  - In demo mode: Compares with generated OTP
  - In production: Firebase Phone Auth verification

#### Success Response
On successful OTP verification:
- Creates/updates user in Firestore
- Navigates to `RoleSelectorScreen`
- Session data stored in `UserProvider`

#### Expected Errors
- "Enter a valid 6-digit OTP"
- "Invalid OTP. Please try again."
- "OTP expired. Please request a new one."

---

## 4. Role Selector Screen

**File:** `screens/onboarding/login_screen.dart` (RoleSelectorScreen)

### Purpose
After successful login, let user choose their role and navigate to appropriate dashboard.

### Display
- Welcome message: "How would you like to continue?"
- Three role cards with:
  - Icon
  - Role name
  - Brief description
  - Arrow indicator

### Role Cards
1. **Customer**
   - Icon: Shopping bag
   - Description: "Order food from local restaurants"
   - Color: Orange

2. **Restaurant Partner**
   - Icon: Restaurant
   - Description: "Manage orders, menu & earnings"
   - Color: Green

3. **Delivery Agent**
   - Icon: Delivery bike
   - Description: "Deliver orders & earn rewards"
   - Color: Blue

### Behavior on Card Tap
1. Calls `UserProvider.setRole(role)`
2. Calls `ThemeProvider.setRoleTheme(role)`
3. Navigates to respective main screen
4. Clears navigation stack

### Navigation Routes
- Customer → `CustomerMain`
- Restaurant Partner → `RestaurantPartnerPage`
- Delivery Agent → `DeliveryDashboardPage`

---

---

# CUSTOMER SCREENS

## 5. Customer Main (Tab Navigation)

**File:** `screens/customer/customer_main.dart`

### Purpose
Main container with bottom navigation for customer area.

### Tabs
1. **Home** (default) - CustomerHome
2. **Cart** - CartScreen
3. **Orders** - OrderTracking

### Bottom Navigation
- Icons and labels for each tab
- Currently selected tab highlighted
- No API calls at this level

---

## 6. Customer Home Screen

**File:** `screens/customer/customer_home.dart`

### Purpose
Main dashboard showing available restaurants and food items.

### Header Elements
1. **App Logo** - Bitex99 logo
2. **Location Pill**
   - Icon: Location pin (red)
   - Text: Town name (e.g., "KR Nagar")
   - Non-functional display

3. **Search Icon** - Currently non-functional
4. **Logout Icon** - Red logout icon

### Logout Button Behavior
- Clears UserProvider
- Navigates to LoginScreen
- Clears navigation stack

### Main Content Sections

#### 1. Banner Carousel
- **Type:** PageView carousel
- **Content:** 2 banners with:
  - Title: "Today's Specials" or "Local Favorites"
  - Subtitle: "Fresh & Hot Meals" or "Authentic Taste"
  - Background color gradient
- **Functionality:** Swipeable between banners

#### 2. Category Filter Row
Categories displayed (currently static):
- Meals
- Tiffin
- Snacks
- Sweets
- Beverages

**Functionality:** Clickable but not filtering in current implementation

#### 3. Restaurant List
- **Title:** "Restaurants near you"

### Restaurant Cards
Each restaurant shows:
- Restaurant name
- Cuisine type badge
- Rating (e.g., "4.5 stars")
- Number of ratings (e.g., "500+ ratings")
- FSSAI verification badge
- Clickable card

### Backend API Requirements

#### 1. Get Restaurants by Town
```
Method: Stream<List<RestaurantModel>>
Endpoint: DatabaseService.getRestaurantsByTown(town)
Parameters:
  - town: "KR Nagar" (hardcoded or from UserProvider)
Query Condition:
  - Firestore: collection('restaurants')
               .where('town', isEqualTo: town)
               .where('status', isEqualTo: 'active')
               .snapshots()
```

#### Expected Response (Array)
```json
{
  "restaurants": [
    {
      "id": "restaurant_phone",
      "shopName": "Hotel Annapurna",
      "ownerName": "Shanthi Lal",
      "phone": "9876543210",
      "email": "hotel@example.com",
      "town": "KR Nagar",
      "address": "Sandalwood Road",
      "cuisineType": "South Indian",
      "fssaiNumber": "FSSAI123456",
      "upiId": "hotel@ybl",
      "status": "active",
      "fssaiPhotoUrl": "url",
      "kitchenPhotoUrl": "url",
      "signboardPhotoUrl": "url",
      "restaurantImageUrl": "url",
      "isOpen": true
    }
  ]
}
```

### Buttons/Actions
- **Restaurant Card** - Tap to navigate to RestaurantDetail with selected restaurant object
- **Logout Button** - Logout and return to login

---

## 7. Restaurant Detail Screen

**File:** `screens/customer/restaurant_detail.dart`

### Purpose
Display restaurant details, menu items, and allow adding items to cart.

### Header Section
- **Restaurant Image/Icon Area**
  - Height: 28% of screen
  - Displays restaurant icon
  - Gradient overlay (black opacity 0.4)
  - Back button (top-left, safe area)
  - Restaurant name overlay (bottom)

### Restaurant Info Section
- **FSSAI Badge** - "FSSAI Licensed" with verification icon (blue)
- **Rating** - "4.5 (500+ ratings)" with star icon (orange)

### Menu Section
- **Title:** "Menu"
- **Menu Items List** - Hardcoded in current implementation:
  1. "Special Masala Dosa" - ₹60 (special badge)
  2. "Idli Vada Combo" - ₹50
  3. "Filter Coffee" - ₹20
  4. "Plain Roti" - ₹40 (marked as sold out)

### Menu Item Card
Each item displays:
- Item name
- Item description
- Price (₹)
- Special/New badge (if applicable)
- Sold out overlay (if applicable)
- Quantity controls: "-" | "Qty" | "+"

### Cart Calculation (Local)
- Tracks items in local `cartItems` map
- Real-time total calculation: `_cartTotal`
- Total = Σ(quantity × price)

### Bottom Bar
When items added to cart:
- Shows total amount: "₹ XXX"
- **Button:** "View Cart" or "Continue Shopping"

### Backend API Requirements
**NOTE:** Current implementation uses hardcoded menu items.

#### For Production - Get Menu Items
```
Method: Stream<List<MenuItemModel>>
Endpoint: DatabaseService.getMenuForRestaurant(restaurantId)
Parameters:
  - restaurantId: restaurant.id (from selected restaurant)
Query:
  - Firestore: collection('restaurants')
              .doc(restaurantId)
              .collection('menu')
              .snapshots()
```

#### Expected Response (Array)
```json
{
  "menu": [
    {
      "id": "item_id_1",
      "restaurantId": "restaurant_id",
      "name": "Special Masala Dosa",
      "description": "Golden crispy dosa with potato mash",
      "price": 60.0,
      "category": "Breakfast",
      "available": true,
      "imageUrl": "url",
      "isSpecial": true,
      "preparationTime": 15
    }
  ]
}
```

### Navigation
- **Back Button** - Returns to CustomerHome
- **View Cart Button** - Navigates to CartScreen with cart data

---

## 8. Cart Screen

**File:** `screens/customer/cart_screen.dart`

### Purpose
Review cart items, add delivery address, select payment method, and place order.

### Sections

#### 1. Cart Items
- List of items with:
  - Quantity: "2 ×"
  - Item name
  - Total price for that item: "₹ 120"
- Items are passed from RestaurantDetail screen

#### 2. Delivery Address
- **Label:** "Delivery Address"
- **Input Field:**
  - Placeholder: "Enter landmark (e.g. Near Bus Stand)"
  - Multiline text input
  - Large height for comfort

### Inputs - Delivery Address
1. **Landmark/Address TextField**
   - Input: Text description of delivery location
   - Placeholder: "Enter landmark (e.g. Near Bus Stand)"
   - This becomes the delivery address for order

### Payment Options

#### Radio Buttons/Selection
1. **UPI (GPay, PhonePe)** - Selected by default
   - Icon: Wallet
   
2. **Cash on Delivery**
   - Icon: Money/Currency

### Bill Details Section

#### Bill Breakdown (Hardcoded in current implementation)
```
Item Total:      ₹ 140
Delivery Fee:    ₹ 20
Taxes:           ₹ 8
─────────────────────
Total Pay:       ₹ 168
```

### Backend API Requirements

#### 1. Create Order
```
Method: POST
Endpoint: DatabaseService or Backend API
Parameters:
  - customerId: current user ID
  - restaurantId: selected restaurant ID
  - town: user's town
  - items: [
      {
        "itemId": "item_1",
        "name": "Special Masala Dosa",
        "quantity": 2,
        "price": 60,
        "totalPrice": 120
      }
    ]
  - totalAmount: 168
  - paymentMethod: "upi" or "cash"
  - landmark: "Near Bus Stand"
```

#### Expected Response
```json
{
  "orderId": "order_12345",
  "customerId": "customer_phone",
  "restaurantId": "restaurant_phone",
  "agentId": null,
  "town": "KR Nagar",
  "items": [
    {
      "itemId": "item_1",
      "name": "Special Masala Dosa",
      "quantity": 2,
      "price": 60
    }
  ],
  "totalAmount": 168,
  "paymentMethod": "upi",
  "landmark": "Near Bus Stand",
  "status": "received",
  "pickupCode": "7421",
  "deliveryOtp": "7421",
  "createdAt": "timestamp"
}
```

### Buttons
- **Confirm Order Button**
  - Label: "Confirm Order ₹ 168"
  - Navigates to OrderTracking screen
  - Should trigger `CreateOrder` API

### Validations
- At least one item in cart
- Delivery address non-empty
- Payment method selected

---

## 9. Order Tracking Screen

**File:** `screens/customer/order_tracking.dart`

### Purpose
Real-time order tracking with status updates and delivery agent information.

### Sections

#### 1. Delivery Agent Card
- **Agent Avatar** - Circular avatar with delivery icon
- **Agent Name** - "Suresh Kumar"
- **Role Text** - "Your Delivery Partner"
- **Call Button** - Green phone icon (currently non-functional)

#### 2. Delivery OTP Display
- **Label:** "Delivery OTP"
- **Format:** Large spaced digits (e.g., "7 4 2 1")
- **Purpose:** Customer shares this OTP when delivery agent arrives

#### 3. Order Status Timeline
Each status step shows:
- **Step Circle** - Filled (green) if completed, primary color if active, grey if pending
- **Check mark** - For completed steps
- **Active indicator** - For current step
- **Step Title** - "Order Confirmed" / "Preparing your food" / etc.
- **Time/Status** - Timestamp or "In progress" text
- **Connector line** - Vertical line between steps (same color as step)

#### Status Flow (Hardcoded in current implementation)
1. **Order Confirmed** - ✓ 10:30 AM (completed)
2. **Preparing your food** - ✓ 10:35 AM (completed)
3. **Agent assigned & on the way** - ◉ In progress (active)
4. **Order arriving** - ○ --- (pending)

### Backend API Requirements

#### 1. Get Order Details & Status
```
Method: Stream<OrderModel>
Endpoint: DatabaseService.getOrder(orderId)
Query:
  - Firestore: collection('orders').doc(orderId).snapshots()
```

#### Expected Response
```json
{
  "id": "order_12345",
  "customerId": "customer_phone",
  "restaurantId": "restaurant_phone",
  "agentId": "agent_phone",
  "town": "KR Nagar",
  "items": [
    {
      "itemId": "item_1",
      "name": "Special Masala Dosa",
      "quantity": 2,
      "price": 60
    }
  ],
  "totalAmount": 168,
  "paymentMethod": "upi",
  "landmark": "Near Bus Stand",
  "status": "delivering",
  "pickupCode": "7421",
  "deliveryOtp": "7421",
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

#### 2. Get Assigned Delivery Agent Info
```
Method: GET
Endpoint: DatabaseService.getAgent(agentId)
Query:
  - Firestore: collection('users').doc(agentId)
               where role == 'agent'
```

#### Expected Response
```json
{
  "uid": "agent_phone",
  "name": "Suresh Kumar",
  "phone": "9876543210",
  "role": "agent",
  "town": "KR Nagar",
  "status": "active",
  "kycStatus": "approved"
}
```

### Real-time Updates
- Status stream updates trigger UI refresh
- Status changes automatically update timeline
- Possible status values: `received` → `preparing` → `pickup_ready` → `delivering` → `delivered`

### Buttons/Actions
- **Call Button** - Calls delivery agent (phone integration needed)
- **Back Button** - Returns to CustomerMain

---

---

# RESTAURANT PARTNER SCREENS

## 10. Restaurant Partner Page

**File:** `screens/restaurant/restaurant_partner_page.dart`

### Purpose
Multi-step registration form for new restaurant partners.

### Registration Steps
Total: 4 steps (stepper indicator shows progress)

#### Step 1: Basic Information
**Inputs:**
1. **Restaurant Name** - TextField
   - Placeholder: "Enter restaurant name"
   - Required: Yes

2. **Owner Name** - TextField
   - Placeholder: "Enter your name"
   - Required: Yes

3. **Phone Number** - TextField (prefilled from UserProvider)
   - ReadOnly or autofilled
   - Required: Yes

4. **Location/Town** - Dropdown/Picker
   - Options: ["KR Nagar", "Hunsur"]
   - Required: Yes

**Buttons:**
- **Next Step** - Validates fields, advances to step 2

#### Step 2: Restaurant Details
**Inputs:**
1. **Email Address** - TextField
   - Placeholder: "Enter email"
   - Validation: Email format
   - Required: Yes

2. **Full Address** - TextField
   - Placeholder: "Enter complete address"
   - Required: Yes

3. **Cuisine Type** - Dropdown
   - Options:
     - South Indian
     - North Indian
     - Chinese
     - Biryani
     - Fast Food
     - Bakery & Sweets
     - Beverages
     - Multi-Cuisine
     - Other
   - Required: Yes

4. **FSSAI Number** - TextField
   - Placeholder: "Enter FSSAI license number"
   - Required: Yes

**Buttons:**
- **Back** - Return to step 1
- **Next Step** - Validates and advances to step 3

#### Step 3: Media Upload
**Inputs:**
1. **Restaurant Image** - Image Picker
   - Thumbnail preview
   - Tap to pick from gallery
   - Required: No (optional in demo)

**Display:**
- Image name if uploaded
- Placeholder if not uploaded

**Buttons:**
- **Back** - Return to step 2
- **Next Step** - Advance to step 4

#### Step 4: Review & Submit
**Display:**
- Summary of all entered information
- Image preview if uploaded
- All fields read-only

**Buttons:**
- **Back** - Return to step 3
- **Submit** - Submit registration and navigate to RestaurantWaitingScreen

### Backend API Requirements

#### 1. Register Restaurant
```
Method: POST
Endpoint: DatabaseService.registerRestaurant(restaurantModel)
Parameters:
  - id: userId (phone)
  - shopName: "Hotel Name"
  - ownerName: "Owner Name"
  - phone: "9876543210"
  - email: "email@example.com"
  - town: "KR Nagar"
  - address: "Full address"
  - cuisineType: "South Indian"
  - fssaiNumber: "FSSAI123456"
  - status: "pending"
  - imageBytes: Uint8List (if image uploaded)
  - imageName: String
```

#### Expected Response
```json
{
  "id": "restaurant_phone",
  "shopName": "Hotel Annapurna",
  "ownerName": "Shanthi Lal",
  "phone": "9876543210",
  "email": "hotel@example.com",
  "town": "KR Nagar",
  "address": "Sandalwood Road",
  "cuisineType": "South Indian",
  "fssaiNumber": "FSSAI123456",
  "upiId": "",
  "status": "pending",
  "fssaiPhotoUrl": "",
  "kitchenPhotoUrl": "",
  "signboardPhotoUrl": "",
  "restaurantImageUrl": "url_if_uploaded",
  "isOpen": false
}
```

#### Error Handling
- Display error snackbar if submission fails
- Allow retry on timeout
- Handle Firebase offline scenarios

---

## 11. Restaurant Waiting Screen

**File:** `screens/restaurant/restaurant_waiting_screen.dart`

### Purpose
Inform restaurant partner that application is under review.

### Display
- **Icon:** Hourglass/Clock icon
- **Title:** "Pending Approval"
- **Message:** "Our team is reviewing your application. You will be notified once approved."
- **Status:** Application submitted successfully

### Backend API Requirements
- Poll or listen for restaurant status updates
- Check: `DatabaseService.getRestaurantStream(restaurantId)`

#### Expected Status Change
```json
{
  "status": "active" // Changed from "pending"
}
```

When status changes to "active":
- Automatically navigate to RestaurantMain (dashboard)
- Update UserProvider if needed

### Navigation
- Cannot go back from this screen (application submitted)
- Auto-navigate to RestaurantMain when approved

---

## 12. Restaurant Main (Tab Navigation)

**File:** `screens/restaurant/restaurant_main.dart`

### Purpose
Main container with bottom navigation for restaurant dashboard.

### Tabs
1. **Dashboard** (default) - RestaurantDashboard
2. **Menu** - MenuManagement

### Bottom Navigation
- Icons and labels for each tab
- Currently selected tab highlighted

### Special Behavior
- Cannot pop if on Dashboard tab (first tab)
- Tapping back button on secondary tab returns to Dashboard

---

## 13. Restaurant Dashboard

**File:** `screens/restaurant/restaurant_dashboard.dart`

### Purpose
Main dashboard showing orders, revenue, and restaurant status.

### Header Section
- **App Logo** - Bitex99 logo (black background)
- **Online Status Indicator**
  - Green dot + "Online" text (if open) or Red dot + "Offline" text (if closed)
  - **Toggle Switch** - Tap to toggle restaurant online/offline status
- **Logout Button** - Red logout icon

### Stats Row
Two stat cards displayed:

#### Card 1: Today's Orders
- Label: "Today's Orders"
- Value: Number count (e.g., "5")
- Icon: Receipt icon (blue)
- Background: Light blue

#### Card 2: Revenue
- Label: "Revenue"
- Value: Amount (e.g., "₹ 1,200")
- Icon: Rupee icon (green)
- Background: Light green

### Active Orders Section

#### Title
"Active Orders" with pending count badge (e.g., "3 Pending")

#### Order Cards (Conditional)
If no active orders:
- Large inbox icon (light grey)
- Text: "No active orders"

If active orders exist:
- List of order cards, each showing:
  - Customer name
  - Order items count
  - Order total
  - Current status
  - Status update button (e.g., "Mark Ready", "Confirm Pickup")

### Backend API Requirements

#### 1. Get Orders for Restaurant
```
Method: Stream<List<OrderModel>>
Endpoint: DatabaseService.getOrdersForRestaurant(restaurantId)
Query:
  - Firestore: collection('orders')
              .where('restaurantId', isEqualTo: restaurantId)
              .orderBy('createdAt', descending: true)
              .snapshots()
```

#### Expected Response (Array)
```json
{
  "orders": [
    {
      "id": "order_12345",
      "customerId": "customer_phone",
      "restaurantId": "restaurant_phone",
      "agentId": null,
      "town": "KR Nagar",
      "items": [
        {
          "itemId": "item_1",
          "name": "Special Masala Dosa",
          "quantity": 2,
          "price": 60
        }
      ],
      "totalAmount": 168,
      "paymentMethod": "upi",
      "landmark": "Near Bus Stand",
      "status": "received",
      "pickupCode": "7421",
      "deliveryOtp": "7421",
      "createdAt": "timestamp",
      "updatedAt": "timestamp"
    }
  ]
}
```

#### 2. Toggle Online Status
```
Method: PUT
Endpoint: DatabaseService.toggleRestaurantOnlineStatus(restaurantId, isOpen)
Parameters:
  - restaurantId: restaurant ID (user phone)
  - isOpen: boolean (true = online, false = offline)
Field to update:
  - isOpen: boolean
```

#### 3. Get Restaurant Stream
```
Method: Stream
Endpoint: DatabaseService.getRestaurantStream(restaurantId)
Returns:
  - Real-time updates to restaurant details including isOpen status
```

#### Expected Response (Stream)
```json
{
  "id": "restaurant_phone",
  "shopName": "Hotel Annapurna",
  "ownerName": "Shanthi Lal",
  "phone": "9876543210",
  "email": "hotel@example.com",
  "town": "KR Nagar",
  "address": "Sandalwood Road",
  "cuisineType": "South Indian",
  "fssaiNumber": "FSSAI123456",
  "status": "active",
  "isOpen": true
}
```

### Buttons/Actions
- **Online/Offline Toggle** - Switch restaurant availability
- **Order Status Buttons** - Mark orders as ready/preparing/etc.
- **Logout Button** - Logout and navigate to LoginScreen

### Real-time Updates
- Order list updates in real-time (stream)
- Stats recalculate automatically
- Status changes reflect immediately

---

## 14. Menu Management Screen

**File:** `screens/restaurant/menu_management.dart`

### Purpose
Create, read, update, and delete menu items for the restaurant.

### Header
- **Title:** "Menu Management"
- **Add Item Button** - Green "+" icon (top-right)
- **Logout Button** (if standalone)

### Menu Display

#### Empty State
If no menu items:
- Large menu icon (grey)
- Text: "Your menu is empty"
- Button: "Add your first item"

#### Menu Items Grouped by Category
Items are grouped by category (e.g., "Breakfast", "Main Course"):

**Category Header** - Section title in uppercase (e.g., "BREAKFAST")

**Menu Item Cards** - For each item:
- Item name
- Item description (brief)
- Price (₹)
- Status badge (Available/Sold Out)
- Action buttons:
  - Edit (pencil icon)
  - Delete (trash icon)

### Add/Edit Item Dialog

#### Inputs
1. **Item Name** - TextField
   - Placeholder: "Enter item name"
   - Required: Yes

2. **Description** - TextField (multiline)
   - Placeholder: "Brief description"
   - Required: No

3. **Category** - Dropdown
   - Options: ["Breakfast", "Main Course", "Desserts", "Beverages", etc.]
   - Required: Yes

4. **Price** - NumberField
   - Placeholder: "₹ 0"
   - Required: Yes

5. **Availability Toggle** - Switch
   - True: Available
   - False: Sold Out
   - Default: True

6. **Image** - Image Picker (optional)
   - Show thumbnail if selected

#### Buttons (in Dialog)
- **Cancel** - Close dialog without saving
- **Save** - Submit new/updated item

### Backend API Requirements

#### 1. Get Menu Items for Restaurant
```
Method: Stream<List<MenuItemModel>>
Endpoint: DatabaseService.getMenuForRestaurant(restaurantId)
Query:
  - Firestore: collection('restaurants')
              .doc(restaurantId)
              .collection('menu')
              .snapshots()
```

#### Expected Response (Array)
```json
{
  "menu": [
    {
      "id": "item_uuid",
      "restaurantId": "restaurant_phone",
      "name": "Special Masala Dosa",
      "description": "Golden crispy dosa with potato mash",
      "price": 60.0,
      "category": "Breakfast",
      "available": true,
      "imageUrl": "url_or_empty",
      "isSpecial": false,
      "preparationTime": 15
    }
  ]
}
```

#### 2. Add Menu Item
```
Method: POST
Endpoint: DatabaseService.addMenuItem(restaurantId, menuItem)
Parameters:
  - restaurantId: restaurant ID
  - menuItem:
    {
      "id": "uuid_generated",
      "restaurantId": "restaurant_phone",
      "name": "Special Masala Dosa",
      "description": "Golden crispy dosa",
      "price": 60.0,
      "category": "Breakfast",
      "available": true,
      "imageUrl": "url_if_uploaded",
      "isSpecial": false,
      "preparationTime": 15
    }
```

#### Expected Response
```json
{
  "id": "item_uuid",
  "restaurantId": "restaurant_phone",
  "name": "Special Masala Dosa",
  "description": "Golden crispy dosa",
  "price": 60.0,
  "category": "Breakfast",
  "available": true
}
```

#### 3. Update Menu Item
```
Method: PUT
Endpoint: DatabaseService.updateMenuItem(restaurantId, itemId, updates)
Parameters:
  - restaurantId: restaurant ID
  - itemId: item ID
  - updates: {
      "available": false,
      "price": 65.0
    }
```

#### 4. Delete Menu Item
```
Method: DELETE
Endpoint: DatabaseService.deleteMenuItem(restaurantId, itemId)
Parameters:
  - restaurantId: restaurant ID
  - itemId: item ID
```

### Buttons/Actions
- **Add Item Button** - Opens add item dialog
- **Edit Button (on item card)** - Opens edit dialog with pre-filled data
- **Delete Button (on item card)** - Deletes item with confirmation
- **Save Button (in dialog)** - Submits new/updated item

---

---

# DELIVERY AGENT SCREENS

## 15. Delivery Dashboard Page

**File:** `screens/agent/delivery_dashboard_page.dart`

### Purpose
Main dashboard for delivery agents with KYC status checking and order management.

### Initial Route Logic
Based on KYC status, shows different screens:
- `KYCStatus.notSubmitted` → DeliveryKYCPage
- `KYCStatus.pending` → KYCPendingPage
- `KYCStatus.rejected` → KYCRejectedPage
- `KYCStatus.approved` → _DashboardView (main view)

### Main Dashboard View (KYC Approved)

#### Header
- **Agent Name** - Greeting with agent name (or "Delivery Partner")
- **Profile Icon** - Tap to navigate to AgentProfileScreen

#### Stats Row
Displays 3 stats:
1. **Active Deliveries** - Number of ongoing deliveries
2. **Today's Earnings** - ₹ amount for today
3. **Completion Rate** - Percentage

#### Online Status Toggle
- **Toggle Switch** - Switch agent online/offline
- **Status Indicator** - Green (Online) or Red (Offline)
- When toggled: Updates in real-time

#### Tab Bar
4 tabs:
1. **Orders** (with badge showing available count)
   - Shows available orders to accept
2. **Active** (with badge if has active order)
   - Shows current delivery in progress
3. **Earnings**
   - Shows earnings summary and history
4. **Notifications**
   - Push notifications about orders

#### Content Sections (by Tab)

### Tab 1: Available Orders

**File:** `screens/agent/available_orders.dart`

#### Purpose
Display list of available orders that agent can accept.

#### Order Cards
Each card shows:
- **Pickup Location**
  - Restaurant icon + restaurant name
  - Address/location
- **Delivery Location**
  - Location pin icon + customer location
  - Landmark
- **Arrow** - Direction indicator between pickup and delivery
- **Payout** - Delivery fee (₹)
- **Items** - Brief item list (if available)
- **Accept Button** - Green button to accept order

#### Card Layout Example
```
🏪 Hotel Annapurna
   Sandalwood Road, KR Nagar

        ⬇️

📍 Near Bus Stand, KR Nagar

Payout: ₹ 25.00  |  [Accept Button]
Items: Masala Dosa × 2, Coffee × 1
```

#### Backend API Requirements

#### 1. Get Available Orders
```
Method: Stream<List<OrderModel>>
Endpoint: DatabaseService.getAvailableOrders(town)
Query:
  - Firestore: collection('orders')
              .where('town', isEqualTo: town)
              .where('status', isEqualTo: 'pickup_ready')
              .where('agentId', isEqualTo: null)
              .snapshots()
```

#### Expected Response (Array)
```json
{
  "orders": [
    {
      "id": "order_12345",
      "customerId": "customer_phone",
      "restaurantId": "restaurant_phone",
      "agentId": null,
      "town": "KR Nagar",
      "items": [
        {
          "itemId": "item_1",
          "name": "Special Masala Dosa",
          "quantity": 2,
          "price": 60
        }
      ],
      "totalAmount": 168,
      "paymentMethod": "upi",
      "landmark": "Near Bus Stand",
      "status": "pickup_ready",
      "pickupCode": "7421",
      "deliveryOtp": "7421",
      "createdAt": "timestamp"
    }
  ]
}
```

#### 2. Accept Order
```
Method: PUT
Endpoint: DatabaseService or custom API
Parameters:
  - orderId: order ID
  - agentId: current agent's ID (phone)
  - status: "delivering" (or specific status)
Fields to update:
  - agentId: agent phone
  - status: "delivering"
  - assignedAt: timestamp
```

#### Expected Response
```json
{
  "orderId": "order_12345",
  "agentId": "agent_phone",
  "status": "delivering",
  "message": "Order accepted successfully"
}
```

### Tab 2: Active Delivery

**File:** `screens/agent/active_delivery.dart`

#### Purpose
Track current delivery with OTP entry and completion.

#### Sections

##### 1. Customer Info Card
- **Customer Avatar** - Circular avatar with person icon
- **Customer Name** - "Customer: Raju S"
- **Delivery Location** - "KR Nagar Railway Station"
- **Call Button** - Green phone icon
- **Navigate Button** - Blue map icon (Google Maps integration)

##### 2. Delivery OTP Entry
- **Title:** "Enter Delivery OTP"
- **Instruction:** "Ask customer for 6-digit OTP to complete delivery"
- **6 OTP Input Fields** - Individual digit inputs
- **Auto-advance** - Moves to next field on digit entry

##### 3. Delivery Status Display
- Shows pickup and delivery progress
- Real-time updates

#### Buttons
- **Complete Delivery Button**
  - Enabled only after all OTP digits entered
  - On click: Validates OTP with order data
  - On success: Shows success message "Delivery completed! ₹ 25 credited."
  - Navigates back to orders list after 2 seconds

#### Backend API Requirements

#### 1. Get Order Details (from available orders screen)
```
Same as "Get Order Details" from customer screen
```

#### 2. Complete Delivery (Verify OTP & Update)
```
Method: PUT
Endpoint: DatabaseService or custom API
Parameters:
  - orderId: order ID
  - deliveredOtp: OTP entered by user (should match deliveryOtp)
  - agentId: agent ID
  - deliveredAt: timestamp
Fields to update:
  - status: "delivered"
  - deliveredAt: timestamp
  - agentId: confirmed agent ID
```

#### Expected Response
```json
{
  "orderId": "order_12345",
  "status": "delivered",
  "earnedAmount": 25,
  "totalEarnings": 285,
  "message": "Delivery completed successfully"
}
```

#### 3. Update Earnings
```
Automatically update agent's earnings after delivery completion:
  - Add delivery payout to today's total
  - Update weekly/monthly earnings
```

### Tab 3: Earnings Screen

**File:** `screens/agent/earnings_screen.dart`

#### Purpose
Display earnings summary and weekly breakdown.

#### Summary Card (Top)
- **Title:** "Today's Earnings"
- **Large Amount:** "₹ 245.00" (today's total)
- **Stats Row:**
  - Deliveries: "8"
  - Avg/Order: "₹ 31"
  - Tips: "₹ 40"

#### Weekly Chart
- **Bar Chart** - 7 bars (Mon-Sun)
- **X-axis:** Day labels (Mon, Tue, Wed, etc.)
- **Y-axis:** Earnings amount
- **Bar Heights:** Proportional to earnings (e.g., Sat highest at ₹510)
- **Colors:** Primary color bars

#### Weekly History
- **List of rows**, each showing:
  - Day name
  - Earnings amount (₹)
  - Number of deliveries

### Backend API Requirements

#### 1. Get Earnings Summary
```
Method: GET
Endpoint: Custom API or DatabaseService.getEarningsSummary(agentId, dateRange)
Parameters:
  - agentId: agent ID
  - dateRange: "today" or date range
```

#### Expected Response
```json
{
  "today": {
    "totalEarnings": 245.00,
    "deliveries": 8,
    "averagePerOrder": 30.625,
    "tips": 40.00
  },
  "weekly": [
    { "day": "Monday", "amount": 180.00, "deliveries": 6 },
    { "day": "Tuesday", "amount": 320.00, "deliveries": 8 },
    { "day": "Wednesday", "amount": 150.00, "deliveries": 5 },
    { "day": "Thursday", "amount": 420.00, "deliveries": 12 },
    { "day": "Friday", "amount": 280.00, "deliveries": 8 },
    { "day": "Saturday", "amount": 510.00, "deliveries": 15 },
    { "day": "Sunday", "amount": 245.00, "deliveries": 7 }
  ]
}
```

### Tab 4: Notifications
- Tab placeholder for future notifications feature

---

## 16. Delivery KYC Page

**File:** `screens/agent/delivery_kyc_page.dart`

### Purpose
KYC (Know Your Customer) registration for delivery agents before they can start deliveries.

### Multi-Step Registration

#### Step 1: Personal Details
**Inputs:**
1. **Full Name** - TextField
2. **Date of Birth** - DatePicker
3. **Gender** - Dropdown/Radio
4. **Address** - TextField (multiline)

**Validation:** All fields required

#### Step 2: Identity Verification
**Inputs:**
1. **Aadhaar Number** - TextField (12 digits)
2. **Aadhaar Photo** - Image picker
3. **PAN Number** - TextField (optional)

**Validation:** Aadhaar required, photo required

#### Step 3: Vehicle Details
**Inputs:**
1. **Vehicle Type** - Dropdown ["Bike", "Scooter", "Bicycle", "Car"]
2. **Vehicle Registration Number** - TextField (e.g., "KA 09 AB 1234")
3. **Insurance Photo** - Image picker
4. **RC (Registration Certificate)** - Image picker

**Validation:** All fields required

#### Step 4: Bank Details
**Inputs:**
1. **Account Holder Name** - TextField
2. **Account Number** - TextField
3. **IFSC Code** - TextField
4. **Bank Name** - TextField (auto-complete from IFSC)

**Validation:** All fields required, IFSC validation

### Progress Indicator
- Bar at top showing 4 steps
- Filled color for current/completed steps
- Grey for pending steps

### Navigation Buttons (at bottom)
- **Back Button** - Visible from step 2 onwards
- **Next/Submit Button** - "Next Step" for steps 1-3, "Submit KYC" for step 4

### Backend API Requirements

#### 1. Submit Agent KYC
```
Method: POST
Endpoint: DatabaseService or custom API
Parameters:
  - agentId: agent phone
  - step1: {
      "fullName": "string",
      "dob": "date",
      "gender": "string",
      "address": "string"
    }
  - step2: {
      "aadhaarNumber": "string",
      "aadhaarPhotoUrl": "url",
      "panNumber": "string"
    }
  - step3: {
      "vehicleType": "Bike",
      "registrationNumber": "KA 09 AB 1234",
      "insurancePhotoUrl": "url",
      "rcPhotoUrl": "url"
    }
  - step4: {
      "accountHolderName": "string",
      "accountNumber": "string",
      "ifscCode": "string",
      "bankName": "string"
    }
  - status: "pending"
```

#### Expected Response
```json
{
  "agentId": "agent_phone",
  "status": "pending",
  "submittedAt": "timestamp",
  "message": "KYC submitted for verification"
}
```

### Post-Submission
- Navigate to KYCPendingPage
- Update UserProvider with KYC status

---

## 17. KYC Pending Page

**File:** `screens/agent/kyc_pending_page.dart`

### Purpose
Show pending KYC status and wait for approval.

### Display
- **Icon:** Hourglass/Clock
- **Title:** "KYC Under Review"
- **Message:** "Your KYC documents are being verified by our team. This usually takes 24-48 hours."
- **Status Indicator:** "Pending"

### Actions
- **View Details Button** (optional) - Shows submitted KYC details
- Cannot proceed until approved

### Real-time Updates
- Poll or listen for KYC status change
- When status changes to "approved": Auto-navigate to dashboard
- When status changes to "rejected": Navigate to KYCRejectedPage

---

## 18. KYC Rejected Page

**File:** `screens/agent/kyc_rejected_page.dart`

### Purpose
Inform agent about KYC rejection and allow resubmission.

### Display
- **Icon:** X mark or alert icon (red)
- **Title:** "KYC Rejected"
- **Rejection Reason:** Display reason from backend (e.g., "Blurry Aadhaar photo")

### Actions
- **Resubmit Button** - Navigates back to DeliveryKYCPage to resubmit

### Backend API Requirement
- Show rejection reason from: `agentKycRejectionReason` field

---

## 19. Agent Profile Screen

**File:** `screens/agent/agent_profile_screen.dart`

### Purpose
Display agent profile information and allow edits.

### Sections
- **Profile Photo** - Avatar
- **Name** - Editable
- **Phone** - Read-only
- **Email** - Editable
- **Address** - Editable
- **Vehicle Details** - Display (from KYC)
- **Bank Details** - Masked display (privacy)

### Buttons
- **Edit Profile** - Toggle edit mode
- **Save Changes** - Confirm edits
- **Change Password** - Navigate to password change
- **Logout** - Logout and return to login

---

---

# ADMIN PANEL

## 20. Admin Panel Screen

**File:** `screens/admin/admin_panel.dart`

### Purpose
Admin dashboard for approving/rejecting restaurants and delivery agents.

### Tabs

#### Tab 1: Restaurant Approvals

##### Purpose
Review and approve/reject pending restaurant applications.

##### Restaurant Card
Each pending restaurant shows:
- **Restaurant Name** - Main title
- **Status Badge** - "Pending" (orange)
- **Owner Name** - Subtext
- **Town** - Subtext
- **Photo Thumbnails** - 3 photos:
  - Signboard
  - Kitchen
  - FSSAI License
- **Reject Button** - Red outlined button
- **Approve Button** - Green filled button

##### Backend API Requirements

##### 1. Get Pending Restaurants
```
Method: Stream<List<RestaurantModel>>
Endpoint: DatabaseService.getPendingRestaurants()
Query:
  - Firestore: collection('restaurants')
              .where('status', isEqualTo: 'pending')
              .snapshots()
```

##### 2. Approve Restaurant
```
Method: PUT
Endpoint: DatabaseService.updateRestaurantStatus(restaurantId, 'active')
Parameters:
  - restaurantId: restaurant ID
  - status: "active"
  - approvedAt: timestamp
  - approvedBy: admin ID
```

##### 3. Reject Restaurant
```
Method: PUT
Endpoint: DatabaseService.updateRestaurantStatus(restaurantId, 'rejected')
Parameters:
  - restaurantId: restaurant ID
  - status: "rejected"
  - rejectionReason: string (optional)
  - rejectedAt: timestamp
  - rejectedBy: admin ID
```

#### Tab 2: Agent Approvals

##### Purpose
Review and approve/reject pending agent KYC submissions.

##### Agent Card
Shows:
- **Agent Name** - Main title
- **Status Badge** - "Pending" / "Approved" / "Rejected"
- **Phone** - Contact number
- **Vehicle Details** - (e.g., "Bike (KA 09 AB 1234)")
- **Photo Thumbnails** - 4 photos:
  - Aadhaar
  - Vehicle RC
  - Insurance
  - Bank Details (masked)
- **Reject Button** - Red outlined
- **Approve Button** - Green filled

##### Backend API Requirements

##### 1. Get Pending Agents
```
Method: Stream<List<AgentKYCModel>>
Endpoint: DatabaseService.getPendingAgents()
Query:
  - Firestore: collection('agents_kyc')
              .where('status', isEqualTo: 'pending')
              .snapshots()
```

##### 2. Approve Agent KYC
```
Method: PUT
Endpoint: DatabaseService.updateAgentKycStatus(agentId, 'approved')
Parameters:
  - agentId: agent ID
  - status: "approved"
  - approvedAt: timestamp
  - approvedBy: admin ID
```

##### 3. Reject Agent KYC
```
Method: PUT
Endpoint: DatabaseService.updateAgentKycStatus(agentId, 'rejected')
Parameters:
  - agentId: agent ID
  - status: "rejected"
  - rejectionReason: string (required)
  - rejectedAt: timestamp
  - rejectedBy: admin ID
```

---

---

# DATA MODELS & STRUCTURES

## User Model

```json
{
  "uid": "string (phone)",
  "name": "string",
  "phone": "string (10 digits)",
  "role": "customer | restaurant | agent | admin",
  "town": "string (KR Nagar, Hunsur, etc.)",
  "status": "active | pending | rejected",
  "createdAt": "timestamp"
}
```

## Restaurant Model

```json
{
  "id": "string (restaurant owner phone)",
  "shopName": "string",
  "ownerName": "string",
  "phone": "string",
  "email": "string",
  "town": "string",
  "address": "string",
  "cuisineType": "string",
  "upiId": "string (optional)",
  "fssaiNumber": "string",
  "status": "pending | active | rejected",
  "fssaiPhotoUrl": "string (url)",
  "kitchenPhotoUrl": "string (url)",
  "signboardPhotoUrl": "string (url)",
  "restaurantImageUrl": "string (url)",
  "isOpen": "boolean"
}
```

## Order Model

```json
{
  "id": "string (unique order ID)",
  "customerId": "string (phone)",
  "restaurantId": "string (restaurant phone)",
  "agentId": "string (agent phone) | null",
  "town": "string",
  "items": [
    {
      "itemId": "string",
      "name": "string",
      "quantity": "integer",
      "price": "float"
    }
  ],
  "totalAmount": "float",
  "paymentMethod": "upi | cash",
  "landmark": "string (delivery address)",
  "status": "received | preparing | pickup_ready | delivering | delivered | cancelled",
  "pickupCode": "string (4 digits)",
  "deliveryOtp": "string (4 digits)",
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

## Menu Item Model

```json
{
  "id": "string (uuid)",
  "restaurantId": "string",
  "name": "string",
  "description": "string",
  "price": "float",
  "category": "string",
  "available": "boolean",
  "imageUrl": "string (url) | empty",
  "isSpecial": "boolean",
  "preparationTime": "integer (minutes)"
}
```

## Agent KYC Model

```json
{
  "agentId": "string (phone)",
  "status": "pending | approved | rejected",
  "personalDetails": {
    "fullName": "string",
    "dob": "date",
    "gender": "string",
    "address": "string"
  },
  "identityDetails": {
    "aadhaarNumber": "string",
    "aadhaarPhotoUrl": "string",
    "panNumber": "string"
  },
  "vehicleDetails": {
    "vehicleType": "string",
    "registrationNumber": "string",
    "insurancePhotoUrl": "string",
    "rcPhotoUrl": "string"
  },
  "bankDetails": {
    "accountHolderName": "string",
    "accountNumber": "string",
    "ifscCode": "string",
    "bankName": "string"
  },
  "submittedAt": "timestamp",
  "approvedAt": "timestamp | null",
  "rejectionReason": "string | null"
}
```

---

# API ENDPOINTS REQUIRED

## Summary of All Backend Endpoints Needed

### Authentication
- [ ] `POST /auth/verify-phone` - Send OTP to phone
- [ ] `POST /auth/verify-otp` - Verify OTP and login
- [ ] `POST /auth/logout` - Logout user

### User Management
- [ ] `GET /users/{uid}` - Get user profile
- [ ] `POST /users` - Create user profile
- [ ] `PUT /users/{uid}` - Update user profile

### Restaurants
- [ ] `GET /restaurants?town={town}&status=active` - Get restaurants by town
- [ ] `GET /restaurants/{id}` - Get restaurant details (stream)
- [ ] `POST /restaurants` - Register new restaurant
- [ ] `PUT /restaurants/{id}` - Update restaurant details
- [ ] `PUT /restaurants/{id}/status` - Update restaurant status (pending/active/rejected)
- [ ] `PUT /restaurants/{id}/online-status` - Toggle online/offline
- [ ] `GET /restaurants/{id}/orders` - Get restaurant's orders (stream)

### Menu Items
- [ ] `GET /restaurants/{restaurantId}/menu` - Get menu items (stream)
- [ ] `POST /restaurants/{restaurantId}/menu` - Add menu item
- [ ] `PUT /restaurants/{restaurantId}/menu/{itemId}` - Update menu item
- [ ] `DELETE /restaurants/{restaurantId}/menu/{itemId}` - Delete menu item

### Orders
- [ ] `POST /orders` - Create new order
- [ ] `GET /orders/{id}` - Get order details (stream)
- [ ] `GET /orders?customerId={id}` - Get customer's orders
- [ ] `GET /orders?restaurantId={id}` - Get restaurant's orders (stream)
- [ ] `GET /orders?town={town}&status=pickup_ready&agentId=null` - Get available orders
- [ ] `PUT /orders/{id}/status` - Update order status
- [ ] `PUT /orders/{id}/agent` - Assign agent to order
- [ ] `PUT /orders/{id}/complete` - Complete delivery with OTP verification

### Agent Management
- [ ] `POST /agents/kyc` - Submit KYC documents
- [ ] `GET /agents/{id}/kyc-status` - Get KYC status (stream)
- [ ] `PUT /agents/{id}/kyc-status` - Update KYC status (admin)
- [ ] `PUT /agents/{id}/online-status` - Toggle agent online/offline
- [ ] `GET /agents/{id}/earnings?period=today|week|month` - Get earnings summary

### Admin
- [ ] `GET /admin/restaurants/pending` - Get pending restaurant approvals
- [ ] `GET /admin/agents/pending` - Get pending agent approvals
- [ ] `PUT /admin/restaurants/{id}/approve` - Approve restaurant
- [ ] `PUT /admin/restaurants/{id}/reject` - Reject restaurant
- [ ] `PUT /admin/agents/{id}/approve` - Approve agent
- [ ] `PUT /admin/agents/{id}/reject` - Reject agent

### File Upload
- [ ] `POST /upload/image` - Upload image file (returns URL)
  - Used for: Restaurant photos, ID verification photos, vehicle documents

---

## Notes for Backend Developer

1. **Real-time Updates**: Use Firestore streams/listeners for:
   - Restaurant status changes
   - Order status updates
   - Agent KYC approvals
   - This ensures UI reflects changes immediately

2. **Authentication**: 
   - Firebase Phone Auth in production
   - Demo mode for testing (6-digit OTP generation)
   - Sessions maintained in UserProvider

3. **Validation**:
   - Phone number: 10 digits, Indian mobile
   - FSSAI: Format validation
   - Bank details: IFSC validation
   - Aadhaar: 12 digits

4. **Error Handling**:
   - Return clear error messages
   - Handle network timeouts (3-second default)
   - Fallback for offline scenarios

5. **Status Flows**:
   - **Restaurant**: pending → active/rejected
   - **Agent KYC**: notSubmitted → pending → approved/rejected
   - **Order**: received → preparing → pickup_ready → delivering → delivered

6. **Image Upload**:
   - Accept Uint8List from Flutter
   - Return URL for storage
   - Compress images before storage
   - Use appropriate storage (Firebase, AWS S3, etc.)

7. **Firestore Collections Structure**:
   ```
   /users/{uid}
   /restaurants/{restaurantId}
      /menu/{itemId}
   /orders/{orderId}
   /agents_kyc/{agentId}
   ```

---

## Testing Checklist

**Frontend Ready to Integrate When Backend Provides:**
- [ ] OTP generation & verification
- [ ] User profile CRUD
- [ ] Restaurant registration & approval flow
- [ ] Menu management (CRUD)
- [ ] Order creation & status updates
- [ ] Agent KYC submission & approval
- [ ] Real-time data streaming
- [ ] Image upload endpoints

---

**Document Version**: 1.0  
**Last Updated**: May 5, 2026  
**Status**: Ready for Backend Integration
