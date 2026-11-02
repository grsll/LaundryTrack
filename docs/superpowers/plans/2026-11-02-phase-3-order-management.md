# Implementation Plan: Phase 3 — Order Management

- **Fase**: Phase 3 — Manajemen Pesanan
- **Mulai**: 2026-11-02
- **Target Database**: PostgreSQL 16 pada VPS (`45.66.153.146:5432 / laundrytrack_db`)

---

## Tahapan Eksekusi

### Step 1: Database Models & Alembic Migration
- [ ] Buat model `Order`, `OrderItem`, `OrderStatusLog`, `OrderSequence` di `backend/app/modules/orders/models.py`.
- [ ] Daftarkan relasi `orders` pada model `Tenant`, `Outlet`, dan `Customer`.
- [ ] Daftarkan model baru pada `backend/migrations/env.py`.
- [ ] Generate revisi migrasi Alembic: `create_orders_and_order_items_tables`.
- [ ] Terapkan `alembic upgrade head` pada database VPS PostgreSQL `laundrytrack_db`.

### Step 2: Backend Schemas, Service & Router
- [ ] Buat schemas Pydantic untuk Order di `backend/app/modules/orders/schemas.py`:
  - `OrderItemCreate`, `OrderItemResponse`
  - `OrderCreate`, `OrderUpdate`, `OrderStatusTransitionRequest`, `OrderCancelRequest`
  - `OrderResponse`, `OrderDetailResponse`, `OrderStatusLogResponse`
- [ ] Buat `OrderService` di `backend/app/modules/orders/service.py`:
  - `generate_order_number`: atomic counter lock with `with_for_update()`.
  - `create_order`: atomic transaction, customer & services tenant check, snapshotting, decimal calculations.
  - `list_orders`: pagination, search by `order_number` or customer name/phone, filter by status and outlet.
  - `get_order_by_id`: complete detail with items, customer, outlet, logs.
  - `transition_status`: state machine validation, append status log.
  - `cancel_order`: reason required, completed orders rejection.
  - `get_order_timeline`: list status history.
- [ ] Buat router di `backend/app/modules/orders/router.py`.
- [ ] Daftarkan `orders_router` di `backend/app/main.py`.

### Step 3: Backend Test Suite
- [ ] Buat `backend/tests/test_orders.py`:
  - Pembuatan order berhasil dengan kalkulasi Decimal dan snapshot item.
  - Validasi penolakan customer/service dari tenant lain (IDOR).
  - Validasi penolakan kuantitas 0 atau negatif.
  - Penomoran nota berurut dan unik (`LDR-YYYYMMDD-XXXX`).
  - Alur transisi status valid (`received -> washing -> ready -> completed`).
  - Penolakan transisi status ilegal (misal langsung `received -> completed`).
  - Pembatalan pesanan dengan alasan, dan penolakan pembatalan pesanan yang sudah `completed`.
  - Isolasi tenant penuh: Tenant B tidak dapat melihat atau memanipulasi pesanan Tenant A.
- [ ] Jalankan `pytest -v` dan pastikan seluruh test (Phase 0, Phase 1, Phase 2, Phase 3) 100% passing.

### Step 4: Frontend Implementation (Flutter Web)
- [ ] Buat model & repository Order: `order_model.dart`, `order_repository.dart`.
- [ ] Buat Riverpod provider: `order_provider.dart`.
- [ ] Buat antarmuka Order:
  - `order_list_screen.dart` dengan filter status, pencarian, dan order cards.
  - `order_create_screen.dart` untuk kasir memasukkan pelanggan dan item layanan dengan kalkulasi live.
  - `order_detail_dialog.dart` untuk melihat detail item, timeline pengerjaan, dan tombol ubah status/batal.
- [ ] Daftarkan rute `/orders` dan `/orders/create` di `app_router.dart`.
- [ ] Tambahkan quick navigation card "Pesanan Laundry" di `DashboardScreen`.
- [ ] Tulis widget test: `order_flow_test.dart`.
- [ ] Jalankan `flutter test` dan `flutter build web --release`.

### Step 5: Multi-Agent Audit Protocol & Documentation
- [ ] Panggil `test-engineer` untuk memverifikasi coverage dan edge cases.
- [ ] Panggil `code-reviewer` untuk evaluasi 5 dimensi.
- [ ] Panggil `security-auditor` untuk audit otorisasi dan IDOR.
- [ ] Susun dokumentasi pasca-tugas `.ai/tasks/2026-11-02_phase-3-manajemen-pesanan.md`.
- [ ] Git commit dan konfirmasi ke user.
