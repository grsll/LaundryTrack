# Phase 1: Auth & Multi-Tenancy Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement robust multi-tenant authentication, atomic business onboarding, RBAC permissions, JWT token rotation/revocation, and Flutter Web Login/Register UI with route guards.

**Architecture:** Modular monolith backend with dedicated modules (`auth`, `tenants`, `outlets`, `users`). Atomic onboarding transactions creating User, Tenant, Outlet, TenantUser, OutletUser, and Subscription in a single DB session. Strict backend resolution of active tenant context via verified JWT access tokens. Flutter Web client with Riverpod session state and GoRouter redirect guards.

**Tech Stack:** Python 3.14, FastAPI, SQLAlchemy 2.0 Async, Alembic, PostgreSQL 16 (VPS), pwdlib/argon2, bcrypt, python-jose, Flutter 3.47.7, Riverpod v2, Dio, GoRouter.

**Spec:** `docs/superpowers/specs/2026-11-01-phase-1-auth-multitenancy-design.md`

## Global Constraints

- Tenant ID must ALWAYS be derived from verified JWT session; never accepted blindly from client request body/query.
- Atomic registration: All 6 onboarding entities must commit or rollback together.
- Passwords must be hashed using Argon2id / bcrypt.
- Refresh tokens must be stored as SHA-256 hashes in database and rotated on each refresh call.
- All new models must use `Base` with `UUIDMixin` and `TimestampMixin`.
- Mandatory post-task markdown documentation in `.ai/tasks/` must be generated upon completion.

## Review Focus

1. **Atomic Rollback on Conflict:** If registration fails due to duplicate email or phone, no orphan Tenant, Outlet, or Subscription is created.
2. **Tenant Context Resolution:** Endpoint `GET /api/v1/auth/me` resolves the active tenant correctly without any client parameter tampering.
3. **Token Rotation & Revocation:** Old refresh tokens cannot be reused after being refreshed or logged out.
4. **Cross-Tenant Access Rejection:** A user from Tenant A cannot view or manipulate data belonging to Tenant B.
5. **Frontend Guarding:** Unauthenticated users accessing `/dashboard` are immediately redirected to `/login`.

---

### Task 1: Database Models & Alembic Migration for Auth & Multi-Tenancy

**Files:**
- Create: `backend/app/modules/tenants/models.py`
- Create: `backend/app/modules/outlets/models.py`
- Create: `backend/app/modules/users/models.py`
- Create: `backend/app/modules/subscriptions/models.py`
- Create: `backend/app/modules/auth/models.py` (RefreshToken)
- Modify: `backend/app/shared/models.py`
- Create: `backend/migrations/versions/..._auth_and_multitenancy.py`

**Steps:**
- [ ] Define `Tenant` model in `app/modules/tenants/models.py`.
- [ ] Define `Outlet` model in `app/modules/outlets/models.py`.
- [ ] Define `User`, `TenantUser`, `OutletUser` models in `app/modules/users/models.py` with Role and UserType enums.
- [ ] Define `Subscription` model in `app/modules/subscriptions/models.py`.
- [ ] Define `RefreshToken` model in `app/modules/auth/models.py`.
- [ ] Re-export all models in `app/shared/models.py` so Alembic auto-detects metadata.
- [ ] Run `alembic revision --autogenerate -m "create_auth_and_multitenancy_tables"`.
- [ ] Run `alembic upgrade head` against VPS PostgreSQL database.
- [ ] Verify all tables exist on VPS `laundrytrack_db`.

---

### Task 2: Core Security Utilities & Dependency Injection

**Files:**
- Create: `backend/app/core/security.py`
- Modify: `backend/app/core/dependencies.py`

**Steps:**
- [ ] Implement password hashing and verification in `app/core/security.py` using `pwdlib` (Argon2id) / `bcrypt`.
- [ ] Implement JWT token generation for access token (payload: sub, tenant_id, outlet_id, role, type="access", exp).
- [ ] Implement refresh token generation and SHA-256 token hashing.
- [ ] Implement `get_current_user` dependency in `app/core/dependencies.py` to validate Bearer token.
- [ ] Implement `get_current_tenant` dependency to extract and verify active tenant context.
- [ ] Implement `require_roles(*roles)` RBAC permission checker dependency.

---

### Task 3: Backend Auth Schemas, Service & Endpoints

**Files:**
- Create: `backend/app/modules/auth/schemas.py`
- Create: `backend/app/modules/auth/service.py`
- Create: `backend/app/modules/auth/router.py`
- Modify: `backend/app/main.py`

**Steps:**
- [ ] Define Pydantic schemas in `schemas.py` for RegisterRequest, LoginRequest, RefreshRequest, AuthResponse, UserProfileResponse.
- [ ] Implement `AuthService` with methods: `register_business`, `authenticate_user`, `refresh_tokens`, `logout_user`, `get_user_profile`.
- [ ] Implement atomic onboarding transaction in `AuthService.register_business`.
- [ ] Implement router endpoints in `router.py`:
  - `POST /api/v1/auth/register`
  - `POST /api/v1/auth/login`
  - `POST /api/v1/auth/refresh`
  - `POST /api/v1/auth/logout`
  - `GET /api/v1/auth/me`
- [ ] Mount auth router in `app/main.py`.

---

### Task 4: Comprehensive Backend Test Suite

**Files:**
- Create: `backend/tests/test_auth.py`
- Create: `backend/tests/test_tenant_isolation.py`

**Steps:**
- [ ] Write tests for business registration (happy path: returns tokens, tenant, outlet, user).
- [ ] Write tests for registration validation & rollback on duplicate email/phone.
- [ ] Write tests for staff login with email and phone.
- [ ] Write tests for refresh token rotation (asserting old refresh token is rejected once rotated).
- [ ] Write tests for logout revocation.
- [ ] Write tests for `GET /api/v1/auth/me` validating active tenant/outlet context.
- [ ] Write tests for tenant isolation (User A cannot access Tenant B profile/data).
- [ ] Run pytest to verify all tests pass.

---

### Task 5: Frontend Flutter Web Auth Integration & UI

**Files:**
- Create: `frontend/lib/core/network/auth_interceptor.dart`
- Create: `frontend/lib/features/auth/data/auth_model.dart`
- Create: `frontend/lib/features/auth/data/auth_repository.dart`
- Create: `frontend/lib/features/auth/providers/auth_provider.dart`
- Create: `frontend/lib/features/auth/presentation/login_screen.dart`
- Create: `frontend/lib/features/auth/presentation/register_screen.dart`
- Create: `frontend/lib/features/dashboard/presentation/dashboard_screen.dart`
- Modify: `frontend/lib/core/router/app_router.dart`
- Create: `frontend/test/auth_flow_test.dart`

**Steps:**
- [ ] Implement `AuthInterceptor` adding `Authorization: Bearer <token>` to Dio requests.
- [ ] Implement `AuthRepository` calling auth API endpoints.
- [ ] Implement Riverpod `authProvider` handling login, register, logout, and session state.
- [ ] Implement `LoginScreen` with email/phone & password validation, loading, and error states.
- [ ] Implement `RegisterBusinessScreen` with owner, business, and outlet inputs.
- [ ] Implement `DashboardScreen` displaying business name, active outlet, user role, and logout button.
- [ ] Update `AppRouter` with authentication redirect guards (`/login`, `/register`, `/dashboard`).
- [ ] Write widget tests for login & register flows in `frontend/test/auth_flow_test.dart`.
- [ ] Run `flutter test` and `flutter build web`.

---

### Task 6: Multi-Agent Audit & Post-Task Documentation

**Files:**
- Create: `.ai/tasks/2026-11-01_phase-1-auth-multitenancy.md`

**Steps:**
- [ ] Invoke `test-engineer` to verify test coverage and test suite robustness.
- [ ] Invoke `code-reviewer` to audit code quality across the 5 dimensions.
- [ ] Invoke `security-auditor` to audit authentication, token handling, and tenant isolation.
- [ ] Address all findings and verify green status.
- [ ] Write post-task markdown documentation.
- [ ] Create git commit: `feat: phase 1 auth and multi-tenancy complete`.
- [ ] Present completion report to the user.
