# Design Specification: Phase 0 — Fondasi Proyek (LaundryTrack)

**Tanggal:** 1 November 2026  
**Status:** Approved by User  
**Tujuan:** Menyediakan fondasi monorepo, backend FastAPI, database PostgreSQL terisolasi di VPS, migrasi Alembic, frontend Flutter Web (PWA ready), dan dokumentasi arsitektur standar.

---

## 1. Arsitektur Keseluruhan

LaundryTrack dibangun dengan pendekatan **Modular Monolith** untuk memastikan konsistensi transaksi, kemudahan deployment oleh tim kecil, serta skalabilitas masa depan:

```
[ Flutter Web / PWA Client ]
            │ HTTP / JSON
            ▼
[ Nginx Reverse Proxy / Direct Local Dev ]
            │ Port 8000
            ▼
[ FastAPI Backend (Modular Monolith) ]
   ├── Core (Config, DB Engine, Security, Dependencies, Exceptions)
   ├── Shared (Pagination, Permissions, Validators)
   └── Modules (Auth, Tenants, Outlets, Customers, Orders, Payments, etc.)
            │
            ▼ SQLAlchemy 2.0 (Async/Sync Session)
[ PostgreSQL 16 on VPS (45.66.153.146:5432) ]
   └── Database: laundrytrack_db
   └── User: laundrytrack_user (Isolated credentials)
```

---

## 2. Topologi Database di VPS

- **Host VPS:** `45.66.153.146` (Port: `5432`)
- **Container Name:** `postgresql` (PostgreSQL 16)
- **Database Baru:** `laundrytrack_db`
- **User Baru:** `laundrytrack_user`
- **Enkripsi & Encoding:** UTF-8, UTC Timezone
- **Isolasi:** Hak akses dibatasi hanya ke `laundrytrack_db`. Database lain di container (`tokokita_db`, `fudgy_db`, dll.) tetap aman dan tidak tersentuh.

---

## 3. Struktur Direktori Proyek (Monorepo)

```text
laundry/
├── backend/
│   ├── app/
│   │   ├── __init__.py
│   │   ├── main.py
│   │   ├── core/
│   │   │   ├── __init__.py
│   │   │   ├── config.py          # Pydantic BaseSettings
│   │   │   ├── database.py        # SQLAlchemy 2.0 async engine & sessionmaker
│   │   │   ├── security.py        # Token & hashing utilities (siap untuk Phase 1)
│   │   │   ├── dependencies.py    # Common DB & Auth dependencies
│   │   │   └── exceptions.py      # Standard HTTP and Domain exceptions
│   │   ├── modules/
│   │   │   ├── __init__.py
│   │   │   └── health/            # Modul health check & verifikasi DB VPS
│   │   │       ├── __init__.py
│   │   │       ├── router.py
│   │   │       └── schemas.py
│   │   └── shared/
│   │       ├── __init__.py
│   │       └── models.py          # Declarative Base & TimestampMixin
│   ├── migrations/
│   │   ├── env.py
│   │   ├── script.py.mako
│   │   └── versions/
│   ├── tests/
│   │   ├── __init__.py
│   │   ├── conftest.py
│   │   └── test_health.py
│   ├── .env.example
│   ├── alembic.ini
│   └── requirements.txt
├── frontend/
│   ├── lib/
│   │   ├── main.dart
│   │   ├── core/
│   │   │   ├── constants/
│   │   │   ├── network/           # Dio HTTP client configuration
│   │   │   ├── router/            # GoRouter configuration
│   │   │   └── theme/             # Material 3 typography & color palette
│   │   └── features/
│   │       └── health/            # Health status screen verifying backend & DB
│   │           ├── presentation/
│   │           └── providers/
│   ├── web/
│   ├── pubspec.yaml
│   └── test/
├── .ai/
│   ├── FLOWS_AND_PATTERNS.md      # Standar alur arsitektur & konvensi penulisan
│   └── tasks/                     # Task execution logs
├── docs/
│   ├── PRD.md
│   └── superpowers/
│       ├── specs/
│       └── plans/
├── AGENTS.md                      # Multi-agent rules & developer contract
└── README.md
```

---

## 4. Standar dan Konvensi Backend

1. **ORM & Database:**
   - SQLAlchemy 2.0 style (`select()`, async `AsyncSession`).
   - Primary Key: UUIDv4 (`sa.UUID(as_uuid=True)`).
   - Nilai uang: `sa.Numeric(precision=12, scale=2)`.
   - Timestamp: `sa.DateTime(timezone=True)` default UTC.
2. **Settings:**
   - Dikelola oleh `pydantic-settings` via file `.env`.
   - Tidak ada hardcoded credentials di source control.
3. **CORS:**
   - Diatur untuk mendukung request dari Flutter Web (localhost:port pada mode dev).
4. **Health Check Endpoint:**
   - `GET /api/v1/health`: Mengembalikan status service, database connection probe, timestamp UTC, dan versi API.

---

## 5. Standar dan Konvensi Frontend

1. **Flutter Web / Material 3:**
   - Riverpod v2 untuk State Management.
   - GoRouter untuk routing berbasis path URL browser yang ramah web.
   - Dio dengan interceptor untuk error handling terpusat dan logging request.
2. **Health Check UI:**
   - Layar inisial yang menampilkan status koneksi ke Backend FastAPI dan Database VPS secara visual.

---

## 6. Acceptance Criteria Phase 0

- [x] Database `laundrytrack_db` dan user `laundrytrack_user` dibuat di PostgreSQL VPS.
- [x] Backend FastAPI berhasil terkoneksi ke PostgreSQL VPS.
- [x] Migrasi inisial Alembic berhasil dijalankan terhadap `laundrytrack_db`.
- [x] Endpoint `GET /api/v1/health` mengembalikan `status: "healthy"` dan probe DB sukses.
- [x] Flutter Web berhasil di-build / diuji terhubung ke endpoint health.
- [x] Dokumentasi `AGENTS.md` dan `.ai/FLOWS_AND_PATTERNS.md` tersedia.
- [x] Tidak ada kode fitur bisnis dibuat sebelum Phase 0 disetujui.
