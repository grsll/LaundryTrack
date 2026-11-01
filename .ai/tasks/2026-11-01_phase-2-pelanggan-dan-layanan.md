# Pembahasan Tugas: Phase 2 - Manajemen Pelanggan & Katalog Layanan Laundry

- **Tanggal**: 2026-11-01
- **Status**: Selesai & Terverifikasi Penuh
- **Target Database**: PostgreSQL 16 pada VPS (`45.66.153.146:5432 / laundrytrack_db`)

---

## 1. Ringkasan Tugas & Konteks

Mengimplementasikan seluruh kebutuhan operasional **Phase 2: Customer & Service Management** untuk LaundryTrack sesuai PRD v1.0.
Fokus fase ini adalah menyediakan data master yang esensial sebelum pencatatan transaksi pesanan (Phase 3):
1. **Modul Pelanggan (`customers`)**:
   - Pencatatan pelanggan per tenant: nama, nomor WhatsApp/telepon, email, alamat penjemputan/domisili, dan catatan preferensi laundry.
   - Pencarian instan berdasarkan nama atau nomor telepon dengan indeks komposit.
   - Kebijakan soft delete / pengarsipan (`is_active = False`) agar riwayat transaksi dan jejak audit masa depan tidak pernah terputus.
2. **Modul Layanan (`services`)**:
   - Katalog tarif laundry per tenant dengan model penetapan harga kiloan (`per_kg`) dan satuan (`per_item`).
   - Penetapan harga presisi moneter `Numeric(12, 2)` (Python `Decimal`) dengan batasan positif dan pencegahan numeric overflow.
   - Estimasi durasi pengerjaan dalam jam untuk dasar perhitungan batas waktu pesanan (Phase 3).
   - Otorisasi ketat: pembuatan, pengubahan, dan pengarsipan tarif layanan hanya dapat dilakukan oleh role `owner` dan `admin`.
3. **Frontend UI Flutter Web (Riverpod v2 + GoRouter)**:
   - Antarmuka manajemen pelanggan (`CustomerListScreen`, `CustomerFormDialog`) lengkap dengan pencarian, penanganan nomor telepon, dan dialog form asinkron.
   - Antarmuka katalog layanan (`ServiceListScreen`, `ServiceFormDialog`) dengan filter chip Kiloan vs Satuan yang responsif (`Wrap`).
   - Quick action cards pada `DashboardScreen` untuk akses cepat operasional kasir.

---

## 2. Alur Analisis / Root Cause

Melalui protokol pengujian otomatis dan delegasi subagent (`test-engineer`, `security-auditor`, `code-reviewer`), ditemukan beberapa potensi celah yang berhasil diatasi:

1. **Broken Function Level Authorization (BFLA) pada Mutasi Tarif Layanan**:
   - *Akar Masalah*: Jika rute pembuatan dan perubahan tarif layanan hanya memvalidasi sesi tanpa memeriksa role, kasir atau operator dapat mengubah harga layanan sebelum menginput pesanan.
   - *Solusi*: Memasang dependency `require_roles("owner", "admin")` pada rute `POST`, `PATCH`, dan `DELETE` di `services/router.py` serta `DELETE` di `customers/router.py`.
2. **Wildcard Injection & ReDoS pada Parameter Pencarian `q`**:
   - *Akar Masalah*: Penggunaan karakter wildcard SQL (`%`, `_`) pada string pencarian `ILIKE` dapat mencocokkan seluruh baris atau membebani CPU database.
   - *Solusi*: Mengimplementasikan escaping karakter `\`, `%`, dan `_` pada query service layer, serta membatasi panjang query parameter `max_length=100`.
3. **Numeric Overflow pada Validasi Harga**:
   - *Akar Masalah*: Database `Numeric(12, 2)` memiliki batas nilai maksimum `9,999,999,999.99`. Input tak terbatas dari schema dapat memicu error internal 500 di PostgreSQL.
   - *Solusi*: Menambahkan batas atas `le=Decimal("999999999.99")` pada Pydantic schema `ServiceBase` dan `ServiceUpdate`.
4. **Kehilangan Input Form jika Request Gagal (Synchronous Pop)**:
   - *Akar Masalah*: Pada antarmuka Flutter, menutup dialog form secara synchronous sebelum proses HTTP async selesai menyebabkan teks yang telah diketik user hilang jika terjadi error validasi atau timeout.
   - *Solusi*: Menjadikan callback `onSave` bertipe `Future<bool>`, menampilkan indikator loading saat submit, dan menutup dialog hanya jika request berhasil (`if (success && mounted) Navigator.pop()`).
5. **RenderFlex Overflow pada Filter Chips Mobile Viewport**:
   - *Akar Masalah*: Penggunaan horizontal `Row` untuk 3 filter chip pada layar smartphone sempit (`358px`) menyebabkan overflow.
   - *Solusi*: Mengganti `Row` dengan `Wrap(spacing: 8, runSpacing: 6)` yang otomatis membungkus chip ke baris kedua secara elegan.

---

## 3. Logika Kode & Solusi

### A. Strict Tenant-Scoped Execution Flow
Setiap request ke modul Pelanggan dan Layanan menerapkan 5 tahap eksekusi linier:
```text
HTTP Request (Header: Authorization: Bearer <JWT>)
  │
  ▼
1. Router & Dependency Injection:
   - get_current_user: decode JWT & load staff user
   - get_current_tenant: verifikasi relasi TenantUser aktif
   - require_roles("owner", "admin"): proteksi mutasi master data
  │
  ▼
2. Validasi Schema (Pydantic v2):
   - Customer: sanitasi teks, strip whitespace nomor HP
   - Service: validasi Decimal gt=0 & le=999jt, unit min_length=1, enum PriceType
  │
  ▼
3. Service Layer Logic:
   - Escaping wildcard ILIKE (% dan _)
   - Filter ketat: Customer.tenant_id == current_tenant.id
   - Soft-delete pattern: is_active = False
  │
  ▼
4. ORM & DB Persistence (PostgreSQL 16):
   - Composite indexes: (tenant_id, is_active), (tenant_id, phone)
   - Database commit & refresh
  │
  ▼
5. Output Serialization:
   - PaginatedResponse[CustomerResponse] & StandardResponse[ServiceResponse]
```

---

## 4. Berkas yang Berubah / Dibuat

| Direktori / Berkas | Status | Deskripsi |
| :--- | :--- | :--- |
| `backend/app/modules/customers/` | Dibuat | Entitas pelanggan: `models.py`, `schemas.py`, `service.py`, `router.py` |
| `backend/app/modules/services/` | Dibuat | Entitas layanan: `models.py`, `schemas.py`, `service.py`, `router.py` |
| `backend/app/shared/schemas.py` | Dibuat | Skema standar `PaginatedResponse`, `PaginationMeta`, `StandardResponse` |
| `backend/app/modules/tenants/models.py` | Diperbarui | Relasi ORM `customers` dan `services` pada model `Tenant` |
| `backend/migrations/versions/8aa413a1cf94_...` | Dibuat | Migrasi pembuatan tabel `customers` dan `services` di VPS PostgreSQL |
| `backend/tests/test_customers.py` | Dibuat | 9 skenario pengujian customer (CRUD, search, wildcard, phone collision, active filter, IDOR list & subresource) |
| `backend/tests/test_services.py` | Dibuat | 9 skenario pengujian service (kiloan/satuan, decimal, negative price, role RBAC, price type filter, IDOR isolation) |
| `frontend/lib/features/customers/` | Dibuat | Feature pelanggan: `customer_model.dart`, `customer_repository.dart`, `customer_provider.dart`, `customer_list_screen.dart`, `customer_form_dialog.dart` |
| `frontend/lib/features/services/` | Dibuat | Feature layanan: `service_model.dart`, `service_repository.dart`, `service_provider.dart`, `service_list_screen.dart`, `service_form_dialog.dart` |
| `frontend/lib/features/dashboard/presentation/dashboard_screen.dart` | Diperbarui | Quick Action Cards navigasi langsung ke Pelanggan dan Layanan |
| `frontend/lib/core/router/app_router.dart` | Diperbarui | Pendaftaran rute `/customers` dan `/services` |
| `frontend/test/customer_service_flow_test.dart` | Dibuat | 10 unit & widget test Flutter untuk model, form dialog interaktif, dan mobile responsive |

---

## 5. Bukti Verifikasi

### A. Pengujian Backend (`pytest -v`)
```text
tests/test_auth.py (10 tests) ........................................ PASSED
tests/test_customers.py (9 tests):
  - test_create_and_get_customer_success ............................ PASSED
  - test_list_and_search_customers .................................. PASSED
  - test_update_and_archive_customer ................................ PASSED
  - test_customer_summary_and_orders_baseline ....................... PASSED
  - test_customer_cross_tenant_isolation_idor_prevention ............ PASSED
  - test_customer_search_with_wildcards_and_whitespace_trimming ..... PASSED
  - test_customer_duplicate_phone_in_same_and_different_tenants ..... PASSED
  - test_customer_active_inactive_filters_and_reactivation .......... PASSED
  - test_customer_idor_subresources_and_list_isolation .............. PASSED
tests/test_health.py (7 tests) ....................................... PASSED
tests/test_services.py (9 tests):
  - test_create_and_get_service_kiloan_and_satuan ................... PASSED
  - test_service_price_validation_must_be_positive .................. PASSED
  - test_list_and_filter_services ................................... PASSED
  - test_update_and_archive_service ................................. PASSED
  - test_service_cross_tenant_isolation_idor_prevention ............. PASSED
  - test_service_price_validation_negative_price .................... PASSED
  - test_service_creation_restricted_to_owner_and_admin ............. PASSED
  - test_service_filter_per_item_and_invalid_price_type ............. PASSED
  - test_service_list_and_search_tenant_isolation ................... PASSED
tests/test_tenant_isolation.py (3 tests) ............................. PASSED

======================== 38 passed, 1 warning in 67.57s ========================
```

### B. Pengujian Frontend (`flutter test`)
```text
00:02 +22: All tests passed!
```

### C. Kompilasi Produksi Frontend (`flutter build web --release`)
```text
Compiling lib/main.dart for the Web...                             64.7s
✓ Built build/web
```

### D. Status Migrasi Database VPS PostgreSQL
```text
INFO  [alembic.runtime.migration] Context impl PostgresqlImpl.
INFO  [alembic.runtime.migration] Will assume transactional DDL.
INFO  [alembic.runtime.migration] Running upgrade 486e0e21a7e1 -> 8aa413a1cf94, create_customers_and_services_tables
```

---

## 6. Catatan Pola Reusable untuk Phase 3 (Order Management)

1. **Snapshotting Layanan ke Pesanan (`order_items`)**:
   Saat membuat pesanan baru di Phase 3, harga dan nama layanan wajib di-snapshot dari `Service`:
   ```python
   order_item = OrderItem(
       service_id=service.id,
       service_name_snapshot=service.name,
       price_type_snapshot=service.price_type,
       unit_snapshot=service.unit,
       unit_price_snapshot=service.price, # Nilai Decimal saat transaksi dibuat
       quantity=item.quantity,
       subtotal=service.price * item.quantity,
   )
   ```
2. **Validasi Layanan & Pelanggan Terhadap Tenant Transaksi**:
   Sebelum transaksi pesanan disimpan, backend wajib memastikan `customer.tenant_id == current_tenant.id` dan seluruh `service.tenant_id == current_tenant.id` serta `service.is_active == True`.
3. **Kombinasi Filter & Pencarian**:
   Gunakan pola `Wrap` untuk filter status pesanan (`received`, `washing`, `drying`, dll.) agar antarmuka kasir pada layar tablet/mobile tetap leluasa tanpa risiko render overflow.
