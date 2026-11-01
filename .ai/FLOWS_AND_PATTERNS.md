# LaundryTrack Architecture Flows & Design Patterns

Dokumen ini memetakan standar arsitektur dan pola eksekusi yang wajib dipatuhi di seluruh modul LaundryTrack.

---

## 1. Alur Eksekusi Baku (Standard Execution Flow)

Setiap endpoint API harus menerapkan 5 tahap eksekusi linier:

```text
[HTTP Request]
       │
       ▼
1. Entry Point (Router / Controller)
       │ Menerima request HTTP, dependency injection (DB session, current user)
       ▼
2. Validasi Input (Pydantic Schema)
       │ Memvalidasi payload, tipe data, range, format nomor HP, dll.
       ▼
3. Business Logic (Service Layer)
       │ Validasi aturan bisnis, cek tenant isolation, kalkulasi (Decimal), orkestrasi
       ▼
4. ORM / Persistence Layer (SQLAlchemy 2.0 Repository)
       │ Atomic transaction, queries with tenant_id filter, snapshotting
       ▼
5. Output Serialization (Pydantic Response Schema)
       │ Masking data sensitif, format datetime UTC, standard JSON structure
       ▼
[HTTP Response 2xx / 4xx / 5xx]
```

---

## 2. Pola Multi-Tenancy & Tenant Isolation

1. **Prinsip Utama:** Tenant aktif selalu diperoleh dari JWT token yang telah diverifikasi di backend, bukan dari query parameter atau body request yang dikirimkan oleh client.
2. **Repository Scope:**
   ```python
   # Pola Query Wajib
   stmt = select(Order).where(
       Order.tenant_id == current_user.tenant_id,
       Order.id == order_id
   )
   ```
3. **Cross-Tenant Prevention:**
   Setiap foreign entity yang dihubungkan ke transaksi (misal `customer_id`, `service_id`) harus diverifikasi bahwa `entity.tenant_id == current_user.tenant_id`.

---

## 3. Pola Database & ORM (SQLAlchemy 2.0 Async)

1. **Model Declarative Base:**
   Menggunakan `DeclarativeBase` dengan mixin:
   - `UUIDMixin`: Primary key `UUIDv4`.
   - `TimestampMixin`: `created_at` dan `updated_at` timezone-aware UTC.
2. **Kalkulasi Keuangan:**
   - Database: `sa.Numeric(precision=12, scale=2)`
   - Python: `from decimal import Decimal`
   - Dilarang keras menggunakan tipe `float` untuk harga, diskon, subtotal, atau pembayaran.
3. **Snapshot Pattern pada Transaksi:**
   Data referensi yang nilainya dapat berubah di masa depan (misal harga layanan pada `services`) **wajib di-snapshot** ke dalam `order_items`:
   - `service_name_snapshot`
   - `unit_price_snapshot`
   - `price_type_snapshot`
   - `quantity`
   - `subtotal`

---

## 4. Pola Response & Penanganan Error

1. **Standard Success Response:**
   Endpoint RESTful mengembalikan objek domain atau list terpaginasi:
   ```json
   {
     "success": true,
     "data": { ... },
     "meta": {
       "page": 1,
       "page_size": 20,
       "total": 100
     }
   }
   ```
2. **Standard Error Response:**
   ```json
   {
     "success": false,
     "error": {
       "code": "ENTITY_NOT_FOUND",
       "message": "Pelanggan tidak ditemukan atau bukan milik tenant Anda.",
       "details": []
     }
   }
   ```

---

## 5. Pola Frontend (Flutter Web)

1. **Arsitektur Modul:**
   - `core/`: Utilitas bersama (API client, token storage, router, theme).
   - `features/<feature_name>/`:
     - `data/`: Model serialisasi JSON & API datasource.
     - `providers/`: Riverpod state notifiers.
     - `presentation/`: Layar dan widget UI Material 3.
2. **Intersepsi Error:**
   Dio interceptor menangani token refresh, error 401 redirect ke login, dan standard snackbar notification.
