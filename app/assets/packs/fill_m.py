#!/usr/bin/env python3
"""
Mengisi field `m` (Bahasa Indonesia) untuk semua file JSON.
Menggabungkan kamus eksplisit + analisis karakter + idiom.
"""
import json, sys, os
sys.stdout.reconfigure(encoding='utf-8')

PACKS_DIR = r'D:\CLAUDE\ZHONG-WEN-SHU-2\app\assets\packs'
sys.path.insert(0, PACKS_DIR)

# ===== TIER 1: KAMUS EKSPLISIT word → Indonesian =====
# Dimuat dari bootstrap_m.py
from bootstrap_m import M as TIER1_DICT

# ===== TIER 2: KARAKTER → SEMANTIK =====
# Untuk kata yang tidak ada di Tier 1, kita analisis karakter penyusunnya
CHAR_SEMANTICS = {
    # Anggota tubuh
    "头": "kepala", "目": "mata", "口": "mulut", "耳": "telinga",
    "鼻": "hidung", "舌": "lidah", "牙": "gigi", "手": "tangan",
    "足": "kaki", "脚": "kaki", "身": "tubuh", "心": "hati",
    "皮": "kulit", "骨": "tulang", "肉": "daging", "血": "darah",
    "发": "rambut", "毛": "bulu",

    # Alam
    "山": "gunung", "水": "air", "火": "api", "木": "pohon",
    "土": "tanah", "石": "batu", "金": "emas; logam",
    "日": "matahari", "月": "bulan", "星": "bintang",
    "云": "awan", "雨": "hujan", "雪": "salju", "风": "angin",
    "雷": "guntur", "电": "listrik",
    "海": "laut", "河": "sungai", "湖": "danau", "江": "sungai",
    "田": "sawah", "地": "tanah",

    # Warna
    "红": "merah", "黄": "kuning", "蓝": "biru", "绿": "hijau",
    "白": "putih", "黑": "hitam", "紫": "ungu", "灰": "abu-abu",
    "青": "hijau/biru", "彩": "warna",

    # Ukuran & kuantitas
    "大": "besar", "小": "kecil", "多": "banyak", "少": "sedikit",
    "长": "panjang", "短": "pendek", "高": "tinggi", "低": "rendah",
    "宽": "lebar", "窄": "sempit", "厚": "tebal", "薄": "tipis",
    "深": "dalam", "浅": "dangkal", "重": "berat", "轻": "ringan",
    "粗": "kasar", "细": "halus", "快": "cepat", "慢": "lambat",
    "远": "jauh", "近": "dekat",

    # Temporal
    "今": "sekarang", "明": "terang; besok", "昨": "kemarin",
    "前": "sebelum", "后": "sesudah", "早": "pagi", "晚": "malam",
    "朝": "pagi", "夕": "sore", "春": "musim semi",
    "夏": "musim panas", "秋": "musim gugur", "冬": "musim dingin",
    "年": "tahun", "月": "bulan", "日": "hari", "时": "waktu",
    "分": "menit", "秒": "detik", "刻": "saat",

    # Arah
    "上": "atas", "下": "bawah", "左": "kiri", "右": "kanan",
    "东": "timur", "西": "barat", "南": "selatan", "北": "utara",
    "中": "tengah", "内": "dalam", "外": "luar", "前": "depan",
    "后": "belakang", "旁": "samping", "边": "tepi; sisi",

    # Orang & hubungan
    "人": "orang", "男": "laki-laki", "女": "perempuan",
    "老": "tua", "幼": "muda", "孩": "anak", "童": "anak",
    "父": "ayah", "母": "ibu", "子": "anak", "女": "perempuan",
    "兄": "kakak laki-laki", "弟": "adik laki-laki",
    "姐": "kakak perempuan", "妹": "adik perempuan",
    "夫": "suami", "妻": "istri", "亲": "orang tua; kerabat",
    "友": "teman", "师": "guru", "生": "murid",

    # Bangunan & tempat
    "家": "rumah", "室": "ruangan", "房": "kamar", "屋": "rumah",
    "门": "pintu", "窗": "jendela", "墙": "dinding",
    "楼": "gedung", "店": "toko", "厂": "pabrik",
    "校": "sekolah", "院": "halaman; institusi",
    "市": "kota; pasar", "城": "kota; benteng",
    "路": "jalan", "街": "jalan", "道": "jalan; jalur",

    # Tindakan umum
    "走": "berjalan", "跑": "berlari", "跳": "melompat",
    "站": "berdiri", "坐": "duduk", "躺": "berbaring",
    "看": "melihat", "听": "mendengar", "说": "berbicara",
    "读": "membaca", "写": "menulis", "画": "menggambar",
    "吃": "makan", "喝": "minum", "咬": "menggigit",
    "拿": "mengambil", "放": "meletakkan", "拉": "menarik",
    "推": "mendorong", "打": "memukul", "敲": "mengetuk",
    "开": "membuka", "关": "menutup", "锁": "mengunci",
    "穿": "memakai", "脱": "melepas", "洗": "mencuci",
    "买": "membeli", "卖": "menjual", "付": "membayar",

    # Pikiran & perasaan
    "想": "berpikir", "思": "berpikir", "念": "merindukan",
    "记": "mengingat", "忘": "lupa", "知": "tahu",
    "爱": "cinta", "恨": "benci", "喜": "suka", "怒": "marah",
    "哀": "sedih", "乐": "gembira", "怕": "takut",
    "惊": "terkejut", "急": "tergesa-gesa",

    # Kata kerja umum
    "做": "membuat", "用": "menggunakan", "有": "memiliki",
    "无": "tidak ada", "是": "adalah", "在": "berada",
    "去": "pergi", "来": "datang", "回": "kembali",
    "出": "keluar", "入": "masuk", "到": "sampai",
    "过": "melewati", "起": "bangkit", "落": "jatuh",
    "飞": "terbang", "游": "berenang",

    # Alam & benda
    "花": "bunga", "草": "rumput", "树": "pohon",
    "叶": "daun", "果": "buah", "种": "biji",
    "米": "beras", "面": "tepung", "油": "minyak",
    "盐": "garam", "糖": "gula", "药": "obat",
    "布": "kain", "纸": "kertas",

    # Abstrak
    "文": "tulisan; budaya", "化": "perubahan; budaya",
    "学": "studi; ilmu", "术": "seni; teknik",
    "法": "hukum; cara", "理": "prinsip; nalar",
    "数": "angka", "量": "jumlah; ukuran",
    "力": "kekuatan", "气": "energi; udara",
    "色": "warna", "光": "cahaya", "声": "suara",
    "味": "rasa", "香": "wangi", "臭": "busuk",

    # Awalan/akhiran umum
    "可": "dapat; layak", "好": "baik",
    "不": "tidak", "未": "belum", "非": "bukan",
    "者": "orang yang", "家": "ahli",
    "化": "-isasi", "性": "-itas; sifat",
    "师": "guru; ahli", "员": "anggota; petugas",
    "手": "tangan; ahli",
}


def compound_translate(word):
    """Terjemahan untuk kata turunan berdasarkan karakter penyusunnya."""
    if len(word) <= 1:
        return None
    if len(word) == 2:
        c1, c2 = word[0], word[1]
        s1 = CHAR_SEMANTICS.get(c1, "")
        s2 = CHAR_SEMANTICS.get(c2, "")
        if not s1 or not s2:
            return None

        # Pola umum: KB + KB
        common_pairs = {
            ("rumah", "panjang"): "kepala keluarga",
            ("tua", "orang"): "orang tua",
            ("anak", "laki-laki"): "anak laki-laki",
            ("anak", "perempuan"): "anak perempuan",
            ("kakak laki-laki", "adik laki-laki"): "saudara laki-laki",
            ("kakak perempuan", "adik perempuan"): "saudara perempuan",
            ("ayah", "ibu"): "orang tua",
            ("suami", "istri"): "pasangan suami istri",
            ("teman", "teman"): "teman",
            ("melihat", "tidak"): "tidak kelihatan",
            ("hati", "dalam"): "dalam hati",
            ("bangsa", "rumah"): "bangsa; negara",
            ("air", "buah"): "buah (air)",
            ("makan", "barang"): "makanan",
            ("minum", "barang"): "minuman",
            ("jalan", "pergi"): "berangkat; pergi",
            ("kembali", "rumah"): "pulang",
            ("tangan", "mesin"): "telepon genggam",
            ("listrik", "otak"): "komputer",
            ("listrik", "melihat"): "televisi",
            ("listrik", "kata"): "telepon",
            ("terbang", "mesin"): "pesawat terbang",
            ("api", "kendaraan"): "kereta api",
            ("sekolah", "murid"): "siswa",
            ("guru", "panjang"): "guru senior",
            ("guru", "tua"): "guru senior",
        }
    return None


# ===== TIER 3: IDIOM / CHENGYU =====
CHENGYU = {
    "二话不说": "tanpa banyak bicara",
    "一路平安": "selamat jalan",
    "一路顺风": "selamat jalan",
    "一帆风顺": "semoga berjalan lancar",
    "一路平安": "selamat jalan",
    "各种各样": "bermacam-macam",
    "越来越多": "semakin banyak",
    "越来越少": "semakin sedikit",
    "不知不觉": "tanpa disadari",
    "好像": "sepertinya",
}


def strip_annotation(s):
    """Hapus anotasi kurung dari s, misal '名字(˙ㄗ)' -> '名字'"""
    for ch in '(\uff08':
        idx = s.find(ch)
        if idx >= 0:
            return s[:idx]
    return s


def get_translation(word):
    """Cari terjemahan untuk sebuah kata."""
    # Coba kamus eksplisit
    if word in TIER1_DICT:
        return TIER1_DICT[word]

    # Coba idiom/chengyu
    if word in CHENGYU:
        return CHENGYU[word]

    # Coba analisis komponen
    compound_result = compound_translate(word)
    if compound_result:
        return compound_result

    return None


# ===== PROSES SEMUA FILE =====
def main():
    files = sorted(f for f in os.listdir(PACKS_DIR)
                   if f.endswith('.json') and f not in ('manifest.json', 'SCHEMA.md')
                   and not f.startswith('SCHEMA'))

    total_filled = 0
    total_empty = 0
    total_notfound = 0
    notfound_words = []

    for fname in files:
        path = os.path.join(PACKS_DIR, fname)
        with open(path, 'r', encoding='utf-8') as f:
            data = json.load(f)
        cards = data.get('cards', [])
        if not cards:
            continue

        changed = 0
        for c in cards:
            current = c.get('m', '').strip()
            simplified = strip_annotation(c['s'])

            # Bersihkan s field dari anotasi
            if simplified != c['s']:
                c['s'] = simplified

            if current and current != simplified:
                continue  # Already has a reasonable translation

            translation = get_translation(simplified)
            if translation:
                c['m'] = translation
                changed += 1
            else:
                total_notfound += 1
                if simplified not in notfound_words:
                    notfound_words.append(simplified)

        if changed > 0:
            with open(path, 'w', encoding='utf-8') as f:
                json.dump(data, f, ensure_ascii=False, separators=(",", ":"))
            # Count how many are still empty
            still_empty = sum(1 for c in cards if not c.get('m', '').strip())
            total_after = len(cards) - still_empty
            print(f"{fname}: +{changed} terisi, {still_empty} masih kosong")

    print(f"\n=== HASIL ===")
    print(f"Kata tidak ditemukan di kamus: {len(notfound_words)}")
    if notfound_words:
        print(f"Contoh 20 kata pertama:")
        for w in notfound_words[:20]:
            print(f"  {w}")


if __name__ == "__main__":
    main()
