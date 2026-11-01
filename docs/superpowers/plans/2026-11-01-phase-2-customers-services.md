# Implementation Plan: Phase 2 — Customer & Service Management

- **Fase**: Phase 2 — Pelanggan dan Layanan
- **Mulai**: 2026-11-01
- **Target Database**: PostgreSQL 16 pada VPS (`45.66.153.146:5432 / laundrytrack_db`)

---

## Tahapan Eksekusi

### Step 1: Database Models & Alembic Migration
- [ ] Buat model `Customer` di `backend/app/modules/customers/models.py`.
- [ ] Buat model `Service` di `backend/app/modules/services/models.py`.
- [ ] Daftarkan relasi pada model `Tenant` di `backend/app/modules/tenants/models.py`.
- [ ] Daftarkan model baru pada `backend/migrations/env.py`.
- [ ] Generate revisi migrasi Alembic: `create_customers_and_services_tables`.
- [ ] Jalankan `alembic upgrade head` terhadap VPS PostgreSQL dan verifikasi tabel terbentuk.

### Step 2: Backend Schemas, Service & Routers
- [ ] Buat schemas Pydantic untuk Customer: `CustomerCreate`, `CustomerUpdate`, `CustomerResponse`, `CustomerSummaryResponse`.
- [ ] Buat `CustomerService` dengan isolasi tenant dan pagination: `create_customer`, `get_customer_by_id`, `list_customers`, `update_customer`, `archive_customer`, `get_customer_summary`.
- [ ] Buat `customer_router` di `backend/app/modules/customers/router.py`.
- [ ] Buat schemas Pydantic untuk Service: `ServiceCreate`, `ServiceUpdate`, `ServiceResponse`, validasi `Decimal` dan enum `price_type`.
- [ ] Buat `ServiceService` dengan isolasi tenant: `create_service`, `get_service_by_id`, `list_services`, `update_service`, `archive_service`.
- [ ] Buat `service_router` di `backend/app/modules/services/router.py`.
- [ ] Daftarkan routers di `backend/app/main.py`.

### Step 3: Backend Test Suite
- [ ] Tulis `backend/tests/test_customers.py`:
  - Create customer, duplicate phone behavior, search by name/phone, update, soft delete, cross-tenant 404 IDOR test.
- [ ] Tulis `backend/tests/test_services.py`:
  - Create `per_kg` service, create `per_item` service, price validation (`Numeric`), search, update, soft delete, cross-tenant 404 IDOR test.
- [ ] Jalankan `pytest -v` dan pastikan seluruh test baru dan test lama (Phase 0, Phase 1) lulus 100%.

### Step 4: Frontend Implementation (Flutter Web)
- [ ] Buat data model & repository Customer: `customer_model.dart`, `customer_repository.dart`.
- [ ] Buat Riverpod provider untuk Customer: `customer_provider.dart`.
- [ ] Buat data model & repository Service: `service_model.dart`, `service_repository.dart`.
- [ ] Buat Riverpod provider untuk Service: `service_provider.dart`.
- [ ] Buat layar Customer: `customer_list_screen.dart` dengan pencarian dan dialog tambah/edit.
- [ ] Buat layar Service: `service_list_screen.dart` dengan filter Kiloan/Satuan dan dialog tambah/edit.
- [ ] Integrasikan navigasi di `DashboardScreen` atau sidebar menu.
- [ ] Tulis widget test: `customer_service_flow_test.dart`.
- [ ] Verifikasi `flutter test` dan `flutter build web`.

### Step 5: Multi-Agent Audit Protocol & Documentation
- [ ] Panggil `test-engineer` untuk memverifikasi coverage dan edge cases.
- [ ] Panggil `code-reviewer` untuk evaluasi 5 dimensi.
- [ ] Panggil `security-auditor` untuk audit tenant isolation dan IDOR risks.
- [ ] Susun berkas dokumentasi `.ai/tasks/2026-11-01_phase-2-pelanggan-dan-layanan.md`.
- [ ] Git commit dan konfirmasi ke user.
