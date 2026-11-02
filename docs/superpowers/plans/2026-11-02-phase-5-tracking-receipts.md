# Implementation Plan: Phase 5 — Public Tracking & Receipt Management

- **Fase**: Phase 5 — Pelacakan Publik & Manajemen Nota
- **Mulai**: 2026-11-02
- **Target Database**: PostgreSQL 16 pada VPS (`45.66.153.146:5432 / laundrytrack_db`)

---

## Tahapan Eksekusi

### Step 1: Database Models & Alembic Migration
- [ ] Tambahkan kolom `tracking_token`, `receipt_printed_at`, dan `reprint_count` pada model `Order` di `backend/app/modules/orders/models.py`.
- [ ] Buat model `ReceiptLog` di `backend/app/modules/receipts/models.py`.
- [ ] Daftarkan model baru pada `backend/migrations/env.py`.
- [ ] Generate revisi migrasi Alembic: `add_tracking_and_receipt_tables`.
- [ ] Terapkan `alembic upgrade head` pada database VPS PostgreSQL `laundrytrack_db`.

### Step 2: Backend Schemas, Service & Routers
- [ ] Buat skema Pydantic di `backend/app/modules/tracking/schemas.py`:
  - `PublicTrackingItemResponse`, `PublicTrackingTimelineResponse`, `PublicTrackingResponse`, `TrackingLinkResponse`
- [ ] Buat skema Pydantic di `backend/app/modules/receipts/schemas.py`:
  - `ReceiptResponse`, `ReceiptItemResponse`, `ReceiptReprintResponse`
- [ ] Buat `TrackingService` di `backend/app/modules/tracking/service.py`:
  - `get_public_tracking_by_token`: query by token, data masking (customer name/phone), exclude sensitive internal IDs.
  - `get_tracking_link`: format share URL and pre-filled WhatsApp message.
  - `regenerate_tracking_token`: generate fresh urlsafe token, invalidate previous token.
- [ ] Buat `ReceiptService` di `backend/app/modules/receipts/service.py`:
  - `get_receipt_data`: complete digital receipt details.
  - `generate_receipt_pdf`: generate binary PDF stream using ReportLab + embedded QR code.
  - `generate_thermal_html`: clean HTML/CSS monospace template (58mm/80mm) with `@media print`.
  - `record_reprint`: increment reprint count, append audit log.
- [ ] Update `create_order` di `backend/app/modules/orders/service.py` untuk generate `tracking_token = secrets.token_urlsafe(32)` secara default.
- [ ] Buat router di `backend/app/modules/tracking/router.py` dan `backend/app/modules/receipts/router.py`.
- [ ] Daftarkan kedua router di `backend/app/main.py`.

### Step 3: Backend Test Suite
- [ ] Buat `backend/tests/test_tracking_and_receipts.py`:
  - Public tracking by valid token (HTTP 200, status pengerjaan, estimasi selesai).
  - Public tracking privacy masking (customer name and phone masked, no tenant/outlet/customer UUIDs).
  - Public tracking with invalid/expired token (HTTP 404).
  - Tracking link retrieval and regeneration (old token becomes 404, new token works).
  - Receipt detail retrieval with complete financial and line items.
  - Receipt PDF generation returns valid binary PDF (`%PDF-1.` header, correct Content-Type).
  - Thermal print HTML endpoint returns valid HTML with printable CSS.
  - Receipt reprint logging increments count and records audit user.
  - Tenant isolation on internal tracking & receipt endpoints.
- [ ] Jalankan `pytest -v` dan pastikan seluruh test (Phase 0 s/d Phase 5) 100% passing.

### Step 4: Frontend Implementation (Flutter Web)
- [ ] Buat model:
  - `frontend/lib/features/tracking/data/tracking_model.dart`
  - `frontend/lib/features/receipts/data/receipt_model.dart`
- [ ] Buat repository & provider:
  - `tracking_repository.dart` & `tracking_provider.dart`
  - `receipt_repository.dart` & `receipt_provider.dart`
- [ ] Buat antarmuka:
  - `frontend/lib/features/tracking/presentation/tracking_screen.dart`: Public responsive tracking screen.
  - `frontend/lib/features/receipts/presentation/receipt_dialog.dart`: Dialog kasir untuk cetak thermal, unduh PDF, salin link tracking, dan bagikan ke WhatsApp.
- [ ] Daftarkan rute publik `/track/:token` di `frontend/lib/core/router/app_router.dart`.
- [ ] Tambahkan tombol "Nota & Tracking" di `OrderDetailDialog` dan opsi setelah membuat pesanan di `order_create_screen.dart`.
- [ ] Tulis widget & unit tests di `frontend/test/tracking_receipt_flow_test.dart`.
- [ ] Jalankan `flutter analyze`, `flutter test`, dan `flutter build web --release`.

### Step 5: Multi-Agent Audit Protocol & Documentation
- [ ] Panggil `test-engineer` untuk memverifikasi coverage dan edge cases.
- [ ] Panggil `code-reviewer` untuk evaluasi 5 dimensi.
- [ ] Panggil `security-auditor` untuk audit proteksi privasi tracking publik dan penanganan PDF/token.
- [ ] Panggil `web-performance-auditor` untuk audit halaman publik `/track/:token` dan dialog nota.
- [ ] Susun dokumentasi pasca-tugas di `.ai/tasks/laundry/2026-11-02_phase-5-tracking-nota.md`.
- [ ] Git commit dan laporkan ke user.
