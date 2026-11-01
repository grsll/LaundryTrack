# Design Specification: Phase 1 — Auth & Multi-Tenancy (LaundryTrack)

**Tanggal:** 1 November 2026  
**Status:** In Progress / Implementation  
**Tujuan:** Menyediakan sistem otentikasi bisnis (registrasi atomik), isolasi multi-tenant yang ketat, manajemen role berbasis RBAC, JWT access & refresh token dengan rotasi/revocation, serta antarmuka Flutter Web untuk Login dan Registrasi Bisnis.

---

## 1. Arsitektur Multi-Tenancy & Prinsip Keamanan

1. **Strict Backend Tenant Isolation:**
   - Client dilarang keras menentukan `tenant_id` secara sepihak melalui body atau query parameter.
   - Backend menyelesaikan `tenant_id` aktif secara otoritatif dari JWT Access Token yang telah diverifikasi (`get_current_tenant`).
   - Setiap query data bisnis di masa depan wajib memfilter dengan `tenant_id == current_user.tenant_id`.
2. **Atomic Registration Transaction:**
   - Registrasi bisnis membuat 6 entitas dalam satu database transaction yang bersifat atomik:
     1. `User` (Kredensial staf)
     2. `Tenant` (Bisnis laundry)
     3. `Outlet` (Outlet utama/default)
     4. `TenantUser` (Keanggotaan role `owner`)
     5. `OutletUser` (Penugasan staf ke outlet utama)
     6. `Subscription` (Paket `free` status `active`)
   - Jika terjadi kegagalan (misal email/phone sudah terdaftar), seluruh transaksi dibatalkan (*rollback*) tanpa meninggalkan data parsial (*orphan records*).
3. **Token Management & Security:**
   - Password di-hash menggunakan **Argon2id** (atau bcrypt).
   - Access Token JWT berumur pendek (30 menit) memuat `sub` (user_id), `tenant_id`, `outlet_id`, `role`.
   - Refresh Token disimpan di database dalam bentuk **SHA-256 hash** (`refresh_tokens`), dengan mekanisme rotasi (refresh token lama di-revoke saat refresh token baru diterbitkan).
   - Endpoint logout mencabut (*revoke*) refresh token aktif.

---

## 2. Skema Database (Data Modeling)

Semua tabel menggunakan `Base` dari `app.shared.models` (`UUIDMixin`, `TimestampMixin`).

```text
tenants
  ├── id (UUID PK)
  ├── name (VARCHAR(150))
  ├── slug (VARCHAR(160) UNIQUE)
  ├── is_active (BOOLEAN default true)
  └── created_at, updated_at

outlets
  ├── id (UUID PK)
  ├── tenant_id (UUID FK -> tenants.id)
  ├── name (VARCHAR(150))
  ├── address (TEXT NULL)
  ├── phone (VARCHAR(30) NULL)
  ├── is_active (BOOLEAN default true)
  └── created_at, updated_at

users
  ├── id (UUID PK)
  ├── email (VARCHAR(255) UNIQUE)
  ├── phone (VARCHAR(50) UNIQUE)
  ├── full_name (VARCHAR(150))
  ├── hashed_password (VARCHAR(255))
  ├── user_type (VARCHAR(20) default 'staff') # 'staff' | 'customer'
  ├── is_active (BOOLEAN default true)
  ├── is_verified (BOOLEAN default false)
  └── created_at, updated_at

tenant_users
  ├── id (UUID PK)
  ├── tenant_id (UUID FK -> tenants.id)
  ├── user_id (UUID FK -> users.id)
  ├── role (VARCHAR(30)) # 'owner' | 'admin' | 'cashier' | 'operator'
  ├── is_active (BOOLEAN default true)
  ├── created_at, updated_at
  └── UNIQUE (tenant_id, user_id)

outlet_users
  ├── id (UUID PK)
  ├── outlet_id (UUID FK -> outlets.id)
  ├── user_id (UUID FK -> users.id)
  ├── created_at, updated_at
  └── UNIQUE (outlet_id, user_id)

subscriptions
  ├── id (UUID PK)
  ├── tenant_id (UUID FK -> tenants.id UNIQUE)
  ├── plan (VARCHAR(30) default 'free') # 'free' | 'starter' | 'business'
  ├── status (VARCHAR(30) default 'active') # 'active' | 'expired' | 'cancelled'
  ├── expires_at (DATETIME NULL)
  └── created_at, updated_at

refresh_tokens
  ├── id (UUID PK)
  ├── user_id (UUID FK -> users.id)
  ├── token_hash (VARCHAR(255) INDEX)
  ├── is_revoked (BOOLEAN default false)
  ├── expires_at (DATETIME)
  └── created_at, updated_at
```

---

## 3. Kontrak API (`/api/v1/auth`)

### 3.1 `POST /api/v1/auth/register`
- **Request Body:**
  ```json
  {
    "full_name": "Budi Laundry",
    "email": "budi@example.com",
    "phone": "081234567890",
    "password": "Password123!",
    "business_name": "Berkah Laundry Clean",
    "outlet_name": "Outlet Pusat",
    "outlet_address": "Jl. Mawar No. 10, Jakarta",
    "outlet_phone": "081234567890"
  }
  ```
- **Response 201 Created:**
  ```json
  {
    "success": true,
    "data": {
      "user": {
        "id": "uuid",
        "full_name": "Budi Laundry",
        "email": "budi@example.com",
        "phone": "081234567890",
        "role": "owner"
      },
      "tenant": {
        "id": "uuid",
        "name": "Berkah Laundry Clean",
        "slug": "berkah-laundry-clean"
      },
      "outlet": {
        "id": "uuid",
        "name": "Outlet Pusat"
      },
      "subscription": {
        "plan": "free",
        "status": "active"
      },
      "tokens": {
        "access_token": "jwt...",
        "refresh_token": "token...",
        "token_type": "bearer",
        "expires_in": 1800
      }
    }
  }
  ```

### 3.2 `POST /api/v1/auth/login`
- **Request Body:**
  ```json
  {
    "email_or_phone": "budi@example.com",
    "password": "Password123!"
  }
  ```
- **Response 200 OK:**
  Struktur response identik dengan register data.

### 3.3 `POST /api/v1/auth/refresh`
- **Request Body:** `{"refresh_token": "..."}`
- **Response 200 OK:** Token baru (`access_token` dan `refresh_token` terotasi).

### 3.4 `POST /api/v1/auth/logout`
- **Request Body:** `{"refresh_token": "..."}`
- **Response 200 OK:** `{"success": true, "message": "Berhasil logout."}`

### 3.5 `GET /api/v1/auth/me`
- **Headers:** `Authorization: Bearer <token>`
- **Response 200 OK:** Profil pengguna, data tenant aktif, outlet aktif, role, dan hak akses.

---

## 4. Frontend Flutter Web (Auth Flow)

1. **State Management:**
   - `authProvider`: StateNotifier menyimpan status `unauthenticated`, `authenticating`, `authenticated(AuthData)`.
   - Menggunakan `shared_preferences` atau in-memory session token storage untuk menyimpan access token dan refresh token.
2. **Routing & Guards (GoRouter):**
   - Rute publik: `/login`, `/register`, `/health`
   - Rute privat: `/dashboard` (redirect ke `/login` jika belum authenticated).
3. **Screens:**
   - `LoginScreen`: Form login email/phone + password dengan validasi input, loading state, error alert, dan link ke register.
   - `RegisterBusinessScreen`: Form pendaftaran pemilik laundry & outlet pertama dengan preview ringkasan paket Free.
   - `DashboardPlaceholderScreen`: Layar pembuka setelah login sukses menampilkan nama bisnis, nama user, role, dan tombol logout.

---

## 5. Acceptance Criteria Phase 1

- [ ] Seluruh tabel database (`tenants`, `outlets`, `users`, `tenant_users`, `outlet_users`, `subscriptions`, `refresh_tokens`) terdefinisi di model ORM dan bermigrasi ke VPS PostgreSQL via Alembic.
- [ ] Registrasi bisnis dieksekusi secara atomik dalam satu DB transaction.
- [ ] Pengujian membuktikan: jika pendaftaran gagal di tengah alur, tidak ada entitas parsial yang tertinggal di DB.
- [ ] Staf dapat login dengan email atau nomor telepon yang valid.
- [ ] Refresh token mendukung rotasi dan revocation saat logout.
- [ ] Security test membuktikan bahwa user tenant A tidak dapat membaca/mengakses endpoint tenant B (IDOR & cross-tenant access blocked).
- [ ] Frontend Flutter Web menyediakan alur Login, Register, Logout, dan dashboard guard yang terhubung ke backend.
