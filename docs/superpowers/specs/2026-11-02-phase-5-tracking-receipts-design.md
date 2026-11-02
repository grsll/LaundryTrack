# Technical Design Specification: Phase 5 — Public Tracking & Receipt Management

- **Fase**: Phase 5 — Pelacakan Publik & Manajemen Nota (Public Tracking & Receipt Management)
- **Status**: Disetujui untuk Implementasi
- **Tanggal**: 2026-11-02
- **Target Database**: PostgreSQL 16 pada VPS (`45.66.153.146:5432 / laundrytrack_db`)

---

## 1. Tujuan & Ruang Lingkup

Fase ini mengimplementasikan dua fitur utama yang menghubungkan operasional laundry dengan pelanggan:
1. **Portal Pelacakan Publik (Public Guest Tracking)**:
   - Pelanggan dapat memantau status cucian secara mandiri tanpa perlu membuat akun atau login (`GET /api/v1/tracking/{token}`).
   - Keamanan tinggi: Token pelacakan berentropi tinggi (`secrets.token_urlsafe(32)` / 256-bit entropy) yang di-generate otomatis saat pesanan dibuat.
   - Privasi pelanggan (*Data Minimization & Masking*): Nama pelanggan disamarkan (`Budi S*****`) dan nomor telepon disamarkan (`0812****7890`). ID database internal (`id`, `tenant_id`, `customer_id`, `staff_id`) tidak pernah diekspos ke publik.
   - Endpoint internal staf untuk mengambil link tracking (`GET /orders/{id}/tracking-link`) dan meregenerasi token jika tautan lama bocor (`POST /orders/{id}/tracking-link/regenerate`).
2. **Manajemen Nota Digital, Thermal Print, & PDF**:
   - **Nota Digital**: Endpoint payload nota lengkap (`GET /api/v1/orders/{id}/receipt`).
   - **Cetak Thermal 58mm & 80mm**: Endpoint HTML/CSS print template (`GET /api/v1/orders/{id}/receipt/thermal?width=58`) yang dioptimalkan untuk printer thermal POS kasir via browser dialog.
   - **Unduh PDF**: Endpoint file PDF (`GET /api/v1/orders/{id}/receipt/pdf`) menggunakan library Python ReportLab dengan QR code tracking tersemat (library `qrcode`).
   - **Audit Cetak Ulang**: Endpoint pencatatan cetak ulang (`POST /api/v1/orders/{id}/receipt/reprint`) untuk memantau frekuensi cetak nota (`reprint_count`).
3. **Antarmuka Pengguna (Flutter Web)**:
   - Halaman publik `/track/:token`: Desain responsif mobile-friendly untuk pelanggan melihat status progress cucian (stepper), rincian layanan, estimasi selesai, dan status pembayaran.
   - Integrasi kasir pada `OrderDetailDialog` & pasca-pembuatan pesanan:
     - Tombol "Cetak Thermal (58mm/80mm)".
     - Tombol "Unduh Nota PDF".
     - Tombol "Salin Link Tracking".
     - Tombol "Bagikan ke WhatsApp" (membuka wa.me dengan teks template rapi).

---

## 2. Arsitektur Data & Model ORM

### 2.1 Perubahan pada Model `Order` (`backend/app/modules/orders/models.py`)
Tambahkan kolom berikut pada tabel `orders`:
- `tracking_token`: `Mapped[str] = mapped_column(sa.String(64), unique=True, index=True, nullable=False)`
- `receipt_printed_at`: `Mapped[Optional[datetime]] = mapped_column(sa.DateTime(timezone=True), nullable=True)`
- `reprint_count`: `Mapped[int] = mapped_column(sa.Integer, default=0, server_default=sa.text("0"), nullable=False)`

### 2.2 Model Baru `ReceiptLog` (`backend/app/modules/receipts/models.py`)
```python
class ReceiptPrintType(str, enum.Enum):
    THERMAL = "thermal"
    PDF = "pdf"
    DIGITAL = "digital"

class ReceiptLog(Base, UUIDMixin, TimestampMixin):
    __tablename__ = "receipt_logs"

    tenant_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), sa.ForeignKey("tenants.id", ondelete="CASCADE"), index=True, nullable=False)
    outlet_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), sa.ForeignKey("outlets.id", ondelete="RESTRICT"), index=True, nullable=False)
    order_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), sa.ForeignKey("orders.id", ondelete="CASCADE"), index=True, nullable=False)
    printed_by_id: Mapped[Optional[uuid.UUID]] = mapped_column(UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="SET NULL"), nullable=True)

    print_type: Mapped[str] = mapped_column(sa.String(32), default=ReceiptPrintType.THERMAL.value, nullable=False)
    notes: Mapped[Optional[str]] = mapped_column(sa.String(255), nullable=True)

    __table_args__ = (
        sa.Index("ix_receipt_logs_tenant_order", "tenant_id", "order_id"),
        sa.Index("ix_receipt_logs_tenant_created", "tenant_id", "created_at"),
    )
```

---

## 3. Logika Bisnis & Spesifikasi API

### 3.1 Public Tracking
1. **`GET /api/v1/tracking/{token}`**:
   - Akses: Publik (tanpa autentikasi).
   - Validasi: Cari order berdasarkan `tracking_token`.
   - Data masking:
     - Nama: `Pak Budi Santoso` -> `Pak Budi S*****`
     - Telepon: `081234567890` -> `0812****7890`
   - Output:
     ```json
     {
       "success": true,
       "data": {
         "order_number": "LDR-20261102-0001",
         "status": "washing",
         "status_label": "Sedang Dicuci",
         "payment_status": "paid",
         "payment_status_label": "Lunas",
         "customer_name_masked": "Pak Budi S*****",
         "customer_phone_masked": "0812****7890",
         "received_at": "2026-11-02T10:00:00Z",
         "estimated_completion_at": "2026-11-04T10:00:00Z",
         "outlet_name": "Laundry Fresh - Outlet Pusat",
         "outlet_phone": "081299990000",
         "outlet_address": "Jl. Melati No. 12",
         "items": [
           {
             "service_name": "Cuci Komplit Reguler",
             "price_type": "per_kg",
             "unit": "kg",
             "quantity": 3.5,
             "unit_price": "7000.00",
             "subtotal": "24500.00"
           }
         ],
         "subtotal": "24500.00",
         "discount_amount": "0.00",
         "total_amount": "24500.00",
         "paid_amount": "24500.00",
         "remaining_amount": "0.00",
         "timeline": [
           {
             "status": "received",
             "status_label": "Diterima Kasir",
             "timestamp": "2026-11-02T10:00:00Z",
             "notes": "Pesanan diterima di kasir"
           }
         ]
       }
     }
     ```

2. **`GET /api/v1/orders/{id}/tracking-link`**:
   - Roles: `owner`, `admin`, `cashier`, `operator`
   - Returns: `tracking_token`, `tracking_url`, `whatsapp_share_text`

3. **`POST /api/v1/orders/{id}/tracking-link/regenerate`**:
   - Roles: `owner`, `admin`, `cashier`
   - Memperbarui `order.tracking_token = secrets.token_urlsafe(32)`

### 3.2 Receipt Management & Thermal/PDF
1. **`GET /api/v1/orders/{id}/receipt`**:
   - Mengembalikan data lengkap untuk rendering nota digital.
2. **`GET /api/v1/orders/{id}/receipt/pdf`**:
   - Mengembalikan file streaming PDF (`application/pdf`) dengan ukuran nota thermal / compact receipt beresolusi tajam, logo outlet / nama bisnis, barcode/QR code token tracking, dan syarat ketentuan laundry.
3. **`GET /api/v1/orders/{id}/receipt/thermal`**:
   - Mengembalikan HTML dengan styling CSS monospace `@page { size: 58mm auto; margin: 0; }` siap print.
4. **`POST /api/v1/orders/{id}/receipt/reprint`**:
   - Mencatat record ke `receipt_logs`, menaikkan `order.reprint_count += 1`.

---

## 4. UI/UX Kasir & Publik (Flutter Web)

1. **Layar Publik `/track/:token` (`TrackingScreen`)**:
   - Tidak memerlukan header dashboard/sidebar staf.
   - Kartu status dinamis dengan warna sesuai state (`received` biru, `washing` teal, `ready` hijau, dll).
   - Stepper horizontal/vertikal interaktif.
   - Rincian item cucian dan status tagihan.
   - Tombol "Hubungi Kasir Outlet" (link telp / WhatsApp).
2. **Dialog Opsi Nota & Berbagi Kasir (`ReceiptShareDialog`)**:
   - Ditampilkan melalui tombol "Cetak & Bagikan Nota" di `OrderDetailDialog` serta tombol shortcut di akhir `order_create_screen.dart`.
   - Preview visual nota compact.
   - Tab / Tombol Aksi:
     - "Cetak Thermal": Membuka URL thermal view di tab baru / memicu window print.
     - "Unduh PDF": Mengunduh berkas `.pdf` nota resmi.
     - "Salin Tautan": Menyalin link pelacakan publik ke clipboard.
     - "Kirim WhatsApp": Membuka WhatsApp Web dengan format teks konfirmasi siap kirim.
