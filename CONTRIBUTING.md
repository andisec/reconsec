# Contributing to RECON

Terima kasih sudah mau kontribusi! 🙏

## Cara Kontribusi

1. Fork repository ini
2. Buat branch baru: `git checkout -b fitur-baru`
3. Commit perubahan: `git commit -m 'Tambah fitur X'`
4. Push: `git push origin fitur-baru`
5. Buka Pull Request

## Aturan Penting

- Tool ini HANYA untuk pengujian berizin — jangan tambahkan fitur
  yang jelas-jelas untuk kegiatan ilegal (brute force login, DDoS, dll)
- Pertahankan prinsip "zero-crash": setiap fitur baru WAJIB punya
  fallback dependency-free (curl/dig/grep)
- Test dulu di target lab milik sendiri sebelum submit
- Gunakan `bash` (bukan `sh`) untuk kompatibilitas
- Jaga output rapi: gunakan fungsi info/warn/error/step yang sudah ada

## Saran Fitur

Lihat section Roadmap di README.md. Issue dengan label
`enhancement` dipersilakan dibahas dulu sebelum coding.
