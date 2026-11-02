# Technical Design Specification: Phase 3 — Order Management

- **Fase**: Phase 3 — Manajemen Pesanan (Order Management)
- **Status**: Disetujui untuk Implementasi
- **Tanggal**: 2026-11-02
- **Target Database**: PostgreSQL 16 pada VPS (`45.66.153.146:5432 / laundrytrack_db`)

---

## 1. Tujuan & Ruang Lingkup

Fase ini mengimplementasikan sistem inti operasional pencatatan pesanan (order processing core) untuk laundry kiloan dan satuan:
1. **Pembuatan Pesanan Atomik**:
   - Validasi ketat bahwa `customer_id` dan seluruh `service_id` adalah milik tenant yang sama dan berstatus aktif.
   - **Snapshotting Immutability**: Informasi nama layanan, jenis harga (`per_kg`/`per_item`), satuan (`kg`/`pcs`), dan harga satuan disalin sebagai snapshot permanen ke dalam tabel `order_items`.
   - **Penomoran Nota Anti-Race-Condition**: Penomoran berurut format `LDR-YYYYMMDD-XXXX` (misal: `LDR-20261102-0001`) yang dijamin unik di tingkat database menggunakan locking tabel counter `order_sequences` dengan `FOR UPDATE`.
   - **Kalkulasi Keuangan**: Subtotal, diskon, dan total dihitung secara eksklusif di backend menggunakan Python `Decimal` (bukan floating point).
2. **Siklus Status Pengerjaan (Status Pipeline)**:
   - Alur normal: `received -> washing -> drying -> ironing -> packaging -> ready -> completed`.
   - Transisi divalidasi dengan aturan state machine.
   - Setiap perubahan status otomatis tercatat dalam `order_status_logs` mencakup aktor (`changed_by_id`), waktu UTC, status lama, status baru, dan catatan.
3. **Pembatalan Pesanan**:
   - Pembatalan (`POST /orders/{id}/cancel`) dengan alasan wajib (`cancellation_reason`).
   - Pesanan berstatus `completed` ditolak untuk dibatalkan melalui alur normal.
4. **Antarmuka Kasir (Flutter Web)**:
   - Form pembuatan pesanan interaktif: pemilihan pelanggan, pemilihan item layanan (kiloan/satuan), kalkulasi otomatis subtotal dan diskon, serta tombol submit.
   - Daftar pesanan berpaginasi dengan filter status (Diterima, Proses Cuci, Selesai, Dibatalkan) dan pencarian nomor nota/nama pelanggan.
   - Detail pesanan dengan visual status timeline dan tombol transisi status.

---

## 2. Arsitektur Data & Model ORM

### 2.1 Model `Order` (`backend/app/modules/orders/models.py`)
```python
class OrderStatus(str, enum.Enum):
    RECEIVED = "received"
    WASHING = "washing"
    DRYING = "drying"
    IRONING = "ironing"
    PACKAGING = "packaging"
    READY = "ready"
    COMPLETED = "completed"
    CANCELLED = "cancelled"

class PaymentStatus(str, enum.Enum):
    UNPAID = "unpaid"
    PARTIAL = "partial"
    PAID = "paid"
    REFUNDED = "refunded"

class Order(Base, UUIDMixin, TimestampMixin):
    __tablename__ = "orders"

    tenant_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), sa.ForeignKey("tenants.id", ondelete="CASCADE"), index=True, nullable=False)
    outlet_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), sa.ForeignKey("outlets.id", ondelete="RESTRICT"), index=True, nullable=False)
    customer_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), sa.ForeignKey("customers.id", ondelete="RESTRICT"), index=True, nullable=False)
    created_by_id: Mapped[Optional[uuid.UUID]] = mapped_column(UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="SET NULL"), nullable=True)

    order_number: Mapped[str] = mapped_column(sa.String(64), index=True, nullable=False)
    status: Mapped[str] = mapped_column(sa.String(32), default=OrderStatus.RECEIVED.value, index=True, nullable=False)
    payment_status: Mapped[str] = mapped_column(sa.String(32), default=PaymentStatus.UNPAID.value, index=True, nullable=False)

    received_at: Mapped[datetime] = mapped_column(sa.DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), nullable=False)
    estimated_completion_at: Mapped[Optional[datetime]] = mapped_column(sa.DateTime(timezone=True), nullable=True)

    subtotal: Mapped[Decimal] = mapped_column(sa.Numeric(12, 2), nullable=False)
    discount_amount: Mapped[Decimal] = mapped_column(sa.Numeric(12, 2), default=Decimal("0.00"), nullable=False)
    total_amount: Mapped[Decimal] = mapped_column(sa.Numeric(12, 2), nullable=False)
    paid_amount: Mapped[Decimal] = mapped_column(sa.Numeric(12, 2), default=Decimal("0.00"), nullable=False)
    remaining_amount: Mapped[Decimal] = mapped_column(sa.Numeric(12, 2), nullable=False)

    notes: Mapped[Optional[str]] = mapped_column(sa.Text, nullable=True)
    cancellation_reason: Mapped[Optional[str]] = mapped_column(sa.Text, nullable=True)
    cancelled_at: Mapped[Optional[datetime]] = mapped_column(sa.DateTime(timezone=True), nullable=True)

    # Composite indexes
    __table_args__ = (
        sa.UniqueConstraint("tenant_id", "order_number", name="uq_orders_tenant_order_number"),
        sa.Index("ix_orders_tenant_outlet", "tenant_id", "outlet_id"),
        sa.Index("ix_orders_tenant_status", "tenant_id", "status"),
        sa.Index("ix_orders_tenant_customer", "tenant_id", "customer_id"),
    )
```

### 2.2 Model `OrderItem` (`backend/app/modules/orders/models.py`)
```python
class OrderItem(Base, UUIDMixin, TimestampMixin):
    __tablename__ = "order_items"

    tenant_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), sa.ForeignKey("tenants.id", ondelete="CASCADE"), index=True, nullable=False)
    order_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), sa.ForeignKey("orders.id", ondelete="CASCADE"), index=True, nullable=False)
    service_id: Mapped[Optional[uuid.UUID]] = mapped_column(UUID(as_uuid=True), sa.ForeignKey("services.id", ondelete="SET NULL"), nullable=True)

    # Immutability Snapshots
    service_name_snapshot: Mapped[str] = mapped_column(sa.String(255), nullable=False)
    price_type_snapshot: Mapped[str] = mapped_column(sa.String(32), nullable=False)
    unit_snapshot: Mapped[str] = mapped_column(sa.String(32), nullable=False)
    unit_price_snapshot: Mapped[Decimal] = mapped_column(sa.Numeric(12, 2), nullable=False)

    quantity: Mapped[Decimal] = mapped_column(sa.Numeric(12, 2), nullable=False)
    subtotal: Mapped[Decimal] = mapped_column(sa.Numeric(12, 2), nullable=False)
    notes: Mapped[Optional[str]] = mapped_column(sa.Text, nullable=True)
```

### 2.3 Model `OrderStatusLog` (`backend/app/modules/orders/models.py`)
```python
class OrderStatusLog(Base, UUIDMixin, TimestampMixin):
    __tablename__ = "order_status_logs"

    tenant_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), sa.ForeignKey("tenants.id", ondelete="CASCADE"), index=True, nullable=False)
    order_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), sa.ForeignKey("orders.id", ondelete="CASCADE"), index=True, nullable=False)
    changed_by_id: Mapped[Optional[uuid.UUID]] = mapped_column(UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="SET NULL"), nullable=True)

    previous_status: Mapped[Optional[str]] = mapped_column(sa.String(32), nullable=True)
    new_status: Mapped[str] = mapped_column(sa.String(32), nullable=False)
    notes: Mapped[Optional[str]] = mapped_column(sa.Text, nullable=True)
```

### 2.4 Model `OrderSequence` (Counter Anti-Race-Condition)
```python
class OrderSequence(Base, UUIDMixin):
    __tablename__ = "order_sequences"

    tenant_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), sa.ForeignKey("tenants.id", ondelete="CASCADE"), nullable=False)
    outlet_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), sa.ForeignKey("outlets.id", ondelete="CASCADE"), nullable=False)
    date_str: Mapped[str] = mapped_column(sa.String(8), nullable=False) # "YYYYMMDD"
    last_sequence: Mapped[int] = mapped_column(sa.Integer, default=0, nullable=False)

    __table_args__ = (
        sa.UniqueConstraint("tenant_id", "outlet_id", "date_str", name="uq_order_sequences_tenant_outlet_date"),
    )
```

---

## 3. Alur Eksekusi & Business Rules

### 3.1 Pembuatan Pesanan (`POST /api/v1/orders`)
1. **Validasi Pelanggan**: Pastikan `customer.tenant_id == current_tenant.id` dan `customer.is_active == True`.
2. **Validasi Layanan**: Untuk setiap line item, pastikan `service.tenant_id == current_tenant.id` dan `service.is_active == True`.
3. **Kalkulasi Backend**:
   - `item_subtotal = item.quantity * service.price`
   - `subtotal = sum(item_subtotal)`
   - `discount = min(payload.discount_amount or Decimal("0.00"), subtotal)`
   - `total_amount = subtotal - discount`
   - `remaining_amount = total_amount`
4. **Penomoran Atomik**:
   - Mengunci baris `order_sequences` untuk tanggal hari ini (`with_for_update()`).
   - Format: `f"LDR-{date_str}-{sequence:04d}"`.
5. **Simpan Atomik**:
   - Buat `Order`.
   - Buat seluruh `OrderItem` dengan snapshot.
   - Buat entri awal `OrderStatusLog(previous_status=None, new_status="received")`.
   - Commit transaksi.

### 3.2 Transisi Status Pengerjaan (`POST /api/v1/orders/{id}/status`)
Validasi transisi valid:
- `received -> [washing, cancelled]`
- `washing -> [drying, cancelled]`
- `drying -> [ironing, packaging, cancelled]`
- `ironing -> [packaging, ready, cancelled]`
- `packaging -> [ready, cancelled]`
- `ready -> [completed]`
- `completed -> []` (Terminal, tidak bisa diubah lagi)
- `cancelled -> []` (Terminal)

---

## 4. Rencana Pengujian

1. **Backend Tests (`test_orders.py`)**:
   - Create order with kiloan & satuan items, verify snapshotting and Decimal total calculations.
   - High concurrency / collision simulation on `order_number` generation.
   - Rejection of cross-tenant customer or service (IDOR protection).
   - Valid & invalid status transitions.
   - Cancellation with reason, rejection of cancelling completed order.
   - Strict tenant isolation: Tenant B cannot view, transition, or cancel Tenant A's orders.
2. **Frontend Tests (`order_flow_test.dart`)**:
   - Render order list screen, filter chips, and order cards.
   - Interactive order creation form validation.
   - Mobile responsive layout check (`390x844`).
