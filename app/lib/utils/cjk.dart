/// Rentang karakter CJK (Hanzi) yang dipakai untuk segmentasi/deteksi teks
/// Mandarin. Satu sumber agar tak ada duplikasi antar service.
final RegExp kCjkChar = RegExp(r'[一-鿿㐀-䶿]');
