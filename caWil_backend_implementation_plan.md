# CaWil Backend Implementation Plan

**Stack:** Dart Frog + PostgreSQL (with native postgres package, no ORM) + JWT Auth  
**Mobile Client:** Flutter (removing Firebase entirely)  
**Deployment:** Render.com  

---

## A. Project Structure

### caWil_backend / (Dart Frog Server)
- `pubspec.yaml` — dart_frog, postgres, json_annotation, pointycastle, jose_plus, pdf, qr, bcrypt, uuid, mime packages
- `.env` — JWT_SECRET, DB_URL, PORT, CORS_ORIGIN
- `lib/db/database.dart` — PostgreSQL connection pool via postgres package
- `lib/models/` — Plain Dart DTOs for requests/responses (no ORM coupling)

### routes / directory structure (route groups)

Each directory under routes/ becomes a URL prefix group. Each file inside is an endpoint.

| Route Group | URL Prefix | File(s) | Description |
|-------------|------------|---------|-------------|
| Global middleware | — | `_middleware.dart` | CORS, headers, validation |
| **Auth** | `/auth` | `register.dart`, `login.dart`, `refresh.dart`, `me.dart`, `forgot_password.dart`, `reset_password.dart` | Authentication endpoints |
| **Schedules** | `/schedules` | `index.dart`, `[id].dart` | Bus schedule search + admin seat updates |
| **Bookings** | `/bookings` | `index.dart`, `[id].dart`, `[id]/qr.pdf/[name].dart` | Booking creation, details, PDF ticket download |
| **Admin / Buses** | `/admin/buses` | `index.dart`, `[id].dart` | Full bus CRUD for admins |
| **Admin / Routes** | `/admin/routes` | `index.dart`, `[id].dart` | Full route CRUD for admins |

### shared models
Plain Dart DTOs in `lib/models/` can be imported by both the Flutter client and Dart Frog server for shared request/response types.

---

## B. PostgreSQL Database Schema (7 Tables)

The schema lives in `database/schema.sql`. Key design notes:

1. **Users** — email+password auth, role enum (user/admin), optional future uid for social login
2. **Buses** — fleet table, 32 seats fixed (8 rows x 4 cols), active/inactive status
3. **Routes** — origin/destination corridors with base_price reference
4. **Schedules (CORE)** — connects buses to routes; each schedule has its own per-bus custom price denormalized from route; status enum includes 'departed' for lifecycle management
5. **Bookings** — seat reservations with UNIQUE booking_ref (CAW-{YYMMDD}-{4chars}), QR PDF stored as bytea blob, payment_status placeholder
6. **Refresh Tokens** — single-use, UUID jti, revoked_at prevents replay attacks
7. **Admin Logs** — audit trail for all admin actions

---

## C. API Endpoints by Route Group

### /auth/ — Authentication (no auth required unless stated)

| Method | Route | Description | Output |
|--------|-------|-------------|--------|
| POST   | `/auth/register` | Create account: verify email format → hash password with bcrypt → insert user → issue JWT pair + refresh token | `{ user, access_token, refresh_token }` |
| POST   | `/auth/login`    | Verify email+password → lookup user → return JWT pair + refresh token | `{ user, access_token, refresh_token }` |
| POST   | `/auth/refresh`  | Validate refresh token in DB → revoke old (set revoked_at) → issue new JWT pair | `{ access_token, refresh_token }` |
| GET    | `/auth/me`       | Decode JWT, look up user by JTI check → return profile | `{ user }` |
| PUT    | `/auth/me`       | Update current user's username or avatar_url (requires auth) | `{ updated user }` |
| POST   | `/auth/forgot-password` | Generate a 6-digit code → email to user (placeholder: just print code for now) | `{ message: "Code sent to your email" }` |
| POST   | `/auth/reset-password` | Verify code + new password → update user's password_hash in DB | `{ message: "Password updated successfully" }` |

### /schedules/ — Bus Schedule Search

| Method | Route | Description | Output |
|--------|-------|-------------|--------|
| GET    | `/schedules?origin=&destination=&date=+bus_id=` | List schedules filtered by origin, destination, date (YYYY-MM-DD), optionally by bus_id. Each schedule returns **per-bus custom price** from schedule record + full bus info | `[ { schedule, bus_info: { bus_number, total_seats } } ]` |
| GET    | `/schedules/:id` | Single schedule details with full bus information | `{ schedule, bus_info }` |
| PUT    | `/schedules/:id/availability` | Update seats_remaining for a schedule (admin role required) | `{ updated schedule }` |

### /bookings/ — Booking Management

| Method | Route | Description | Output |
|--------|-------|-------------|--------|
| POST   | `/bookings` | Create booking: `SELECT FOR UPDATE` row-lock on schedules → availability check → insert booking + decrement seats_remaining + generate branded PDF QR ticket via pdf package + qr package → save PDF blob to postgres bytea column → return result | `{ booking_ref, id }` + download link for the PDF |
| GET    | `/bookings/:id` | Get booking details (only owner or admin can fetch) | `{ booking, user profile if public }` |
| PUT    | `/bookings/:id/cancel` | Cancel booking + increment seats_remaining back on schedule | `{ status: "cancelled" }` |
| GET    | `/bookings/:id/qr.pdf/[name]` | Serve/download a branded PDF ticket with actual QR code image embedded (binary file download response) | **PDF file** |

### /admin/ — Admin CRUD Routes (all require `role == 'admin'`)

#### /admin/buses/ — Bus Management
| Method | Route | Description | Output |
|--------|-------|-------------|--------|
| GET    | `/admin/buses/` | List all buses in the system | `[ { buses } ]` |
| POST   | `/admin/buses/` | Create new bus: bus_number (unique), plate_number, total_seats(=32), route_type | `{ created bus }` |
| PUT    | `/admin/buses/:id` | Edit bus details: number, plate, seats count, status (active/inactive) | `{ updated bus }` |
| DELETE | `/admin/buses/:id` | Delete bus and cascade its schedules (FK CASCADE) | `{ status: "deleted" }` |

#### /admin/routes/ — Route Management
| Method | Route | Description | Output |  
|--------|-------|-------------|---------|  
| GET    | `/admin/routes/` | List all routes | `[ { routes } ]` |
| POST   | `/admin/routes/` | Create new route: origin → destination, duration_hours, base_price(GHS) | `{ created route }` |
| PUT    | `/admin/routes/:id` | Edit existing route details (origin, dest, duration, price) | `{ updated route }` |
| DELETE | `/admin/routes/:id` | Delete route(s) — schedules cascade too unless guarded | `{ status: "deleted" }` |

---

## D. Token Flow Details

### Access Tokens
- Algorithm: **HMAC-SHA256** (via jose_plus package)  
- Expiration: **1 hour** (3600 seconds)  
- Payload: `{ sub: user_id, email, iat, exp }`  
- Transport: `Authorization: Bearer <token>` header on all protected requests

### Refresh Tokens
- Storage: **refresh_tokens table** in PostgreSQL with expiry date and single-use UUID jti  
- Lifecycle: Single-use only. On each `/auth/refresh`, old token's revoked_at is set (preventing replay). Fresh access + refresh pair returned.

### Password Hashing
- **bcrypt via bcrypt package**  
- Salt rounds: 12

---

## E. Flutter Changes — Remove Firebase → HTTP

### Dependencies Removed (pubspec.yaml)
```yaml
firebase_core        # REMOVE
firebase_auth        # REMOVE
cloud_firestore      # REMOVE
firebase_storage     # REMOVE 
image_picker         # KEEP
hive & hive_flutter  # KEEP
provider             # KEEP
```

### Dependencies Added to pubspec.yaml
```yaml
dio        # HTTP client replacing Firebase calls 
jwt_decoder  # Parsing access token locally (exp check etc.) 
uuid         # Generate UUIDs for local state management
```

### File-by-File Changes 

| Flutter File | What breaks (Firebase) | What it becomes (HTTP/Dio) |
|--------------|------------------------|----------------------------|
| `lib/main.dart` | `await Firebase.initializeApp()` removed; check Hive token presence at startup | Show login on initial load & homepage if valid token found |
| `lib/resources/auth_methods.dart` | FirebaseAuth everywhere — full rewrite with Dio endpoints calling `/auth/register`, `/auth/login`, `/auth/refresh`, `/auth/me` |
| `lib/models/user.dart` | Firestore `fromSnap()` removed; keep only const constructor + toJson |
| `pubspec.yaml` (Firebase deps) | Remove all four Firebase packages as a group |

### Hive Local Caching Boxes (Flutter side) 

| Hive Box Name | What it stores |
|--|--|
| `tokens' box | access_token, refresh_token, expires_at timestamp |
| `schedules' box (optional cache) | Recently fetched schedules for offline fallback |
| `user_profile' box | Recent profile info from `/auth/me` to avoid repeated requests |
| `['config'] box' | api_base_url + last_synced_at |

---

## F. Implementation Order (Phases)

### Phase 1 — Database Setup
- Create `lib/db/database.dart` with PostgreSQL connection pool via postgres package
- Apply SQL migrations from `database/schema.sql` (7 tables) at deploy time
- Define plain Dart DTOs in `lib/models/` for all request/response types

### Phase 2 — Auth Endpoints Implementation
- bcrypt password hashing setup  
- JWT HMAC-SHA256 token pair generation logic + refresh mechanism
- Implement `/auth/register`, `/auth/login`, `/auth/refresh`, `/auth/me` endpoints

### Phase 3 — Admin CRUD Routes
- Full buses CRUD under `admin/buses/` route group for managing fleet inventory
- Full routes CRUD under `admin/routes/` for managing corridor definitions
- Availability update endpoint on schedules allowing admins to modify remaining seat counts dynamically

### Phase 4 — Schedule Search Endpoint
- GET /schedules with filtering by origin, destination and/or date query parameters
- Each schedule returns **per-bus custom pricing** from the schedule record (not route base_price)

### Phase 5 — Bookings Core Flow  
- POST /bookings: `SELECT FOR UPDATE` row-lock on schedules to prevent double-booking → insert booking + decrement seats_remaining
- Generate QR code server-side via qr package, embed into branded PDF ticket via pdf package, save as postgres bytea blob
- GET/PUT booking endpoints with owner/admin access control

### Phase 6 — Flutter Wiring
- Remove all four Firebase dependencies from Flutter pubspec.yaml, add dio + jwt_decoder
- Wire up Dio interceptors: automatic Bearer token attachment + automatic refresh on 401 responses
- Update auth flow to call HTTP endpoints instead of FirebaseAuth

---

## G. Branded PDF Ticket

### Packages Used 
- `pdf` package — layout + styling with app's deepBlue (#0a1853) and Purple accent (#6a1b9a) palette  
- `qr` package — generates scannable QR code images containing booking reference string

---

## H. Deployment to Render.com 

### Dart Frog Server 
Deployed via Render's [Custom Service](https://render.com/docs/blueprint-spec#custom-service):
1. Command: `dartfrog serve --environment production`
2. Port configurable via PORT environment variable (set by Render automatically)
3. PostgreSQL via render.io paid PostgreSQL add-on
4. Environment Variables: JWT_SECRET, DB_CONNECTION_STRING, CORS_ALLOWED_ORIGIN

---

## I. Key Decisions Made During Planning  

1. **Full JWT authentication.** Firebase completely removed from both Flutter app and backend
2. **Dart Frog + PostgreSQL with native postgres package.** No ORM — direct SQL via postgres driver
3. **Per-bus custom pricing stored in schedules table.** Each schedule has its own price for flexible pricing
4. **Admin routes built during core development.** So you can populate data immediately after deployment
5. **QR code images generated server-side and embedded in branded PDF tickets.** Actual scannable QR with app's deep-blue/purple/green palette  
6. **Hive as Flutter local store.** Tokens + optional schedule data for offline access
7. **Separate route groups per directory under routes/.** Each directory = URL prefix group

---

## Next Steps
1. Create `lib/db/database.dart` with postgres connection pool
2. Define plain Dart DTOs in `lib/models/`
3. Implement auth endpoints (register/login/refresh/me) + JWT middleware
4. Implement admin CRUD routes for buses and routes
5. Build schedule search + booking flow with seat hold mechanics
6. Implement PDF ticket generation endpoint
7. Wire up Flutter app to HTTP
