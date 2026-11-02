# Implementation Plan: Phase 4 — Payment & Refund Management

- **Fase**: Phase 4 — Manajemen Pembayaran & Kasir / Refund
- **Mulai**: 2026-11-02
- **Target Database**: PostgreSQL 16 pada VPS (`45.66.153.146:5432 / laundrytrack_db`)

---

## Tahapan Eksekusi

### Step 1: Database Models & Alembic Migration
- [ ] Buat model `Payment` dan `Refund` di `backend/app/modules/payments/models.py`.
- [ ] Daftarkan relasi `payments` dan `refunds` pada model `Order` di `backend/app/modules/orders/models.py`.
- [ ] Daftarkan model baru pada `backend/migrations/env.py`.
- [ ] Generate revisi migrasi Alembic: `create_payments_and_refunds_tables`.
- [ ] Terapkan `alembic upgrade head` pada database VPS PostgreSQL `laundrytrack_db`.

### Step 2: Backend Schemas, Service & Router
- [ ] Buat schemas Pydantic di `backend/app/modules/payments/schemas.py`:
  - `PaymentCreate`, `PaymentResponse`, `PaymentDetailResponse`
  - `RefundCreate`, `RefundResponse`
- [ ] Buat `PaymentService` di `backend/app/modules/payments/service.py`:
  - `record_payment`: pessimistic lock with `with_for_update()`, check overpayment, update order amounts and payment status.
  - `list_order_payments`: list all payments for an order.
  - `get_payment_by_id`: single payment detail with refunds.
  - `record_refund`: check refund limit, lock payment & order, update balances and status.
  - `list_payments`: paginated list with filters.
- [ ] Perbarui `backend/app/modules/orders/service.py`:
  - Update `cancel_order`: tolak pembatalan jika pesanan masih memiliki `paid_amount > 0` (harus di-refund terlebih dahulu).
- [ ] Buat router di `backend/app/modules/payments/router.py`.
- [ ] Daftarkan `payments_router` di `backend/app/main.py`.

### Step 3: Backend Test Suite
- [ ] Buat `backend/tests/test_payments.py`:
  - Pembayaran penuh (`unpaid -> paid`).
  - Pembayaran sebagian (`unpaid -> partial -> paid`).
  - Tolak overpayment (`amount > remaining_amount`).
  - Tolak pembayaran nominal nol atau negatif.
  - Tolak pembayaran pada pesanan dibatalkan.
  - Refund parsial dan refund penuh (`paid -> refunded`).
  - Tolak refund melebihi nominal pembayaran awal.
  - Tolak refund tanpa alasan.
  - Otorisasi RBAC: Kasir ditolak untuk refund (403), Owner/Admin diizinkan.
  - Isolasi tenant / IDOR: Tenant B ditolak mengakses/membayar/merefund transaksi Tenant A.
  - Pengujian pembatalan pesanan terproteksi jika masih memiliki `paid_amount > 0`.
- [ ] Jalankan `pytest -v` dan pastikan seluruh test (Phase 0 s/d Phase 4) 100% passing.

### Step 4: Frontend Implementation (Flutter Web)
- [ ] Buat model: `payment_model.dart` dan `payment_repository.dart` di `frontend/lib/features/payments/data/`.
- [ ] Buat Riverpod provider: `payment_provider.dart` di `frontend/lib/features/payments/providers/`.
- [ ] Buat komponen UI:
  - `payment_form_dialog.dart`: form kasir untuk catat bayar, metode bayar, quick chips tunai, kembalian otomatis.
  - `refund_form_dialog.dart`: form refund untuk owner/admin.
  - Modifikasi `order_detail_dialog.dart`: integrasikan tombol "Catat Pembayaran", tab/section riwayat pembayaran & refund.
  - Modifikasi `order_list_screen.dart`: badge status pembayaran yang informatif.
- [ ] Tulis widget test: `payment_flow_test.dart`.
- [ ] Jalankan `flutter analyze`, `flutter test`, dan `flutter build web --release`.

### Step 5: Multi-Agent Audit Protocol & Documentation
- [ ] Panggil `test-engineer` untuk memverifikasi kelengkapan pengujian.
- [ ] Panggil `code-reviewer` untuk evaluasi 5 dimensi.
- [ ] Panggil `security-auditor` untuk audit otorisasi finansial dan IDOR.
- [ ] Panggil `web-performance-auditor` untuk audit UI kasir dan layout responsif.
- [ ] Susun dokumentasi pasca-tugas di `.ai/tasks/laundry/2026-11-02_phase-4-pembayaran-kasir.md`.
- [ ] Git commit dan laporkan ke user.
