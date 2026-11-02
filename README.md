# LaundryTrack — Smart Laundry Management System

LaundryTrack adalah sistem manajemen operasional laundry berbasis SaaS multi-tenant untuk membantu pengusaha laundry mengelola pesanan, pelanggan, layanan, pembayaran, tracking publik (QR code), dan laporan bisnis.

---

## Tech Stack

- **Backend:** Python FastAPI, SQLAlchemy 2.0 (Async), PostgreSQL 16, Alembic, Pydantic v2
- **Frontend:** Flutter Web / PWA, Riverpod v2, GoRouter, Dio
- **Database:** PostgreSQL 16 terisolasi pada VPS (`45.66.153.146:5432`)
- **Reporting & Print:** ReportLab (PDF), Browser Print CSS (Thermal 58mm & 80mm)

---

## Struktur Direktori

```text
laundry/
├── backend/                  # FastAPI Modular Monolith
│   ├── app/
│   │   ├── core/             # Config, DB async engine, security, dependencies
│   │   ├── modules/          # Domain modules (auth, customers, orders, dll.)
│   │   ├── shared/           # Models base, pagination, permissions
│   │   └── main.py           # Entrypoint aplikasi FastAPI
│   ├── migrations/           # Skrip migrasi database Alembic
│   ├── tests/                # Test suite backend
│   └── requirements.txt
├── frontend/                 # Flutter Web Application
│   ├── lib/
│   │   ├── core/             # Network (Dio), Routing (GoRouter), Theme
│   │   ├── features/         # Layar dan logika fitur
│   │   └── main.dart         # Entrypoint Flutter
│   └── pubspec.yaml
├── docs/
│   ├── PRD.md                # Product Requirements Document
│   └── superpowers/          # Spesifikasi & Rencana Implementasi
├── .ai/
│   ├── FLOWS_AND_PATTERNS.md # Panduan alur bisnis & konvensi kode
│   └── tasks/                # Dokumentasi tugas & verifikasi
├── AGENTS.md                 # Aturan kolaborasi AI & developer
└── README.md
```

---

## Menjalankan Aplikasi (Local Development)

### 1. Menjalankan Backend
```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8000
```
Backend API docs akan tersedia di: `http://localhost:8000/docs`

### 2. Menjalankan Frontend (Flutter Web)
```bash
cd frontend
flutter run -d chrome --web-port 3000
```
Frontend akan terbuka di browser: `http://localhost:3000`

---

## Status Pengembangan (Phased Development)
- [x] **Phase 0:** Fondasi Proyek (Repository, FastAPI modular monolith, DB VPS, Alembic, Flutter Web baseline)
- [ ] **Phase 1:** Auth dan Multi-Tenancy
- [ ] **Phase 2:** Pelanggan dan Layanan
- [ ] **Phase 3:** Manajemen Pesanan
- [ ] **Phase 4:** Pembayaran dan Status
- [ ] **Phase 5:** Tracking dan Nota
- [ ] **Phase 6:** Portal Pelanggan
- [ ] **Phase 7:** Dashboard, Laporan, dan SaaS
- [ ] **Phase 8:** Audit dan Deployment
# LaundryApps
# LaundryApps
