# Technical Design Specification: Phase 4 — Payment & Refund Management

- **Fase**: Phase 4 — Manajemen Pembayaran & Refund (Payment & Refund Management)
- **Status**: Disetujui untuk Implementasi
- **Tanggal**: 2026-11-02
- **Target Database**: PostgreSQL 16 pada VPS (`45.66.153.146:5432 / laundrytrack_db`)

---

## 1. Tujuan & Ruang Lingkup

Fase ini mengimplementasikan sistem pencatatan keuangan transaksi pembayaran dan refund untuk LaundryTrack:
1. **Pencatatan Pembayaran Fleksibel & Terkendali**:
   - Mendukung pembayaran lunas maupun bertahap (cicilan/uang muka: `partial`).
   - Berbagai metode pembayaran: Tunai (`cash`), QRIS (`qris`), Transfer Bank (`bank_transfer`), Kartu Debit (`debit`).
   - Input nomor referensi transaksi eksternal (misal: ID transaksi QRIS, reference code transfer).
   - Validasi ketat overpayment: nominal pembayaran tidak boleh melebihi sisa tagihan (`remaining_amount`).
   - Pessimistic locking (`with_for_update()`) pada order untuk mencegah race condition pembayaran bersamaan.
2. **Pengembalian Dana (Refunds) & Immutable Ledger**:
   - Transaksi pembayaran bersifat kekal (*immutable*); tidak boleh diubah atau dihapus dari database.
   - Pengembalian dana dicatat sebagai record tersendiri di tabel `refunds` dengan relasi ke `payment` dan `order`.
   - Refund parsial maupun penuh dengan validasi bahwa total refund tidak boleh melebihi nominal pembayaran terkait.
   - Wajib mencantumkan alasan pengembalian dana (`reason`).
   - Perhitungan otomatis sisa tagihan pesanan dan pembaruan status pembayaran pesanan (`unpaid`, `partial`, `paid`, `refunded`).
3. **Integritas Pembatalan Pesanan**:
   - Pesanan yang memiliki saldo pembayaran aktif (`paid_amount > 0`) tidak dapat dibatalkan begitu saja sebelum seluruh dana di-refund secara akuntabel.
4. **Otorisasi & RBAC**:
   - Pembayaran dapat dicatat oleh role: `owner`, `admin`, `cashier`.
   - Refund memerlukan wewenang lebih tinggi: hanya `owner` dan `admin`.
5. **Antarmuka Kasir (Flutter Web)**:
   - Dialog pencatatan pembayaran kasir: tombol cepat nominal uang (uang pas, 20.000, 50.000, 100.000), kalkulator kembalian tunai, pilihan metode bayar, dan catatan/referensi.
   - Tab/bagian riwayat pembayaran dan refund di `OrderDetailDialog`.
   - Dialog otorisasi refund untuk owner/admin.
   - Badge status pembayaran pada card daftar pesanan.

---

## 2. Arsitektur Data & Model ORM

### 2.1 Model `Payment` (`backend/app/modules/payments/models.py`)
```python
class PaymentMethod(str, enum.Enum):
    CASH = "cash"
    QRIS = "qris"
    BANK_TRANSFER = "bank_transfer"
    DEBIT = "debit"

class PaymentRecordStatus(str, enum.Enum):
    PAID = "paid"
    PARTIALLY_REFUNDED = "partially_refunded"
    REFUNDED = "refunded"

class Payment(Base, UUIDMixin, TimestampMixin):
    __tablename__ = "payments"

    tenant_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), sa.ForeignKey("tenants.id", ondelete="CASCADE"), index=True, nullable=False)
    outlet_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), sa.ForeignKey("outlets.id", ondelete="RESTRICT"), index=True, nullable=False)
    order_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), sa.ForeignKey("orders.id", ondelete="RESTRICT"), index=True, nullable=False)
    received_by_id: Mapped[Optional[uuid.UUID]] = mapped_column(UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="SET NULL"), nullable=True)

    amount: Mapped[Decimal] = mapped_column(sa.Numeric(precision=12, scale=2), nullable=False)
    payment_method: Mapped[str] = mapped_column(sa.String(32), default=PaymentMethod.CASH.value, nullable=False)
    reference_number: Mapped[Optional[str]] = mapped_column(sa.String(64), nullable=True)
    status: Mapped[str] = mapped_column(sa.String(32), default=PaymentRecordStatus.PAID.value, nullable=False)
    paid_at: Mapped[datetime] = mapped_column(sa.DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), server_default=sa.text("now()"), nullable=False)
    notes: Mapped[Optional[str]] = mapped_column(sa.Text, nullable=True)

    __table_args__ = (
        sa.Index("ix_payments_tenant_order", "tenant_id", "order_id"),
        sa.Index("ix_payments_tenant_outlet", "tenant_id", "outlet_id"),
        sa.Index("ix_payments_tenant_paid_at", "tenant_id", "paid_at"),
    )
```

### 2.2 Model `Refund` (`backend/app/modules/payments/models.py`)
```python
class Refund(Base, UUIDMixin, TimestampMixin):
    __tablename__ = "refunds"

    tenant_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), sa.ForeignKey("tenants.id", ondelete="CASCADE"), index=True, nullable=False)
    outlet_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), sa.ForeignKey("outlets.id", ondelete="RESTRICT"), index=True, nullable=False)
    payment_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), sa.ForeignKey("payments.id", ondelete="RESTRICT"), index=True, nullable=False)
    order_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), sa.ForeignKey("orders.id", ondelete="RESTRICT"), index=True, nullable=False)
    refunded_by_id: Mapped[Optional[uuid.UUID]] = mapped_column(UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="SET NULL"), nullable=True)

    amount: Mapped[Decimal] = mapped_column(sa.Numeric(precision=12, scale=2), nullable=False)
    reason: Mapped[str] = mapped_column(sa.Text, nullable=False)
    refunded_at: Mapped[datetime] = mapped_column(sa.DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), server_default=sa.text("now()"), nullable=False)

    __table_args__ = (
        sa.Index("ix_refunds_tenant_payment", "tenant_id", "payment_id"),
        sa.Index("ix_refunds_tenant_order", "tenant_id", "order_id"),
    )
```

---

## 3. Logika Bisnis & Rumus Keuangan (Decimal Precision)

1. **Pencatatan Pembayaran Baru (`POST /orders/{id}/payments`)**:
   - Kunci record Order: `SELECT * FROM orders WHERE id = :order_id AND tenant_id = :tenant_id FOR UPDATE`
   - Validasi:
     - `order.status != OrderStatus.CANCELLED.value` (pesanan dibatalkan tidak boleh dibayar).
     - `payload.amount > 0`.
     - `payload.amount <= order.remaining_amount` (mencegah overpayment).
   - Buat record `Payment`:
     - `payment = Payment(..., amount=payload.amount, status=PaymentRecordStatus.PAID.value)`
   - Mutasi saldo Order:
     - `order.paid_amount = (order.paid_amount + payload.amount).quantize(Decimal("0.01"))`
     - `order.remaining_amount = (order.total_amount - order.paid_amount).quantize(Decimal("0.01"))`
     - `order.payment_status = PaymentStatus.PAID.value` jika `order.remaining_amount == 0` else `PaymentStatus.PARTIAL.value`

2. **Pencatatan Refund (`POST /payments/{id}/refunds`)**:
   - Kunci record Payment dan Order dengan `FOR UPDATE`.
   - Hitung total refund eksisting untuk payment ini: `existing_refund_sum = SUM(refunds.amount)`
   - Sisa yang dapat direfund dari payment ini: `max_refundable = payment.amount - existing_refund_sum`
   - Validasi:
     - `payload.amount > 0`
     - `payload.amount <= max_refundable`
     - `payload.amount <= order.paid_amount`
     - `len(payload.reason.strip()) >= 3`
   - Buat record `Refund`.
   - Update status Payment:
     - Jika `existing_refund_sum + payload.amount == payment.amount`: `payment.status = PaymentRecordStatus.REFUNDED.value`
     - Lainnya: `payment.status = PaymentRecordStatus.PARTIALLY_REFUNDED.value`
   - Mutasi saldo Order:
     - `order.paid_amount = (order.paid_amount - payload.amount).quantize(Decimal("0.01"))`
     - `order.remaining_amount = (order.total_amount - order.paid_amount).quantize(Decimal("0.01"))`
     - Pembaruan `order.payment_status`:
       - Jika `order.paid_amount == 0`: `PaymentStatus.REFUNDED.value` (jika pernah dibayar lalu di-refund habis) atau `PaymentStatus.UNPAID.value`
       - Jika `order.remaining_amount == 0`: `PaymentStatus.PAID.value`
       - Lainnya: `PaymentStatus.PARTIAL.value`

---

## 4. API Endpoints Contract

1. `POST /api/v1/orders/{order_id}/payments`
   - Roles: `owner`, `admin`, `cashier`
   - Request Body:
     ```json
     {
       "amount": "40000.00",
       "payment_method": "cash",
       "reference_number": null,
       "notes": "Uang pas"
     }
     ```
   - Response: `PaymentResponse` (HTTP 201)

2. `GET /api/v1/orders/{order_id}/payments`
   - Roles: `owner`, `admin`, `cashier`, `operator`
   - Response: `List[PaymentResponse]` (HTTP 200)

3. `GET /api/v1/payments/{payment_id}`
   - Roles: `owner`, `admin`, `cashier`, `operator`
   - Response: `PaymentDetailResponse` (HTTP 200, beserta detail refunds)

4. `POST /api/v1/payments/{payment_id}/refunds`
   - Roles: `owner`, `admin`
   - Request Body:
     ```json
     {
       "amount": "20000.00",
       "reason": "Pembatalan sebagian pakaian atau diskon susulan"
     }
     ```
   - Response: `RefundResponse` (HTTP 201)

5. `GET /api/v1/payments`
   - Roles: `owner`, `admin`, `cashier`
   - Query: `order_id`, `payment_method`, `status`, `page`, `page_size`
   - Response: `PaginatedResponse[PaymentResponse]` (HTTP 200)

---

## 5. UI/UX Kasir (Flutter Web)

1. **Tombol "Catat Pembayaran" di Order Detail:**
   - Hanya muncul jika `order.remainingAmount > 0` dan `order.status != 'cancelled'`.
2. **Dialog Pembayaran (`PaymentFormDialog`):**
   - Menampilkan sisa tagihan yang harus dibayar.
   - Pilihan metode bayar: Tunai, QRIS, Transfer Bank, Debit (SegmentedButton / ChoiceChips).
   - Untuk Tunai:
     - Quick chips nominal: Uang Pas, Rp20.000, Rp50.000, Rp100.000.
     - Field input "Uang Diterima".
     - Live indicator "Kembalian: Rp X.XXX" (jika uang diterima > tagihan, nominal yang dicatat ke sistem tetap sebesar tagihan, kembalian dihitung untuk panduan kasir).
   - Field Nomor Referensi (opsional/wajib untuk non-tunai) dan Catatan.
3. **Riwayat Pembayaran di Order Detail:**
   - List transaksi pembayaran: tanggal, kasir penerima, metode, nominal, badge status (`Lunas`, `Refund Sebagian`, `Direfund`).
   - Tampilan item refund di bawah pembayaran terkait.
   - Tombol "Refund" per transaksi pembayaran (khusus role `owner` / `admin`).
4. **Dialog Refund (`RefundFormDialog`):**
   - Input nominal refund (maksimal sisa saldo pembayaran yang belum direfund).
   - Input alasan refund (wajib).
