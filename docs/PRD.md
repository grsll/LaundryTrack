# Product Requirements Document (PRD)

# LaundryTrack — Smart Laundry Management System

**Versi:** 1.0  
**Tanggal:** 1 November 2026  
**Status:** Draft untuk pengembangan MVP  
**Bahasa produk:** Bahasa Indonesia  
**Mata uang:** Rupiah (IDR)  
**Zona waktu default:** Asia/Jakarta  

---

## 1. Ringkasan Produk

LaundryTrack adalah aplikasi SaaS (Software as a Service) untuk membantu pemilik usaha laundry mengelola operasional bisnis dalam satu sistem. Aplikasi berfokus pada pencatatan pelanggan, layanan, transaksi laundry, pembayaran, status pengerjaan, pelacakan pesanan melalui QR/link, nota digital, dan laporan usaha.

LaundryTrack dirancang untuk usaha laundry kecil hingga menengah. Pengguna dapat mendaftarkan bisnisnya sendiri, mengelola satu outlet pada tahap awal, dan menggunakan sistem yang secara arsitektur sudah siap mendukung banyak outlet di masa depan.

Pelanggan dapat melacak pesanan tanpa harus membuat akun melalui QR code atau tautan unik. LaundryTrack juga menyediakan portal pelanggan bagi pelanggan yang ingin memiliki akun dan melihat riwayat transaksi.

### 1.1 Masalah yang Ingin Diselesaikan
Banyak usaha laundry masih mengandalkan pencatatan manual atau aplikasi sederhana yang belum terintegrasi. Hal ini dapat menyebabkan:
- Data pelanggan dan transaksi tersebar.
- Kesulitan mengetahui status setiap pesanan.
- Kesalahan perhitungan berat, harga, diskon, dan pembayaran.
- Pemilik kesulitan memantau omzet dan performa usaha.
- Pelanggan harus menghubungi outlet untuk menanyakan status laundry.
- Nota mudah hilang dan riwayat transaksi sulit ditelusuri.

### 1.2 Solusi
LaundryTrack menyediakan satu sistem terpusat yang memungkinkan pemilik dan staf:
- Mengelola data pelanggan dan layanan laundry.
- Membuat serta memantau pesanan.
- Mencatat pembayaran penuh maupun sebagian.
- Mengubah status pengerjaan dengan riwayat aktivitas.
- Membagikan QR code atau tautan pelacakan pesanan.
- Mencetak nota thermal dan mengirim nota digital.
- Melihat dashboard serta laporan operasional.

---

## 2. Visi dan Tujuan Produk

### 2.1 Visi
Menjadi sistem manajemen laundry yang mudah digunakan, terjangkau, dan dapat berkembang bersama bisnis laundry dari satu outlet menjadi beberapa outlet.

### 2.2 Tujuan MVP
1. Pemilik laundry dapat mendaftarkan bisnis dan mulai menggunakan aplikasi.
2. Pemilik atau staf dapat mengelola pelanggan dan layanan.
3. Pengguna dapat membuat pesanan laundry secara akurat.
4. Pengguna dapat mencatat pembayaran dan memantau sisa tagihan.
5. Pelanggan dapat memantau status pesanan melalui tautan publik yang aman.
6. Outlet dapat memberikan nota digital dan mencetak nota thermal.
7. Pemilik dapat melihat ringkasan transaksi dan laporan dasar.
8. Data setiap bisnis terisolasi dan tidak dapat diakses oleh bisnis lain.

### 2.3 Indikator Keberhasilan
Target awal untuk validasi produk:
- 5–10 pemilik laundry diwawancarai sebelum atau selama pengembangan MVP.
- Minimal 3 bisnis bersedia mencoba versi uji coba.
- Pengguna uji coba dapat membuat pesanan tanpa bantuan teknis.
- Tidak ditemukan kebocoran data lintas tenant pada pengujian keamanan.
- Pemilik dapat melihat omzet, jumlah pesanan, dan pesanan aktif dari dashboard.
- Pelanggan dapat membuka tautan tracking tanpa harus login.

---

## 3. Target Pengguna dan Hak Akses

### 3.1 Segmen Pengguna
- **Pemilik laundry:** mengelola bisnis, outlet, staf, layanan, transaksi, laporan, dan pengaturan.
- **Admin:** membantu mengelola operasional sesuai izin yang diberikan.
- **Kasir:** membuat pesanan, mengelola pelanggan, dan mencatat pembayaran.
- **Operator:** memperbarui status pengerjaan pesanan.
- **Pelanggan:** melihat status pesanan dan riwayat miliknya melalui akun pelanggan.

### 3.2 Peran dan Hak Akses
| Peran | Hak akses utama |
|---|---|
| Owner | Akses penuh terhadap tenant dan pengaturan bisnis |
| Admin | Pengelolaan operasional sesuai permission |
| Cashier | Pelanggan, pesanan, pembayaran, dan nota |
| Operator | Melihat antrean dan memperbarui status pengerjaan |
| Customer | Melihat pesanan miliknya sendiri |

Hak akses harus divalidasi di backend. Menyembunyikan menu di frontend bukan mekanisme keamanan.

---

## 4. Ruang Lingkup Produk

### 4.1 Termasuk dalam MVP
1. Registrasi dan login bisnis.
2. Arsitektur SaaS multi-tenant.
3. Satu outlet aktif per bisnis pada pengalaman awal.
4. Pengelolaan staf dan role dasar.
5. CRUD pelanggan.
6. CRUD layanan laundry.
7. Pembuatan dan pengelolaan pesanan.
8. Status pengerjaan pesanan.
9. Pembayaran penuh dan sebagian.
10. Riwayat pembayaran.
11. QR code atau tautan tracking publik.
12. Nota digital.
13. PDF nota.
14. Cetak thermal melalui browser print CSS untuk kertas 58 mm dan 80 mm.
15. Dashboard dan laporan dasar.
16. Portal pelanggan dasar.
17. Audit log untuk aktivitas penting.

### 4.2 Tidak Termasuk dalam MVP
- Aplikasi mobile native terpisah untuk pelanggan.
- Integrasi payment gateway otomatis.
- Integrasi WhatsApp Business API otomatis.
- Sinkronisasi akuntansi penuh.
- Manajemen inventaris bahan kimia dan perlengkapan laundry.
- Payroll dan absensi karyawan.
- Program loyalty dan poin pelanggan.
- Multi-outlet sebagai fitur aktif berbayar.
- Bluetooth ESC/POS dan dukungan langsung berbagai printer.
- Microservices.
- AI untuk prediksi operasional.

---

## 5. Model Bisnis dan SaaS

LaundryTrack menggunakan model berlangganan per bisnis (tenant).

### 5.1 Struktur Tenant dan Outlet
- **Tenant** mewakili satu bisnis laundry.
- **Outlet** mewakili cabang atau lokasi operasional milik tenant.
- Registrasi bisnis membuat satu tenant dan satu outlet default secara otomatis.
- Semua transaksi harus memiliki `tenant_id` dan `outlet_id` sejak awal.
- Tenant hanya dapat mengakses data miliknya sendiri.
- Sistem disiapkan agar tenant dapat memiliki beberapa outlet di masa depan.

### 5.2 Rencana Paket Awal
| Paket | Harga indikatif | Target |
|---|---|---|
| Free | Rp0 | Uji coba dan laundry mikro |
| Starter | Rp39.000/bulan | Laundry kecil |
| Business | Rp79.000/bulan | Laundry yang membutuhkan fitur lebih lengkap |

### 5.3 Pengelolaan Langganan
- Setiap tenant memiliki status langganan.
- Paket menentukan batas fitur dan kuota.
- Backend menjadi sumber kebenaran untuk memeriksa batas paket.
- Status langganan tidak boleh hanya diperiksa di frontend.
- Integrasi payment gateway ditunda sampai kebutuhan dan model harga tervalidasi.

---

## 6. Alur Pengguna Utama

### 6.1 Registrasi Pemilik Laundry
1. Pemilik membuka halaman registrasi.
2. Pemilik mengisi nama, email, nomor telepon, dan kata sandi.
3. Pemilik mengisi nama bisnis dan informasi outlet pertama.
4. Backend membuat user, tenant, outlet default, keanggotaan owner, dan langganan Free secara atomik.
5. Pemilik diarahkan ke dashboard.

### 6.2 Membuat Pesanan
1. Kasir memilih pelanggan atau membuat pelanggan baru.
2. Kasir memilih layanan laundry.
3. Kasir memasukkan berat atau jumlah item sesuai jenis layanan.
4. Sistem mengambil harga layanan yang berlaku.
5. Backend menghitung subtotal, diskon, total, dan sisa pembayaran.
6. Pesanan disimpan dengan status awal `received`.
7. Sistem membuat nomor pesanan dan token tracking.
8. Kasir dapat membuka atau mencetak nota dan membagikan tautan tracking.

### 6.3 Proses Pengerjaan
Alur status normal:
`received → washing → drying → ironing → packaging → ready → completed`

Status `cancelled` merupakan jalur khusus yang hanya dapat dilakukan jika memenuhi aturan pembatalan.

### 6.4 Pembayaran
1. Kasir membuka detail pesanan.
2. Kasir memasukkan nominal pembayaran.
3. Backend memvalidasi nominal dan sisa tagihan.
4. Pembayaran dicatat sebagai transaksi baru.
5. Sistem memperbarui status pembayaran (`unpaid`, `partial`, `paid`, `refunded`).
6. Nota atau bukti pembayaran dapat dicetak atau dibagikan.

### 6.5 Pelacakan oleh Pelanggan
1. Pelanggan menerima QR code atau tautan tracking.
2. Pelanggan membuka tautan tanpa login.
3. Backend memvalidasi token.
4. Sistem menampilkan nomor pesanan, status, estimasi selesai, dan informasi aman lainnya.
5. Data pribadi sensitif pelanggan tidak ditampilkan secara publik.

### 6.6 Portal Pelanggan
Pelanggan dapat membuat akun untuk melihat riwayat pesanan miliknya melalui verifikasi kepemilikan.

---

## 7. Persyaratan Fungsional
Lihat detail pada PRD asli untuk modul Auth, Tenant/Outlet, Pelanggan, Layanan, Pesanan, Pembayaran/Refund, Tracking, Nota, Dashboard/Laporan, Staf/Role, dan Langganan.

---

## 8. Persyaratan Non-Fungsional
- **Keamanan:** Tenant isolation via session/token JWT, Argon2id/bcrypt untuk password, IDOR prevention, rate limit public tracking, audit log.
- **Privasi:** Minimized public tracking info, data pelanggan terisolasi per tenant.
- **Performa:** Pagination, indexed queries, efficient aggregations, no N+1 queries.
- **Keandalan:** DB transactions, `NUMERIC` for monetary values, timezone-aware UTC timestamps (Asia/Jakarta display).

---

## 9. Rancangan Teknologi
- **Frontend:** Flutter Web / PWA (Dart, Riverpod, Dio, GoRouter)
- **Backend:** Python FastAPI, SQLAlchemy 2.0, PostgreSQL 16, Alembic, Pydantic v2
- **PDF/Nota:** ReportLab & Browser Print CSS (58mm, 80mm)
- **Deployment:** Docker Compose + Nginx reverse proxy

---

## 10. Tahapan Pengembangan (Phases)
- **Phase 0:** Fondasi Proyek (Repository, FastAPI, Flutter Web, Database VPS, Alembic, Docs)
- **Phase 1:** Auth dan Multi-Tenancy
- **Phase 2:** Pelanggan dan Layanan
- **Phase 3:** Manajemen Pesanan
- **Phase 4:** Pembayaran dan Status
- **Phase 5:** Tracking dan Nota
- **Phase 6:** Portal Pelanggan
- **Phase 7:** Dashboard, Laporan, dan SaaS
- **Phase 8:** Audit dan Deployment
