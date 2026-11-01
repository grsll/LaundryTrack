# Phase 0: Fondasi Proyek Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Establish the complete project foundation (monorepo structure, isolated VPS PostgreSQL database, FastAPI backend with health & DB probe, Alembic migrations, Flutter Web baseline, and architecture rules) with zero business feature code.

**Architecture:** Modular monolith backend in FastAPI connecting via SQLAlchemy 2.0 async engine to an isolated PostgreSQL 16 database running on the user's VPS (`45.66.153.146:5432`). Flutter Web client with Riverpod, Dio, and GoRouter configured to communicate with the backend.

**Tech Stack:** Python 3.14, FastAPI, SQLAlchemy 2.0, asyncpg, psycopg2-binary, Alembic, Pydantic v2, pytest, httpx, Flutter 3.47.7 (Dart 3.13.5), Riverpod v2, GoRouter, Dio, PostgreSQL 16 on VPS.

**Spec:** `docs/superpowers/specs/2026-11-01-phase-0-foundation-design.md`

## Global Constraints

- Backend must use SQLAlchemy 2.0 conventions (DeclarativeBase, async session).
- Primary keys must be UUIDv4 (`uuid.uuid4`).
- Money values must use `sa.Numeric(precision=12, scale=2)` (not floating point).
- Timestamps must be timezone-aware UTC (`datetime.now(timezone.utc)`).
- Secrets must never be committed to git (use `.env` and `.env.example`).
- Database on VPS must be isolated (`laundrytrack_db` and `laundrytrack_user`) without touching other databases.
- Zero business feature code (auth, orders, customers, etc.) may be written in Phase 0.
- Mandatory post-task markdown documentation in `.ai/tasks/` must be generated upon completion.

## Review Focus

1. **VPS Database Connectivity:** Database credentials and connection string work across local host and VPS PostgreSQL without socket timeout or authentication failure.
2. **Alembic Migration Integrity:** Alembic can initialize, auto-detect metadata, and execute migrations cleanly without corrupting the existing VPS container.
3. **Health Check Accuracy:** `/api/v1/health` accurately probes the database connection (executing `SELECT 1`) and returns a structured response rather than a static 200 OK.
4. **CORS & Network Boundaries:** Flutter Web can send cross-origin requests to FastAPI without being blocked by browser CORS policies.
5. **Architectural Consistency:** Project layout strictly follows `.ai/FLOWS_AND_PATTERNS.md` and `AGENTS.md`.

---

### Task 1: VPS Database Provisioning & Security Isolation

**Files:**
- Create: `backend/.env.example`
- Create: `backend/.env` (gitignored)
- Test: Remote query execution on VPS

**Steps:**
- [ ] Connect to VPS via SSH and check container `postgresql`.
- [ ] Create user `laundrytrack_user` with strong password and create database `laundrytrack_db` owned by `laundrytrack_user`.
- [ ] Grant appropriate privileges to `laundrytrack_user` on `laundrytrack_db`.
- [ ] Verify direct connection to `laundrytrack_db` from local host.
- [ ] Create `backend/.env.example` and `backend/.env` with secure database connection strings (both async `postgresql+asyncpg://` and sync `postgresql://` for Alembic).

---

### Task 2: Architecture Documentation, Coding Guidelines & Git Initialization

**Files:**
- Create: `.gitignore`
- Create: `AGENTS.md`
- Create: `.ai/FLOWS_AND_PATTERNS.md`
- Create: `README.md`

**Steps:**
- [ ] Initialize git repository in root (`git init`).
- [ ] Create comprehensive `.gitignore` covering Python (`.venv`, `__pycache__`, `.env`), Flutter/Dart (`.dart_tool/`, `build/`), IDEs, and OS files.
- [ ] Create `AGENTS.md` documenting the multi-agent delegation protocol, post-task documentation rules, coding standards, and project constraints.
- [ ] Create `.ai/FLOWS_AND_PATTERNS.md` mapping the modular monolith architecture, entry point -> validation -> business logic -> ORM -> output flow, Odoo/SaaS alignment patterns, and error handling.
- [ ] Create `README.md` with system overview, architecture diagram, and instructions to run local development.

---

### Task 3: Backend FastAPI Modular Monolith Scaffolding & Health Check

**Files:**
- Create: `backend/requirements.txt`
- Create: `backend/app/__init__.py`
- Create: `backend/app/main.py`
- Create: `backend/app/core/config.py`
- Create: `backend/app/core/database.py`
- Create: `backend/app/core/exceptions.py`
- Create: `backend/app/shared/models.py`
- Create: `backend/app/modules/health/router.py`
- Create: `backend/app/modules/health/schemas.py`
- Create: `backend/tests/conftest.py`
- Create: `backend/tests/test_health.py`

**Steps:**
- [ ] Create virtual environment in `backend/.venv` and install `backend/requirements.txt`.
- [ ] Implement `backend/app/core/config.py` using `pydantic-settings` to load environment variables.
- [ ] Implement `backend/app/core/database.py` providing async SQLAlchemy engine, session maker, and DB health probe function.
- [ ] Implement `backend/app/shared/models.py` providing `Base` (`DeclarativeBase`), `UUIDMixin`, and `TimestampMixin`.
- [ ] Implement `backend/app/modules/health/schemas.py` and `router.py` handling `GET /api/v1/health`.
- [ ] Wire up FastAPI application in `backend/app/main.py` with CORS middleware, lifespan events, and health router.
- [ ] Write integration test in `backend/tests/test_health.py` using `httpx.AsyncClient` verifying `/api/v1/health` returns status `healthy` and `database: healthy`.
- [ ] Run pytest to verify all tests pass.

---

### Task 4: Alembic Database Migration Setup & Initial Baseline Migration

**Files:**
- Create: `backend/alembic.ini`
- Create: `backend/migrations/env.py`
- Create: `backend/migrations/script.py.mako`
- Create: `backend/migrations/versions/`

**Steps:**
- [ ] Initialize Alembic in `backend/` configured to import `Base` from `app.shared.models` and read database URL from `app.core.config.settings`.
- [ ] Configure `migrations/env.py` for both offline and online migrations.
- [ ] Generate initial baseline migration (`alembic revision --autogenerate -m "initial_baseline"`).
- [ ] Run migration upgrade against the VPS database (`alembic upgrade head`).
- [ ] Verify `alembic_version` table exists in `laundrytrack_db` on VPS.

---

### Task 5: Frontend Flutter Web Baseline & End-to-End Connectivity

**Files:**
- Create: `frontend/` (via `flutter create --platforms web .`)
- Modify: `frontend/pubspec.yaml`
- Create: `frontend/lib/core/network/api_client.dart`
- Create: `frontend/lib/core/router/app_router.dart`
- Create: `frontend/lib/core/theme/app_theme.dart`
- Create: `frontend/lib/features/health/presentation/health_screen.dart`
- Modify: `frontend/lib/main.dart`
- Create: `frontend/test/health_widget_test.dart`

**Steps:**
- [ ] Scaffold Flutter Web project in `frontend/`.
- [ ] Add packages: `flutter_riverpod`, `dio`, `go_router`.
- [ ] Implement Dio `ApiClient` in `frontend/lib/core/network/api_client.dart` with base URL configuration and timeout settings.
- [ ] Implement `HealthScreen` showing visual indicator for Backend API and VPS Database status.
- [ ] Setup `GoRouter` in `frontend/lib/core/router/app_router.dart` routing `/` to `HealthScreen`.
- [ ] Configure `AppTheme` with clean Material 3 design and Indonesian locale format.
- [ ] Run `flutter test` to verify widget and logic tests pass.
- [ ] Test Flutter Web build (`flutter build web`) to verify compilation success.

---

### Task 6: Multi-Agent Protocol Verification & Post-Task Documentation

**Files:**
- Create: `.ai/tasks/2026-11-01_phase-0-fondasi-proyek.md`

**Steps:**
- [ ] Invoke subagent `code-reviewer` to audit code quality across the 5 dimensions (Correctness, Readability, Architecture, Security, Performance).
- [ ] Invoke subagent `security-auditor` to audit database credentials handling, VPS exposure, and CORS security.
- [ ] Invoke subagent `test-engineer` to verify test coverage and test suite robustness.
- [ ] Write post-task markdown documentation in `.ai/tasks/2026-11-01_phase-0-fondasi-proyek.md`.
- [ ] Create initial git commit: `feat: phase 0 project foundation complete`.
- [ ] Present comprehensive completion report to the user.
