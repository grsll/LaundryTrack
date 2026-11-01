# LaundryTrack Developer & Agent Guidelines

## 1. Project Overview & Architecture
LaundryTrack is a multi-tenant SaaS application designed for laundry businesses.
- **Backend:** FastAPI modular monolith (`backend/app/`)
  - `core/`: Application settings, database session, security, exceptions, shared dependencies.
  - `modules/`: Domain modules (`auth`, `tenants`, `outlets`, `customers`, `services`, `orders`, `payments`, `tracking`, `receipts`, `reports`, `subscriptions`).
  - `shared/`: Declarative models base, pagination, permissions, validators.
- **Frontend:** Flutter Web / PWA (`frontend/lib/`)
  - `core/`: Network (Dio), Routing (GoRouter), Theme, Constants.
  - `features/`: Feature modules matching backend domains.
- **Database:** PostgreSQL 16 on VPS (`45.66.153.146:5432`), isolated database `laundrytrack_db`.

---

## 2. Core Architectural & Coding Standards

### Backend (Python / FastAPI / SQLAlchemy 2.0)
1. **Execution Flow:** Every request must strictly follow:
   `Entry Point (Router) -> Input Validation (Pydantic) -> Business Logic (Service) -> Persistence (ORM / SQLAlchemy 2.0) -> Output Serialization (Schema)`
2. **Tenant Isolation:**
   - Active tenant must always be resolved from the authenticated user session / JWT token.
   - Client-provided `tenant_id` must NEVER be blindly trusted.
   - Every multi-tenant model must have `tenant_id` (and `outlet_id` for operational records).
3. **Data Types:**
   - Primary Keys: Always UUIDv4 (`sa.UUID(as_uuid=True)`).
   - Currency & Financial calculations: Always `sa.Numeric(precision=12, scale=2)` and Python `Decimal`. NEVER use floating point.
   - Dates & Timestamps: Always timezone-aware UTC (`sa.DateTime(timezone=True)` default `datetime.now(timezone.utc)`). Display formatted in Asia/Jakarta (WIB).
4. **Historical Immutability (Snapshotting):**
   - Transaction line items (`order_items`) must snapshot service name, unit price, quantity, and unit at time of order creation.

### Frontend (Flutter Web)
1. **State Management:** Riverpod v2.
2. **HTTP Client:** Dio with centralized error interceptor, base URL, and auth token headers.
3. **Routing:** GoRouter with declarative web URLs.
4. **Design System:** Material 3, responsive layout (desktop sidebar, mobile drawer/bottom bar, tables to cards on narrow viewports).

---

## 3. Mandatory Multi-Agent Delegation Protocol

Before marking any major feature, refactor, or bug fix complete:
1. `test-engineer`: Verify unit and integration test coverage, edge cases, and run test suites.
2. `code-reviewer`: Evaluate 5 dimensions (Correctness, Readability, Architecture, Security, Performance).
3. `security-auditor`: Audit auth, tenant isolation, database credentials, IDOR risks, and rate limiting.
4. `web-performance-auditor`: Audit frontend assets, layout shifts, responsive breakpoints, and network requests.

---

## 4. Mandatory Post-Task Markdown Documentation

Every task completion must produce a post-task markdown file in `.ai/tasks/` with format `YYYY-MM-DD_<topic>.md`:
- **Format:**
  1. Ringkasan Tugas & Konteks
  2. Alur Analisis / Root Cause
  3. Logika Kode & Solusi
  4. Berkas yang Berubah
  5. Bukti Verifikasi (Test outputs & terminal evidence)
  6. Catatan Pola Reusable untuk tugas serupa di masa depan
- Inform the user of the created `.md` file and concise summary.
