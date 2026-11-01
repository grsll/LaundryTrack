# Pembahasan Tugas: Phase 1 - Autentikasi & Fondasi Multi-Tenancy LaundryTrack

- **Tanggal**: 2026-11-01
- **Status**: Selesai & Terverifikasi Penuh
- **Target Database**: PostgreSQL 16 pada VPS (`45.66.153.146:5432 / laundrytrack_db`)

---

## 1. Ringkasan Tugas & Konteks

Mengimplementasikan seluruh fondasi arsitektur **Phase 1: Authentication & Multi-Tenancy** untuk aplikasi SaaS LaundryTrack sesuai spesifikasi PRD v1.0. 
Fokus fase ini adalah menjamin pemisahan data antar tenant (*strict tenant isolation*), sistem autentikasi modern berbasis token JWT dengan rotasi single-use Refresh Token, hashing kata sandi Argon2id, onboarding pendaftaran bisnis secara atomik, serta antarmuka Flutter Web terintegrasi penuh.

### Ruang Lingkup Deliverables
1. **Model & Migrasi Database VPS**:
   - Tabel `tenants`, `outlets`, `users`, `tenant_users`, `outlet_users`, `subscriptions`, dan `refresh_tokens`.
   - Penerapan migrasi Alembic `1f810c0418be` dan `486e0e21a7e1` langsung pada database VPS PostgreSQL `laundrytrack_db`.
2. **Backend FastAPI Modular Monolith**:
   - `core/security.py`: Argon2id password hashing, SHA-256 token hashing, JWT access token generation & decode.
   - `core/dependencies.py`: Dependency injection untuk memvalidasi `current_user`, `current_tenant`, `current_outlet`, dan RBAC role checks.
   - `modules/auth/service.py`: Logika registrasi onboarding atomik, dual-login (email / nomor telepon WhatsApp), rotasi Refresh Token dengan `with_for_update()`, dummy Argon2id hash untuk pencegahan timing attack.
   - `modules/auth/router.py`: Endpoints `/register`, `/login`, `/refresh`, `/logout`, `/me`.
3. **Frontend Flutter Web (Riverpod v2 + GoRouter + Dio)**:
   - Form Login & Registrasi Bisnis responsive (Material 3).
   - Layar Dashboard berorientasi multi-outlet dengan indikator sesi terisolasi.
   - Guard navigasi GoRouter dengan `RouterNotifier` dan `refreshListenable`.
   - Keamanan `Dio` interseptor (pembersihan log kredensial pada console).
4. **Verifikasi & Quality Gate**:
   - 20 skenario backend test suite (`pytest`) lulus 100%.
   - 12 skenario frontend test suite (`flutter test`) lulus 100% termasuk uji responsive mobile viewport (`390x844`).
   - Kompilasi release Flutter Web (`flutter build web`) sukses tanpa error.

---

## 2. Alur Analisis / Root Cause

Selama proses implementasi dan audit multi-agent (`test-engineer`, `security-auditor`, `code-reviewer`), ditemukan beberapa tantangan teknis:

1. **Race Condition pada Token Refresh (Replay Attack Risk)**:
   - *Analisis*: Jika dua permintaan refresh token datang bersamaan dalam latensi jaringan milidetik, ada risiko kedua token dianggap valid sebelum flag `is_revoked` tersimpan.
   - *Solusi*: Menggunakan `with_for_update()` pada query seleksi RefreshToken di PostgreSQL, memastikan row terkunci secara eksklusif selama transaksi rotasi token berlangsung.
2. **Potensi User Enumeration via Timing Attack**:
   - *Analisis*: Memverifikasi password dengan Argon2id membutuhkan waktu komputasi ~50-100ms. Jika pengecekan email/telepon yang tidak ditemukan langsung mengembalikan error 401 tanpa hashing, penyerang dapat membedakan akun yang terdaftar vs tidak terdaftar berdasarkan selisih waktu respons.
   - *Solusi*: Membuat pre-computed `DUMMY_ARGON2_HASH` dan tetap menjalankan `verify_password(payload.password, target_hash)` meskipun user tidak ditemukan di database.
3. **Pemisahan Sesi Multi-Tenant pada RefreshToken**:
   - *Analisis*: Pengguna yang memiliki akun di beberapa bisnis laundry dapat memicu ambiguitas saat melakukan refresh token jika token tidak mengikat `tenant_id`.
   - *Solusi*: Menambahkan kolom `tenant_id` dan indeks unik pada tabel `refresh_tokens`, serta menerapkan migrasi `486e0e21a7e1` pada database VPS.
4. **Re-Instansiasi GoRouter pada State Riverpod**:
   - *Analisis*: Pemanggilan `ref.watch(authProvider)` di dalam definisi `routerProvider` menyebabkan instance `GoRouter` dihancurkan dan dibuat ulang setiap kali state autentikasi berganti.
   - *Solusi*: Mengadopsi pola `RouterNotifier` yang mengimplementasikan `ChangeNotifier` dan dihubungkan ke `GoRouter` via `refreshListenable`.
5. **RenderFlex Overflow pada Viewport Mobile (Ahem Test Font)**:
   - *Analisis*: Pada layar mobile sempit (`390px`), header brand `LaundryTrack` mengalami overflow horizontal karena kombinasi padding statis dan test font monospace Ahem yang lebar.
   - *Solusi*: Membungkus brand row dengan `FittedBox(fit: BoxFit.scaleDown)` dan menyesuaikan padding kartu secara responsif.

---

## 3. Logika Kode & Solusi

### A. Strict Tenant Context Resolution (`backend/app/core/dependencies.py`)
Setiap request ke endpoint yang memerlukan otorisasi wajib melewati dependency chain berikut:
```text
HTTP Request (Header: Authorization: Bearer <JWT>)
  │
  ▼
get_current_user:
  - Decode & verify JWT signature (HS256)
  - Validasi klaim 'sub' (User UUID)
  - Query User dari DB: pastikan is_active == True
  │
  ▼
get_current_tenant:
  - Ekstrak 'tenant_id' dari klaim JWT (bukan dari input request body / query param)
  - Validasi asosiasi TenantUser: pastikan relasi aktif dan tenant is_active == True
  │
  ▼
get_current_outlet:
  - Ekstrak 'outlet_id' dari klaim JWT
  - Validasi bahwa outlet milik tenant yang terverifikasi (Outlet.tenant_id == Tenant.id)
  │
  ▼
Execution Router / Service Logic
```

### B. Transaksi Atomik Onboarding Registrasi (`backend/app/modules/auth/service.py`)
Dalam satu transaksi database (`await self.db.commit()`):
1. Pengecekan duplikasi `email` dan `phone`.
2. Pembuatan slug tenant unik (`slugify(business_name)` dengan fallback `-<hex>` bila terjadi tabrakan).
3. Pembuatan `User` (password di-hash dengan Argon2id via `pwdlib`).
4. Pembuatan `Tenant`.
5. Pembuatan `Outlet` pertama ("Outlet Utama").
6. Asosiasi `TenantUser` dengan role `owner`.
7. Asosiasi `OutletUser` untuk akses outlet.
8. Pembuatan `Subscription` paket `free` berstatus `active`.
9. Pembuatan single-use `RefreshToken` (di-hash menggunakan SHA-256 sebelum disimpan ke DB).
10. Penerbitan sepasang Access Token (JWT) dan Refresh Token transparan ke client.

---

## 4. Berkas yang Berubah / Dibuat

| Direktori / Berkas | Status | Deskripsi |
| :--- | :--- | :--- |
| `backend/app/core/security.py` | Dibuat | Modul Argon2id hashing, SHA-256 token hashing, JWT encoder/decoder |
| `backend/app/core/dependencies.py` | Diperbarui | Dependency `get_current_user`, `get_current_tenant`, `get_current_outlet`, `require_roles` |
| `backend/app/modules/auth/` | Dibuat | Domain auth: `models.py`, `schemas.py`, `service.py`, `router.py` |
| `backend/app/modules/tenants/models.py` | Dibuat | Model entitas `Tenant` |
| `backend/app/modules/outlets/models.py` | Dibuat | Model entitas `Outlet` |
| `backend/app/modules/users/models.py` | Dibuat | Model entitas `User`, `TenantUser`, `OutletUser`, enum `UserRole`, `UserType` |
| `backend/app/modules/subscriptions/models.py` | Dibuat | Model entitas `Subscription` |
| `backend/migrations/versions/1f810c0418be_...` | Dibuat | Migrasi baseline tabel auth & multi-tenancy pada VPS |
| `backend/migrations/versions/486e0e21a7e1_...` | Dibuat | Migrasi penambahan kolom `tenant_id` dan indeks unik pada `refresh_tokens` |
| `backend/tests/test_auth.py` | Dibuat | 10 skenario pengujian auth (register, duplicate check, dual-login, refresh rotation, logout, me, slug deduplication, inactive user) |
| `backend/tests/test_tenant_isolation.py` | Dibuat | 3 skenario isolasi tenant dan validasi token JWT tamper-proof |
| `frontend/lib/core/network/auth_interceptor.dart` | Dibuat | Interseptor Dio untuk injeksi Bearer token dan penyimpanan token aman |
| `frontend/lib/core/network/api_client.dart` | Diperbarui | Pencegahan kebocoran logging kredensial |
| `frontend/lib/core/router/app_router.dart` | Diperbarui | Navigasi GoRouter dengan `RouterNotifier` dan `refreshListenable` |
| `frontend/lib/features/auth/` | Dibuat | Fitur Auth: `data/`, `presentation/login_screen.dart`, `register_screen.dart`, `providers/` |
| `frontend/lib/features/dashboard/presentation/dashboard_screen.dart` | Dibuat | UI Dashboard multi-outlet responsif |
| `frontend/test/auth_flow_test.dart` | Dibuat | 5 unit & widget test auth Flutter termasuk uji responsive mobile |

---

## 5. Bukti Verifikasi

### A. Pengujian Backend (`pytest -v`)
```text
tests/test_auth.py::test_register_business_success PASSED                [  5%]
tests/test_auth.py::test_register_business_duplicate_email PASSED        [ 10%]
tests/test_auth.py::test_register_business_duplicate_phone PASSED        [ 15%]
tests/test_auth.py::test_login_success_with_email_and_phone PASSED       [ 20%]
tests/test_auth.py::test_login_invalid_credentials PASSED                [ 25%]
tests/test_auth.py::test_refresh_token_rotation_and_revocation PASSED    [ 30%]
tests/test_auth.py::test_logout_revokes_session PASSED                   [ 35%]
tests/test_auth.py::test_get_me_authenticated_endpoint PASSED            [ 40%]
tests/test_auth.py::test_tenant_slug_collision_deduplication PASSED      [ 45%]
tests/test_auth.py::test_inactive_user_login_rejected PASSED             [ 50%]
tests/test_health.py::test_root_endpoint_metadata_and_headers PASSED     [ 55%]
tests/test_health.py::test_health_endpoint_unit_success PASSED           [ 60%]
tests/test_health.py::test_health_endpoint_live_vps_connection PASSED    [ 65%]
tests/test_health.py::test_health_endpoint_database_degraded PASSED      [ 70%]
tests/test_health.py::test_app_exception_standard_format PASSED          [ 75%]
tests/test_health.py::test_check_db_health_success_probe PASSED          [ 80%]
tests/test_health.py::test_check_db_health_exception_handled PASSED      [ 85%]
tests/test_tenant_isolation.py::test_tenant_context_isolation_between_separate_tenants PASSED [ 90%]
tests/test_tenant_isolation.py::test_forged_or_tampered_jwt_rejected PASSED [ 95%]
tests/test_tenant_isolation.py::test_unauthenticated_request_rejected PASSED [100%]

======================== 20 passed, 1 warning in 27.97s ========================
```

### B. Pengujian Frontend (`flutter test`)
```text
00:02 +12: All tests passed!
```

### C. Kompilasi Produksi Frontend (`flutter build web --release`)
```text
Compiling lib/main.dart for the Web...                             67.8s
✓ Built build/web
```

### D. Status Database VPS PostgreSQL
```text
INFO  [alembic.runtime.migration] Context impl PostgresqlImpl.
INFO  [alembic.runtime.migration] Will assume transactional DDL.
INFO  [alembic.runtime.migration] Running upgrade 1f810c0418be -> 486e0e21a7e1, add_tenant_id_to_refresh_tokens
```

---

## 6. Catatan Pola Reusable untuk Fase Berikutnya

1. **Pola Tenant-Scoped Query**:
   Pada modul berikutnya (Phase 2: Customers & Services), seluruh query wajib menyertakan filter `tenant_id`:
   ```python
   stmt = select(Customer).where(Customer.tenant_id == current_tenant.id)
   ```
   Jangan pernah menerima `tenant_id` dari payload input client.
2. **Pola Locking untuk Transaksi Finansial & Stok**:
   Gunakan `.with_for_update()` pada PostgreSQL saat memproses transaksi pembayaran atau nomor urut nota untuk mencegah nomor ganda (*race condition*).
3. **Pola UI Form & Card Responsif**:
   Pada antarmuka Flutter Web berikutnya, selalu bungkus widget header atau baris teks dalam `FittedBox(fit: BoxFit.scaleDown)` atau `Wrap`, dan terapkan padding adaptif berbasis `LayoutBuilder` untuk mendukung perangkat kasir mobile/tablet.
