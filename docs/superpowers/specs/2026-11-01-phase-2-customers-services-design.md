# Technical Design Specification: Phase 2 — Customer & Service Management

- **Fase**: Phase 2 — Pelanggan dan Layanan (Customers & Services)
- **Status**: Disetujui untuk Implementasi
- **Tanggal**: 2026-11-01
- **Target Database**: PostgreSQL 16 pada VPS (`45.66.153.146:5432 / laundrytrack_db`)

---

## 1. Tujuan & Ruang Lingkup

Fase ini mengimplementasikan manajemen data master operasional untuk:
1. **Pelanggan (Customers)**:
   - Pencatatan pelanggan per tenant dengan informasi nama, nomor WhatsApp/telepon, email, alamat, dan catatan preferensi laundry.
   - Pencarian cepat pelanggan berdasarkan nama atau nomor telepon (dengan indeks database).
   - Pengarsipan/penonaktifan pelanggan jika memiliki riwayat transaksi, agar tidak merusak integritas audit.
   - Endpoint ringkasan pelanggan (total pesanan, total pengeluaran).
2. **Layanan Laundry (Services)**:
   - Katalog layanan laundry per tenant dengan jenis harga (`per_kg` atau `per_item`).
   - Penetapan harga menggunakan `Numeric(12, 2)` (Python `Decimal`).
   - Estimasi durasi pengerjaan dalam satuan jam (opsional, untuk perhitungan batas waktu pesanan di Phase 3).
   - Penonaktifan layanan sehingga tidak dapat dipilih untuk pesanan baru tanpa merusak referensi historis.
3. **Frontend UI Flutter Web**:
   - Menu navigasi Pelanggan & Layanan terintegrasi pada Dashboard.
   - Daftar pelanggan dengan pencarian instan dan dialog tambah/ubah pelanggan.
   - Katalog layanan dengan tab/filter Kiloan vs Satuan dan formulir pembuatan layanan baru.

---

## 2. Arsitektur Data & Model ORM

### 2.1 Model `Customer` (`backend/app/modules/customers/models.py`)
```python
class Customer(Base, UUIDMixin, TimestampMixin):
    __tablename__ = "customers"

    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        sa.ForeignKey("tenants.id", ondelete="CASCADE"),
        index=True,
        nullable=False,
    )
    name: Mapped[str] = mapped_column(sa.String(255), index=True, nullable=False)
    phone: Mapped[Optional[str]] = mapped_column(sa.String(32), index=True, nullable=True)
    email: Mapped[Optional[str]] = mapped_column(sa.String(255), nullable=True)
    address: Mapped[Optional[str]] = mapped_column(sa.Text, nullable=True)
    notes: Mapped[Optional[str]] = mapped_column(sa.Text, nullable=True)
    is_active: Mapped[bool] = mapped_column(
        sa.Boolean, default=True, server_default=sa.text("true"), index=True, nullable=False
    )

    # Relationships
    tenant = relationship("Tenant", back_populates="customers")
```
- **Indeks**:
  - `ix_customers_tenant_id`
  - `ix_customers_name`
  - `ix_customers_phone`
  - Indeks komposit `(tenant_id, is_active)` untuk efisiensi filter per tenant.

### 2.2 Model `Service` (`backend/app/modules/services/models.py`)
```python
class PriceType(str, enum.Enum):
    PER_KG = "per_kg"
    PER_ITEM = "per_item"

class Service(Base, UUIDMixin, TimestampMixin):
    __tablename__ = "services"

    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        sa.ForeignKey("tenants.id", ondelete="CASCADE"),
        index=True,
        nullable=False,
    )
    name: Mapped[str] = mapped_column(sa.String(255), index=True, nullable=False)
    description: Mapped[Optional[str]] = mapped_column(sa.Text, nullable=True)
    price_type: Mapped[str] = mapped_column(sa.String(32), nullable=False)  # "per_kg" | "per_item"
    unit: Mapped[str] = mapped_column(sa.String(32), default="kg", nullable=False) # "kg", "pcs", "meter", etc.
    price: Mapped[Decimal] = mapped_column(sa.Numeric(12, 2), nullable=False)
    estimated_duration_hours: Mapped[Optional[int]] = mapped_column(sa.Integer, nullable=True)
    is_active: Mapped[bool] = mapped_column(
        sa.Boolean, default=True, server_default=sa.text("true"), index=True, nullable=False
    )

    # Relationships
    tenant = relationship("Tenant", back_populates="services")
```

---

## 3. Alur Eksekusi API & Validasi

Setiap endpoint API mengimplementasikan 5 tahap standar:
`Router -> Pydantic Schema -> Service Layer -> SQLAlchemy 2.0 ORM -> Response Schema`

### 3.1 Endpoints Pelanggan (`/api/v1/customers`)
1. `GET /api/v1/customers`:
   - Query: `page=1`, `page_size=20`, `q="budi"`, `is_active=true`
   - Filter ketat: `Customer.tenant_id == current_tenant.id`
   - Menghasilkan daftar pelanggan berpaginasi beserta total count.
2. `POST /api/v1/customers`:
   - Body: `name`, `phone`, `email`, `address`, `notes`
   - Otomatis mengisi `tenant_id = current_tenant.id`
   - Validasi nomor telepon dan sanitasi teks.
3. `GET /api/v1/customers/{id}`:
   - Verifikasi `customer.tenant_id == current_tenant.id`. Return 404 jika bukan milik tenant yang sama (pencegahan IDOR).
4. `PATCH /api/v1/customers/{id}`:
   - Partial update data pelanggan.
5. `DELETE /api/v1/customers/{id}`:
   - Soft-delete: Mengubah `is_active = False` untuk menjaga jejak riwayat audit transaksi.
6. `GET /api/v1/customers/{id}/orders`:
   - Menyiapkan endpoint riwayat pesanan (kosong pada Phase 2, terhubung pada Phase 3).
7. `GET /api/v1/customers/{id}/summary`:
   - Ringkasan total transaksi dan omzet dari pelanggan tersebut.

### 3.2 Endpoints Layanan (`/api/v1/services`)
1. `GET /api/v1/services`:
   - Query: `page=1`, `page_size=50`, `q="cuci"`, `price_type="per_kg"`, `is_active=true`
   - Filter ketat: `Service.tenant_id == current_tenant.id`
2. `POST /api/v1/services`:
   - Body: `name`, `description`, `price_type`, `unit`, `price`, `estimated_duration_hours`, `is_active`
   - Validasi: `price > 0`, `price_type` in `["per_kg", "per_item"]`.
3. `GET /api/v1/services/{id}`:
   - Verifikasi kepemilikan tenant. Return 404 jika cross-tenant.
4. `PATCH /api/v1/services/{id}`:
   - Update harga atau nama layanan. Catatan: Perubahan harga layanan di sini tidak memengaruhi snapshot order di masa depan.
5. `DELETE /api/v1/services/{id}`:
   - Soft-delete (`is_active = False`) agar layanan nonaktif tidak dapat dipilih untuk pesanan baru namun data pesanan lama tetap aman.

---

## 4. Frontend UI Design (Flutter Web)

1. **Dashboard Navigation**:
   - Sidebar navigasi desktop dan bottom/drawer mobile menyediakan tautan langsung ke tab:
     - "Dashboard" (Ringkasan)
     - "Pelanggan" (Customer Management)
     - "Layanan" (Service Catalog)
2. **Customer Management Screen**:
   - Search bar interaktif dengan debouncing untuk pencarian nama atau nomor HP.
   - Tombol "+ Pelanggan Baru" membuka Dialog form responsif.
   - Card item pelanggan dengan info kontak, alamat, dan tombol edit/nonaktifkan.
3. **Service Catalog Screen**:
   - Segmented Button / Tabs: "Semua", "Kiloan (per kg)", "Satuan (per pcs)".
   - Tombol "+ Tambah Layanan".
   - Indikator status layanan (Aktif / Nonaktif), badge harga IDR terformat, dan durasi pengerjaan.

---

## 5. Rencana Pengujian & Quality Gate

1. **Unit & Integration Tests (`pytest`)**:
   - CRUD Pelanggan (create, get, list, search by name/phone, update, soft delete).
   - CRUD Layanan (create kiloan, create satuan, price Decimal validation, search, update price, soft delete).
   - **Strict Tenant Isolation**: Memastikan tenant A tidak dapat melihat, mengubah, atau menghapus pelanggan & layanan milik tenant B via direct ID probing (404/IDOR prevention).
2. **Frontend Tests (`flutter test`)**:
   - Render layar pelanggan & katalog layanan.
   - Filter pencarian dan input form.
   - Responsivitas mobile viewport.
3. **Verifikasi VPS PostgreSQL**:
   - Migrasi Alembic diterapkan ke database live `laundrytrack_db`.
