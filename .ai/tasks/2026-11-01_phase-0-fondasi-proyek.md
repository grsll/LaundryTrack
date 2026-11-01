# Dokumentasi Tugas: Phase 0 — Fondasi Proyek LaundryTrack

**Tanggal:** 2026-11-01  
**Topik Tugas:** Inisialisasi Fondasi Monorepo, Database Terisolasi VPS, Backend FastAPI Modular Monolith, Migrasi Alembic, dan Frontend Flutter Web (PWA Ready).  
**Status:** Selesai & Terverifikasi (Pass 100%)  

---

## 1. Ringkasan Tugas & Konteks

Berdasarkan Product Requirements Document (PRD) v1.0 LaundryTrack, pengembangan wajib dilakukan secara bertahap dimulai dari **Phase 0 (Fondasi Proyek)** tanpa menulis kode fitur bisnis apa pun sampai kerangka kerja disetujui.

Sesuai instruksi khusus dari pengguna:
- Basis data PostgreSQL menggunakan instance PostgreSQL 16 yang sudah berjalan di container Docker VPS (`45.66.153.146:5432`).
- Pengembang/agen diberikan akses VPS melalui SSH untuk melakukan provisioning basis data terisolasi.

Tujuan utama Phase 0:
1. Menyediakan repository dan struktur monorepo terorganisir (`backend/`, `frontend/`, `docker/`, `docs/`, `.ai/`).
2. Menyiapkan database terisolasi `laundrytrack_db` dan user `laundrytrack_user` di VPS.
3. Membangun backend FastAPI berbasis SQLAlchemy 2.0 async engine dengan health check endpoint `/api/v1/health` yang melakukan probe nyata ke VPS PostgreSQL.
4. Mengonfigurasi migrasi Alembic dan mengeksekusi migrasi inisial baseline langsung ke database VPS.
5. Membangun frontend Flutter Web berbasis Riverpod v2, GoRouter, dan Dio yang menampilkan status koneksi end-to-end ke backend dan basis data.
6. Menjalankan protokol multi-agent audit (`test-engineer`, `code-reviewer`, `security-auditor`) dan menerapkan seluruh perbaikan sebelum penyelesaian tugas.

---

## 2. Alur Analisis & Investigasi

1. **Investigasi VPS & Database:**
   - Akses SSH ke `45.66.153.146:20322` berhasil dilakukan.
   - Pengecekan container Docker menemukan container `postgresql` (PostgreSQL 16) yang sudah menampung beberapa database proyek lain (`tokokita_db`, `fudgy_db`, dll.).
   - Untuk mencegah kebocoran data dan menjaga integritas multi-tenant, dibuat role `laundrytrack_user` dengan password acak dengan entropi tinggi dan database baru `laundrytrack_db` dengan ownership penuh pada user tersebut.
   - Pengecekan jaringan membuktikan port 5432 VPS dapat dijangkau langsung dari host lokal melalui driver `asyncpg` dan `psycopg`.
2. **Investigasi Scaffolding & Kompatibilitas:**
   - Python 3.14 pada host diverifikasi kompatibel dengan FastAPI 0.115+, SQLAlchemy 2.0.35+, Pydantic v2, Alembic, psycopg 3, dan greenlet.
   - Flutter 3.47.7 (Dart 3.13.5) diaktifkan untuk target Web dan berhasil mengompilasi package `flutter_riverpod`, `go_router`, dan `dio`.
3. **Temuan Audit Multi-Agent:**
   - **`test-engineer`**: Menyoroti perlunya pemisahan unit test terisolasi (mocking) dengan live integration test agar test suite tidak gagal saat offline, serta pentingnya pengujian loading, error, dan degraded states pada Flutter.
   - **`code-reviewer`**: Menemukan potensi bug URI path resolution pada Dio (leading slash `/health` menimpa prefix `/api/v1`), hilangnya `server_default` pada model mixins, perlunya timeout eksplisit pada query probe DB, dan perbaikan CORS wildcard credentials.
   - **`security-auditor`**: Merekomendasikan pengetatan CORS whitelist, penambahan security headers middleware (`nosniff`, `DENY`), penyembunyian `/docs` di production, dan sanitasi query logging.

---

## 3. Logika Kode & Solusi

### 3.1 Database Provisioning di VPS
- Eksekusi SQL via psql di container `postgresql` VPS:
  - Role: `laundrytrack_user`
  - Database: `laundrytrack_db`
  - Hak akses eksklusif diberikan pada `laundrytrack_db`.

### 3.2 Backend FastAPI (Modular Monolith)
- **`app/core/config.py`**: Menggunakan `pydantic-settings` untuk memuat variabel dari `.env` dengan validasi secret key dan CORS origins. Nilai default host lokal aman dari hardcoding IP publik.
- **`app/core/database.py`**:
  - `create_async_engine` dengan `pool_pre_ping=True`, `pool_size=10`, `max_overflow=20`.
  - Fungsi `check_db_health()` menggunakan probe query `SELECT 1` dengan `asyncio.wait_for(timeout=3.0)`.
- **`app/shared/models.py`**:
  - `UUIDMixin`: Menggunakan UUIDv4 dengan Python default dan `server_default=sa.text("gen_random_uuid()")`.
  - `TimestampMixin`: Menggunakan datetime UTC dengan `server_default=sa.func.now()`.
  - `TenantMixin`: Menyediakan kolom terindeks `tenant_id` untuk kesiapan Phase 1.
- **`app/main.py`**:
  - Mengintegrasikan `SecurityHeadersMiddleware`.
  - Mengonfigurasi `CORSMiddleware` dengan origin spesifik (`localhost:3000`, `127.0.0.1:3000`).
  - Menambahkan global exception handler untuk `AppException` dan unhandled exception standar sesuai `.ai/FLOWS_AND_PATTERNS.md`.
  - Endpoint `/api/v1/health` mengembalikan status `healthy` (HTTP 200) atau `degraded` (HTTP 503).

### 3.3 Alembic Migration
- `migrations/env.py` membaca `SYNC_DATABASE_URL` secara dinamis dari `settings` dan menghubungkan `Base.metadata`.
- Migrasi inisial `baseline_foundation` berhasil dieksekusi ke VPS PostgreSQL, menghasilkan tabel `alembic_version`.

### 3.4 Frontend Flutter Web
- `core/constants/app_constants.dart` & `core/network/api_client.dart`: Dio client dikonfigurasi dengan `defaultApiHost` dan path eksplisit `/api/v1/health` dengan validator status (200 & 503).
- `features/health/presentation/health_screen.dart`: UI responsif Material 3 menampilkan status Backend API, Database VPS, latency, serta checklist roadmap Phase 0–8.
- `health_widget_test.dart`: Meliputi pengujian unit model JSON dan pengujian UI untuk seluruh state (Healthy, Degraded, Loading, Error).

---

## 4. Berkas yang Berubah / Dibuat

```text
.
├── .ai/
│   ├── FLOWS_AND_PATTERNS.md
│   └── tasks/
│       └── 2026-11-01_phase-0-fondasi-proyek.md
├── .gitignore
├── AGENTS.md
├── README.md
├── docker-compose.yml
├── docs/
│   ├── PRD.md
│   └── superpowers/
│       ├── specs/2026-11-01-phase-0-foundation-design.md
│       └── plans/2026-11-01-phase-0-foundation.md
├── backend/
│   ├── .env.example
│   ├── .env (gitignored)
│   ├── Dockerfile
│   ├── alembic.ini
│   ├── requirements.txt
│   ├── app/
│   │   ├── __init__.py
│   │   ├── main.py
│   │   ├── core/
│   │   │   ├── __init__.py
│   │   │   ├── config.py
│   │   │   ├── database.py
│   │   │   ├── dependencies.py
│   │   │   └── exceptions.py
│   │   ├── modules/
│   │   │   ├── __init__.py
│   │   │   └── health/
│   │   │       ├── __init__.py
│   │   │       ├── router.py
│   │   │       └── schemas.py
│   │   └── shared/
│   │       ├── __init__.py
│   │       └── models.py
│   ├── migrations/
│   │   ├── env.py
│   │   ├── script.py.mako
│   │   └── versions/
│   │       └── 2dd32392889c_baseline_foundation.py
│   └── tests/
│       ├── __init__.py
│       ├── conftest.py
│       └── test_health.py
└── frontend/
    ├── pubspec.yaml
    ├── lib/
    │   ├── main.dart
    │   ├── core/
    │   │   ├── constants/app_constants.dart
    │   │   ├── network/api_client.dart
    │   │   ├── router/app_router.dart
    │   │   └── theme/app_theme.dart
    │   └── features/
    │       └── health/
    │           ├── data/health_model.dart
    │           └── presentation/health_screen.dart
    └── test/
        └── health_widget_test.dart
```

---

## 5. Bukti Verifikasi

### 5.1 Test Suite Backend (Pytest)
```bash
$ cd backend && .venv/bin/pytest -v
============================= test session starts ==============================
platform linux -- Python 3.14.4, pytest-9.2.0, pluggy-1.7.0
rootdir: /home/huawei-matebook-d14/Projects/Vibe_Coding/laundry/backend
collected 7 items

tests/test_health.py::test_root_endpoint_metadata_and_headers PASSED     [ 14%]
tests/test_health.py::test_health_endpoint_unit_success PASSED           [ 28%]
tests/test_health.py::test_health_endpoint_live_vps_connection PASSED    [ 42%]
tests/test_health.py::test_health_endpoint_database_degraded PASSED      [ 57%]
tests/test_health.py::test_app_exception_standard_format PASSED          [ 71%]
tests/test_health.py::test_check_db_health_success_probe PASSED          [ 85%]
tests/test_health.py::test_check_db_health_exception_handled PASSED      [100%]

========================= 7 passed, 1 warning in 2.80s =========================
```

### 5.2 Test Suite Frontend (Flutter Test)
```bash
$ cd frontend && flutter test
00:00 +0: HealthModel Unit Tests fromJson handles complete valid payload
00:00 +1: HealthModel Unit Tests fromJson handles partial or missing fields with safe defaults
00:00 +2: HealthScreen Widget Tests renders healthy status when services are operational
00:00 +3: HealthScreen Widget Tests renders degraded status when database is unreachable
00:00 +4: HealthScreen Widget Tests renders loading state while awaiting API probe
00:00 +5: HealthScreen Widget Tests renders error banner when backend connection fails
00:01 +6: All tests passed!
```

### 5.3 Kompilasi Build Flutter Web
```bash
$ cd frontend && flutter build web
Compiling lib/main.dart for the Web...                             44.3s
✓ Built build/web
```

### 5.4 Verifikasi Basis Data VPS
```bash
$ ssh -p 20322 root@45.66.153.146 "docker exec postgresql psql -U laundrytrack_user -d laundrytrack_db -c 'SELECT * FROM alembic_version;'"
 version_num  
--------------
 2dd32392889c
(1 row)
```

---

## 6. Catatan Pola Reusable untuk Tugas Serupa

1. **Pemisahan Unit vs Live Integration Test:**
   Selalu gunakan mock untuk unit test rute agar CI/CD offline tidak bergantung pada konektivitas jaringan VPS, dan tandai tes koneksi langsung dengan penanda terpisah.
2. **Dio RFC 3986 URI Resolution:**
   Jika `baseUrl` mengandung path (seperti `/api/v1`), request dengan leading slash (misal `dio.get('/health')`) akan mereset path ke root host (`/health`). Selalu pisahkan base host (`http://localhost:8000`) dengan path relatif/lengkap (`/api/v1/...`).
3. **Penyelarasan Server Default Model:**
   Saat membuat mixin SQLAlchemy 2.0 untuk UUID dan timestamps, selalu pasangkan Python `default` dengan `server_default` SQL (`gen_random_uuid()`, `now()`) agar proses migrasi, seed, atau query raw SQL tetap mematuhi schema constraint.
4. **Keamanan Remote DB:**
   Selalu pisahkan database dan user per project dalam multi-database container PostgreSQL untuk membatasi radius dampak keamanan.
