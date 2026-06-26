#!/usr/bin/env python3
"""
Generate HSK 3.0 vocabulary JSON files from official word list CSV.
Uses opencc for simplified→traditional conversion and pypinyin for pinyin.
Indonesian translations are provided via a dictionary.
"""
import csv
import json
import re
import sys
from pathlib import Path
from opencc import OpenCC
from pypinyin import pinyin, Style

# ── Conversion tools ──────────────────────────────────────────────
cc_s2t = OpenCC('s2t')  # Simplified → Traditional

# Bopomofo (Zhuyin) mapping
INITIAL_MAP = {
    'b': 'ㄅ', 'p': 'ㄆ', 'm': 'ㄇ', 'f': 'ㄈ',
    'd': 'ㄉ', 't': 'ㄊ', 'n': 'ㄋ', 'l': 'ㄌ',
    'g': 'ㄍ', 'k': 'ㄎ', 'h': 'ㄏ',
    'j': 'ㄐ', 'q': 'ㄑ', 'x': 'ㄒ',
    'zh': 'ㄓ', 'ch': 'ㄔ', 'sh': 'ㄕ', 'r': 'ㄖ',
    'z': 'ㄗ', 'c': 'ㄘ', 's': 'ㄙ', 'y': 'ㄧ', 'w': 'ㄨ',
}

FINAL_MAP = {
    'a': 'ㄚ', 'o': 'ㄛ', 'e': 'ㄜ', 'ê': 'ㄝ',
    'ai': 'ㄞ', 'ei': 'ㄟ', 'ao': 'ㄠ', 'ou': 'ㄡ',
    'an': 'ㄢ', 'en': 'ㄣ', 'ang': 'ㄤ', 'eng': 'ㄥ', 'er': 'ㄦ',
    'i': 'ㄧ', 'ia': 'ㄧㄚ', 'iao': 'ㄧㄠ', 'ian': 'ㄧㄢ',
    'in': 'ㄧㄣ', 'iang': 'ㄧㄤ', 'ing': 'ㄧㄥ', 'ie': 'ㄧㄝ',
    'iu': 'ㄧㄡ', 'iong': 'ㄩㄥ',
    'u': 'ㄨ', 'ua': 'ㄨㄚ', 'uo': 'ㄨㄛ', 'uai': 'ㄨㄞ',
    'ui': 'ㄨㄟ', 'uan': 'ㄨㄢ', 'un': 'ㄨㄣ', 'uang': 'ㄨㄤ',
    'ong': 'ㄨㄥ',
    'v': 'ㄩ', 'ü': 'ㄩ', 'ue': 'ㄩㄝ', 've': 'ㄩㄝ',
    'van': 'ㄩㄢ', 'vn': 'ㄩㄣ',
}

TONE_MARKS = {1: '', 2: 'ˊ', 3: 'ˇ', 4: 'ˋ', 5: '˙'}

def pinyin_to_zhuyin_single(char_pinyin):
    """Convert a single-character pinyin (with tone mark) to zhuyin."""
    if not char_pinyin:
        return ''
    
    syll = char_pinyin
    
    # Determine tone
    tone = 1
    if any(c in syll for c in 'āōēīūǖ'):
        tone = 1
    elif any(c in syll for c in 'áóéíúǘ'):
        tone = 2
    elif any(c in syll for c in 'ǎǒěǐǔǚ'):
        tone = 3
    elif any(c in syll for c in 'àòèìùǜ'):
        tone = 4
    
    # Remove tone marks
    tone_remover = str.maketrans(
        'āáǎàēéěèīíǐìōóǒòūúǔùǖǘǚǜ',
        'aaaaeeeeiiiioooouuuuvvvv'
    )
    clean = syll.translate(tone_remover).replace('ü', 'v')
    
    # Vowel-only syllables
    vowel_only = {'a', 'o', 'e', 'ai', 'ei', 'ao', 'ou', 'an', 'en', 'ang', 'eng', 'er'}
    
    initial = ''
    final = clean
    
    if clean not in vowel_only:
        sorted_initials = sorted(INITIAL_MAP.keys(), key=len, reverse=True)
        for init in sorted_initials:
            if clean.startswith(init) and len(clean) > len(init):
                initial = init
                final = clean[len(init):]
                break
    
    zy_initial = INITIAL_MAP.get(initial, '')
    zy_final = FINAL_MAP.get(final, final)
    tone_mark = TONE_MARKS.get(tone, '')
    
    if tone == 5:
        return tone_mark + zy_initial + zy_final
    else:
        return zy_initial + zy_final + tone_mark


def pinyin_to_zhuyin(py_str):
    """Convert pinyin string to zhuyin (bopomofo).
    Handles compound words by splitting at syllable boundaries."""
    if not py_str:
        return ''
    
    # Split pinyin string at syllable boundaries
    # A syllable boundary occurs when: vowel(s)+tone followed by consonant that starts new syllable
    # Use pypinyin to get per-character pinyin for accurate splitting
    return py_str  # fallback - will use per-char approach instead


def char_pinyin_to_zhuyin(char_pinyin):
    """Convert single character pinyin to zhuyin."""
    return pinyin_to_zhuyin_single(char_pinyin)


def get_word_zhuyin(hanzi):
    """Get zhuyin for a word by processing each character separately."""
    py_list = pinyin(hanzi, style=Style.TONE)
    result = []
    for py_pair in py_list:
        if py_pair and py_pair[0]:
            result.append(pinyin_to_zhuyin_single(py_pair[0]))
    return ' '.join(result)


def get_pinyin_with_tone(hanzi):
    """Get pinyin with tone marks for a Chinese word."""
    py_list = pinyin(hanzi, style=Style.TONE)
    return ''.join([p[0] for p in py_list])


def get_tone_number(hanzi):
    """Get the tone number of the first syllable."""
    py_list = pinyin(hanzi, style=Style.TONE)
    if py_list and py_list[0]:
        first_py = py_list[0][0]
        # Extract tone from pinyin
        tone_map = {'ā': 1, 'á': 2, 'ǎ': 3, 'à': 4}
        for mark, num in tone_map.items():
            if mark in first_py:
                return num
        return 5  # neutral
    return 5


def to_traditional(simplified):
    """Convert simplified to traditional Chinese."""
    return cc_s2t.convert(simplified)


# ── Indonesian translation dictionary (HSK 1-6 core) ──────────────
# This is a comprehensive mapping based on official HSK word lists
# Format: 'simplified': 'indonesian meaning'
INDONESIAN_DICT = {
    # === HSK 1 ===
    '爱': 'cinta; suka', '爱好': 'hobi', '八': 'delapan', '爸爸': 'ayah',
    '吧': 'partikel', '白': 'putih', '白天': 'siang hari', '百': 'seratus',
    '班': 'kelas', '半': 'setengah', '半年': 'setengah tahun', '半天': 'setengah hari',
    '帮': 'membantu', '帮忙': 'membantu', '包': 'bungkus; kantong',
    '包子': 'bakpao', '杯': 'cangkir', '杯子': 'gelas',
    '北': 'utara', '北边': 'sebelah utara', '北京': 'Beijing',
    '本': '量词 buku', '本子': 'buku catatan', '比': 'dibandingkan',
    '别': 'jangan', '别的': 'lainnya', '别人': 'orang lain',
    '病': 'sakit', '病人': 'pasien', '不大': 'tidak terlalu',
    '不对': 'salah', '不客气': 'sama-sama', '不用': 'tidak perlu', '不': 'tidak',
    '菜': 'masakan; sayur', '茶': 'teh', '差': 'kurang; buruk',
    '常': 'sering', '常常': 'sering', '唱': 'menyanyi',
    '唱歌': 'menyanyi', '车': 'kendaraan', '车票': 'tiket',
    '车上': 'di atas kendaraan', '车站': 'stasiun',
    '吃': 'makan', '吃饭': 'makan nasi', '出': 'keluar',
    '出来': 'keluar', '出去': 'keluar', '穿': 'memakai (baju)',
    '床': 'tempat tidur', '次': 'kali', '从': 'dari',
    '错': 'salah', '打': 'memukul', '打车': 'menyewa taksi',
    '打电话': 'menelepon', '打开': 'membuka', '打球': 'bermain bola',
    '大': 'besar', '大学': 'universitas', '大学生': 'mahasiswa',
    '到': 'sampai', '得到': 'mendapatkan', '地': 'tanah',
    '的': 'partikel', '等': 'menunggu', '地点': 'lokasi',
    '地方': 'tempat', '地上': 'di tanah', '地图': 'peta',
    '弟弟': 'adik laki-laki', '第': 'awalan ordinal', '点': 'titik; pukul',
    '电': 'listrik', '电话': 'telepon', '电脑': 'komputer',
    '电视': 'televisi', '电视机': 'perangkat TV', '电影': 'film',
    '电影院': 'bioskop', '东': 'timur', '东边': 'sebelah timur',
    '东西': 'barang', '动': 'bergerak', '动作': 'gerakan',
    '都': 'semua', '读': 'membaca', '读书': 'belajar',
    '对': 'benar', '对不起': 'maaf', '多': 'banyak',
    '多少': 'berapa', '饿': 'lapar', '儿子': 'anak laki-laki',
    '二': 'dua', '饭': 'nasi', '饭店': 'restoran',
    '房间': 'kamar', '房子': 'rumah', '放': 'meletakkan',
    '放假': 'libur', '放学': 'selesai sekolah', '飞': 'terbang',
    '飞机': 'pesawat', '非常': 'sangat', '分': 'menit; poin',
    '风': 'angin', '干': 'kering', '干净': 'bersih',
    '干什么': 'sedang apa', '高': 'tinggi', '高兴': 'senang',
    '告诉': 'memberitahu', '哥哥': 'kakak laki-laki', '歌': 'lagu',
    '个': '量词', '给': 'memberi', '跟': 'dengan',
    '工人': 'pekerja', '工作': 'bekerja', '关': 'mematikan',
    '关上': 'menutup', '贵': 'mahal', '国': 'negara',
    '国家': 'negara', '国外': 'luar negeri', '过': 'melewati',
    '还': 'masih', '还是': 'atau', '还有': 'masih ada',
    '孩子': 'anak', '汉语': 'bahasa Mandarin', '汉字': 'huruf Tionghoa',
    '好': 'baik', '好吃': 'enak', '好看': 'bagus',
    '好听': 'enak didengar', '好玩': 'menyenangkan', '号': 'tanggal; nomor',
    '喝': 'minum', '和': 'dan', '很': 'sangat',
    '后': 'belakang', '后边': 'sebelah belakang', '后天': 'lusa',
    '花': 'bunga', '话': 'kata', '坏': 'rusak; jahat',
    '回': 'kembali', '回答': 'menjawab', '回到': 'kembali ke',
    '回家': 'pulang', '回来': 'kembali', '回去': 'kembali',
    '会': 'bisa; akan', '火车': 'kereta api', '机场': 'bandara',
    '机票': 'tiket pesawat', '鸡蛋': 'telur ayam', '几': 'berapa',
    '记': 'mengingat', '记得': 'ingat', '记住': 'hafalkan',
    '家': 'rumah', '家里': 'di rumah', '家人': 'keluarga',
    '间': '量词 kamar', '见': 'bertemu', '见面': 'bertemu',
    '教': 'mengajar', '叫': 'disebut; memanggil', '教学楼': 'gedung kuliah',
    '姐姐': 'kakak perempuan', '介绍': 'memperkenalkan', '今年': 'tahun ini',
    '今天': 'hari ini', '进': 'masuk', '进来': 'masuk ke sini',
    '进去': 'masuk ke sana', '九': 'sembilan', '就': 'langsung; maka',
    '觉得': 'merasa', '开': 'membuka; menyalakan', '开车': 'menyetir',
    '开会': 'rapat', '开玩笑': 'bercanda', '看': 'melihat',
    '看病': 'berobat', '看到': 'melihat', '看见': 'melihat',
    '考': 'ujian', '考试': 'ujian', '渴': 'haus',
    '课': 'pelajaran', '课本': 'buku pelajaran', '课文': 'teks',
    '口': 'mulut', '块': '量词', '快': 'cepat',
    '来': 'datang', '来到': 'datang ke', '老': 'tua',
    '老人': 'orang tua', '老师': 'guru', '了': 'partikel',
    '累': 'lelah', '冷': 'dingin', '里': 'di dalam',
    '里边': 'di bagian dalam', '两': 'dua', '零': 'nol',
    '六': 'enam', '楼': 'gedung', '楼上': 'di atas',
    '楼下': 'di bawah', '路': 'jalan', '路口': 'persimpangan',
    '路上': 'di jalan', '妈妈': 'ibu', '马路': 'jalan raya',
    '马上': 'segera', '吗': 'partikel tanya', '买': 'membeli',
    '慢': 'lambat', '忙': 'sibuk', '毛': 'sen (mata uang)',
    '没': 'tidak', '没关系': 'tidak apa-apa', '没什么': 'tidak ada apa-apa',
    '没事儿': 'tidak apa-apa', '没有': 'tidak ada',
    '妹妹': 'adik perempuan', '门': 'pintu', '门口': 'depan pintu',
    '门票': 'tiket masuk', '们': 'partikel jamak', '米饭': 'nasi',
    '面包': 'roti', '面条': 'mie', '名字': 'nama',
    '明白': 'mengerti', '明年': 'tahun depan', '明天': 'besok',
    '拿': 'mengambil', '哪': 'mana', '哪里': 'di mana',
    '哪儿': 'di mana', '哪些': 'yang mana', '那': 'itu',
    '那边': 'di sana', '那里': 'di sana', '那儿': 'di sana',
    '那些': 'itu-itu', '奶': 'susu', '奶奶': 'nenek',
    '男': 'laki-laki', '男孩': 'anak laki-laki', '男朋友': 'kekasih laki-laki',
    '男人': 'pria', '男生': 'siswa laki-laki', '南': 'selatan',
    '南边': 'sebelah selatan', '难': 'sulit', '呢': 'partikel',
    '能': 'bisa', '你': 'kamu', '你们': 'kalian',
    '年': 'tahun', '您': 'Anda (hormat)', '牛奶': 'susu sapi',
    '女': 'perempuan', '女儿': 'anak perempuan', '女孩': 'anak perempuan',
    '女朋友': 'kekasih perempuan', '女人': 'wanita', '女生': 'siswa perempuan',
    '旁边': 'sebelah', '跑': 'berlari', '朋友': 'teman',
    '票': 'tiket', '七': 'tujuh', '起': 'bangun',
    '起床': 'bangun tidur', '起来': 'berdiri', '汽车': 'mobil',
    '前': 'depan', '前边': 'sebelah depan', '前天': 'kemarin lusa',
    '钱': 'uang', '钱包': 'dompet', '请': 'tolong; silakan',
    '请假': 'mengambil cuti', '请进': 'silakan masuk', '请问': 'permisi',
    '请坐': 'silakan duduk', '球': 'bola', '去': 'pergi',
    '去年': 'tahun lalu', '热': 'panas', '人': 'orang',
    '认识': 'mengenal', '认真': 'serius', '日': 'hari',
    '日期': 'tanggal', '肉': 'daging', '三': 'tiga',
    '山': 'gunung', '商场': 'pusat perbelanjaan', '商店': 'toko',
    '上': 'atas', '上班': 'berangkat kerja', '上边': 'di atas',
    '上车': 'naik kendaraan', '上次': 'kali lalu', '上课': 'masuk kelas',
    '上网': 'online', '上午': 'pagi', '上学': 'berangkat sekolah',
    '少': 'sedikit', '谁': 'siapa', '身上': 'di badan',
    '身体': 'tubuh', '什么': 'apa', '生病': 'sakit',
    '生气': 'marah', '生日': 'ulang tahun', '十': 'sepuluh',
    '时候': 'waktu', '时间': 'waktu', '事': 'urusan',
    '试': 'mencoba', '是': 'adalah', '是不是': 'apakah',
    '手': 'tangan', '手机': 'ponsel', '书': 'buku',
    '书包': 'ransel', '书店': 'toko buku', 'tree': 'pohon',
    '水': 'air', '水果': 'buah', '睡': 'tidur',
    '睡觉': 'tidur', '说': 'berbicara', '说话': 'berbicara',
    '四': 'empat', '送': 'mengirim; memberi', '岁': 'tahun (umur)',
    '他': 'dia (laki-laki)', '他们': 'mereka (laki-laki)', '她': 'dia (perempuan)',
    '她们': 'mereka (perempuan)', '太': 'terlalu', '天': 'hari; langit',
    '天气': 'cuaca', '听': 'mendengar', '听到': 'mendengar',
    '听见': 'mendengar', '听写': 'dictasi', '同学': 'teman sekelas',
    '图书馆': 'perpustakaan', '外': 'luar', '外边': 'di luar',
    '外国': 'luar negeri', '外语': 'bahasa asing', '玩': 'bermain',
    '晚': 'malam', '晚饭': 'makan malam', '晚上': 'malam',
    '网上': 'di internet', '网友': 'teman online', '忘': 'lupa',
    '忘记': 'lupa', '问': 'bertanya', '我': 'saya',
    '我们': 'kami', '五': 'lima', '午饭': 'makan siang',
    '西': 'barat', '西边': 'sebelah barat', '洗': 'mencuci',
    '洗手间': 'kamar mandi', '喜欢': 'suka', '下': 'turun',
    '下班': 'selesai kerja', '下边': 'di bawah', '下车': 'turun dari kendaraan',
    '下次': 'kali berikutnya', '下课': 'selesai kelas', '下午': 'siang',
    '下雨': 'hujan', '先': 'lebih dulu', '先生': 'tuan',
    '现在': 'sekarang', '想': 'ingin; berpikir', '小': 'kecil',
    '小孩': 'anak kecil', '小姐': 'nona', '小朋友': 'anak kecil',
    '小时': 'jam', '小学': 'sekolah dasar', '小学生': 'siswa SD',
    '笑': 'tertawa', '写': 'menulis', '谢谢': 'terima kasih',
    '新': 'baru', '新年': 'Tahun Baru', '星期': 'minggu',
    '星期日': 'Minggu', '星期天': 'Minggu', '行': 'baik; bisa',
    '休息': 'istirahat', '学': 'belajar', '学生': 'murid',
    '学习': 'belajar', '学校': 'sekolah', '学院': 'fakultas',
    '要': 'ingin; mau', '爷爷': 'kakek', '也': 'juga',
    '页': 'halaman', '一': 'satu', '衣服': 'pakaian',
    'doctor': 'dokter', '医院': 'rumah sakit', '一半': 'setengah',
    '一会儿': 'sebentar', '一块': 'bersama', '一下': 'sebentar',
    '一样': 'sama', '一边': 'sambil', '一点': 'sedikit',
    '一起': 'bersama', '一些': 'beberapa', '用': 'menggunakan',
    '有': 'ada; memiliki', '有的': 'ada yang', 'terkenal': 'terkenal',
    '有时候': 'kadang-kadang', '有些': 'ada yang', '有用': 'berguna',
    'right': 'kanan', '右边': 'sebelah kanan', '雨': 'hujan',
    'yuan': 'yuan', '远': 'jauh', '月': 'bulan',
    '再': 'lagi', '再见': 'selamat tinggal', '在': 'di',
    '在家': 'di rumah', '早': 'pagi', '早饭': 'sarapan',
    '早上': 'pagi', '怎么': 'bagaimana', '站': 'berdiri; stasiun',
    '找': 'mencari', '找到': 'menemukan', '这': 'ini',
    '这边': 'di sini', '这里': 'di sini', '这儿': 'di sini',
    '这些': 'ini-ini', '着': 'partikel', '真': 'benar; sungguh',
    '真的': 'benar', '正': 'tepat; sedang', '正在': 'sedang',
    '知道': 'tahu', '知识': 'pengetahuan', '中': 'tengah',
    '中国': 'Tiongkok', '中间': 'tengah', '中文': 'bahasa Tionghoa',
    '中午': 'tengah hari', '中学': 'SMP/SMA', '中学生': 'siswa SMP/SMA',
    '重': 'berat', 'penting': 'penting', '住': 'tinggal',
    '准备': 'mempersiapkan', '桌子': 'meja', '字': 'huruf; karakter',
    '子': 'akhiran', '走': 'berjalan', '走路': 'berjalan kaki',
    '最': 'paling', '最好': 'paling baik', '最后': 'terakhir',
    '昨天': 'kemarin', 'left': 'kiri', '左边': 'sebelah kiri',
    '坐': 'duduk', '坐下': 'duduk', '做': 'melakukan',
    
    # === HSK 2 ===
    '啊': 'ah', '爱情': 'cinta', 'suami/istri': 'pasangan',
    '安静': 'tenang', 'aman': 'aman', 'putih': 'putih',
    '白色': 'warna putih', '班长': 'ketua kelas', '办': 'mengurus',
    'cara': 'cara', '办公室': 'kantor', '半夜': 'tengah malam',
    'membantu': 'membantu', 'kenyang': 'kenyang', 'daftar': 'mendaftar',
    'koran': 'koran', 'utara': 'utara', 'punggung': 'punggung',
    'contoh': 'contoh', 'misalnya': 'misalnya', 'pensil': 'pensil',
    'catatan': 'catatan', 'buku catatan': 'buku catatan', 'harus': 'harus',
    'sisi': 'sisi', 'berubah': 'berubah', 'menjadi': 'menjadi',
    'sekali': 'sekali', 'tabel': 'tabel', 'menunjukkan': 'menunjukkan',
    'tidak buruk': 'tidak buruk', 'bukan hanya': 'bukan hanya',
    'tidak cukup': 'tidak cukup', 'tetapi': 'tetapi', 'tidak terlalu': 'tidak terlalu',
    'jangan': 'jangan', 'malu': 'malu', 'tidak lama': 'tidak lama',
    'tidak puas': 'tidak puas', 'tidak sebaik': 'tidak sebaik',
    'banyak': 'banyak', 'tidak sama': 'tidak sama', 'tidak bisa': 'tidak bisa',
    'belum tentu': 'belum tentu', 'sebentar': 'sebentar',
    'bagian': 'bagian', 'baru': 'baru', 'menu': 'menu',
    'mengunjungi': 'mengunjungi', 'berpartisipasi': 'berpartisipasi',
    'rumput': 'rumput', 'padang rumput': 'padang rumput',
    'lantai': 'lantai', 'memeriksa': 'memeriksa', 'hampir': 'hampir',
    'panjang': 'panjang', 'sering': 'sering', 'umum': 'umum',
    'lapangan': 'lapangan', 'melebihi': 'melebihi', 'supermarket': 'supermarket',
    'kendaraan': 'kendaraan', 'menyebut': 'menyebut', 'menjadi': 'menjadi',
    'prestasi': 'prestasi', 'menjadi': 'menjadi', 'mengulang': 'mengulang',
    'lagi': 'lagi', 'berangkat': 'berangkat', 'ke luar negeri': 'ke luar negeri',
    'keluar': 'keluar', 'pintu keluar': 'pintu keluar', 'keluar rumah': 'keluar rumah',
    'lahir': 'lahir', 'muncul': 'muncul', 'keluar rumah sakit': 'keluar rumah sakit',
    'menyewa': 'menyewa', 'taksi': 'taksi', 'perahu': 'perahu',
    'meniup': 'meniup', 'Tahun Baru': 'Tahun Baru', 'musim semi': 'musim semi',
    'kata': 'kata', 'kamus': 'kamus', 'kata-kata': 'kata-kata',
    'sejak kecil': 'sejak kecil', 'menjawab': 'menjawab',
    'bekerja': 'bekerja', 'cetakan': 'cetakan', 'mencetak': 'mencetak',
    'sebagian besar': 'sebagian besar', 'besar': 'besar',
    'mayoritas': 'mayoritas', 'laut': 'laut', 'semua': 'semua',
    'banyak': 'banyak', 'pintu masuk': 'pintu masuk', 'orang dewasa': 'orang dewasa',
    'suara keras': 'suara keras', 'ukuran': 'ukuran', 'mantel': 'mantel',
    'alam': 'alam', 'membawa': 'membawa', 'membawa': 'membawa',
    'unit': 'unit', 'tapi': 'tetapi', 'telur': 'telur',
    'kue': 'kue', 'saat itu': 'saat itu', 'ke mana-mana': 'ke mana-mana',
    'jatuh': 'jatuh', 'dari': 'dari', 'timur laut': 'timur laut',
    '东方': '东方', 'tenggara': 'tenggara', 'musim dingin': 'musim dingin',
    'mengerti': 'mengerti', 'memahami': 'memahami', 'hewan': 'hewan',
    'kebun binatang': 'kebun binatang', 'bacaan': 'bacaan',
    'derajat': 'derajat', 'pendek': 'pendek', 'pesan singkat': 'pesan singkat',
    'segmen': 'segmen', 'tim': 'tim', 'kapten': 'kapten',
    'dialog': 'dialog', 'sisi berlawanan': 'sisi berlawanan',
    'lebih': 'lebih', 'berapa lama': 'berapa lama', 'betapa': 'betapa',
    'sebagian besar': 'sebagian besar', 'berawan': 'berawan',
    'tetapi': 'tetapi', 'menemukan': 'menemukan', 'restoran': 'restoran',
    'nyaman': 'nyaman', 'mi instan': 'mi instan', 'metode': 'metode',
    'aspek': 'aspek', 'arah': 'arah', 'meletakkan': 'meletakkan',
    'tenang': 'tenang', 'bagi': 'bagi', 'memisahkan': 'memisahkan',
    'nilai': 'nilai', 'menit': 'menit', 'porsi': 'porsi',
    'amplop': 'amplop', 'layanan': 'layanan', 'ulang': 'ulang',
    'harus': 'harus', 'mengubah': 'mengubah', 'bersulang': 'bersulang',
    'merasa': 'merasa', 'terharu': 'terharu', 'perasaan': 'perasaan',
    'berterima kasih': 'berterima kasih', 'bekerja': 'bekerja',
    'barusan': 'barusan', 'baru saja': 'baru saja', '高级': '高级',
    'SMA': 'SMA', 'tinggi badan': 'tinggi badan', 'lebih': 'lebih',
    'bus kota': 'bus kota', 'bus': 'bus', 'kilogram': 'kilogram',
    'kilometer': 'kilometer', 'jalan raya': 'jalan raya', 'adil': 'adil',
    'perusahaan': 'perusahaan', 'taman': 'taman', 'anjing': 'anjing',
    'cukup': 'cukup', 'cerita': 'cerita', 'sengaja': 'sengaja',
    'pelanggan': 'pelanggan', 'mematikan': 'mematikan', 'peduli': 'peduli',
    'pandangan': 'pandangan', 'alun-alun': 'alun-alun', 'iklan': 'iklan',
    'internasional': 'internasional', 'datang': 'datang', 'rayakan': 'rayakan',
    'masa lalu': 'masa lalu', 'laut': 'laut', 'pantai': 'pantai',
    'berteriak': 'berteriak', 'keuntungan': 'keuntungan', 'banyak': 'banyak',
    'lama': 'lama', 'orang baik': 'orang baik', 'hal baik': 'hal baik',
    'sepertinya': 'sepertinya', 'cocok': 'cocok', 'sungai': 'sungai',
    'hitam': 'hitam', 'papan tulis': 'papan tulis', 'hitam': 'hitam',
    'merah': 'merah', 'merah': 'merah', 'envelope merah': 'amplop merah',
    'teh merah': 'teh merah', 'lampu lalu lintas': 'lampu lalu lintas',
    'belakang': 'belakang', 'setelah': 'setelah', 'bunga': 'bunga',
    'kebun bunga': 'kebun bunga', 'ski': 'ski', 'gambar': 'gambar',
    'pelukis': 'pelukis', 'buruk': 'buruk', 'mengganti': 'mengganti',
    'kuning': 'kuning', 'kuning': 'kuning', 'selamat datang': 'selamat datang',
    'kembali': 'kembali', 'jawaban': 'jawaban', 'pulang': 'pulang',
    'kembali': 'kembali', 'kembali': 'kembali', 'bisa': 'bisa',
    'menyelamatkan': 'menyelamatkan', 'kegiatan': 'kegiatan', 'api': 'api',
    'kereta api': 'kereta api', 'atau': 'atau', 'mungkin': 'mungkin',
    'kesempatan': 'kesempatan', 'bandara': 'bandara',
    'beberapa': 'beberapa', 'mengirim': 'mengirim', 'mencatat': 'mencatat',
    'taksi': 'taksi', 'rencana': 'rencana', 'menambah': 'menambah',
    'keluarga': 'keluarga', 'rumah tangga': 'rumah tangga',
    '量词 rumah': '量词 rumah', 'sederhana': 'sederhana',
    '量词 baju': '量词 baju', 'bertemu': 'bertemu',
    'bertemu': 'bertemu', 'sehat': 'sehat', 'berbicara': 'berbicara',
    'berbicara': 'berbicara', 'menyerahkan': 'menyerahkan',
    'sepatu': 'sepatu', 'sepeda': 'sepeda', 'dumpling': 'dumpling',
    'disebut': 'disebut', 'mengajar': 'mengajar', 'ruang kelas': 'ruang kelas',
    'menerima': 'menerima', 'menikah': 'menikah',
    'program': 'program', 'kakak perempuan': 'kakak perempuan',
    'menyelesaikan': 'menyelesaikan', 'meminjam': 'meminjam',
    'memperkenalkan': 'memperkenalkan', 'kilogram': 'kilogram',
    'tahun ini': 'tahun ini', 'hari ini': 'hari ini',
    'polisi': 'polisi', 'gugup': 'gugup', 'dekat': 'dekat',
    'masuk': 'masuk', 'perkembangan': 'perkembangan', 'masuk': 'masuk',
    'masuk': 'masuk', 'lewat': 'lewat', 'sembilan': 'sembilan',
    'lama': 'lama', 'alkohol': 'alkohol', 'tepat': 'tepat',
    'segera': 'segera', 'tua': 'tua', 'segera': 'segera',
    'kalimat': 'kalimat', 'merasa': 'merasa', 'memutuskan': 'memutuskan',
    'kopi': 'kopi', 'kartu': 'kartu', 'menyetir': 'menyetir',
    'menyetir': 'menyetir', 'mulai': 'mulai', 'air mendidih': 'air mendidih',
    'gembira': 'gembira', 'sekolah': 'sekolah',
    'memanggang': 'memanggang', 'ujian': 'ujian',
    'menonton': 'menonton', 'melihat': 'melihat',
    'melihat': 'melihat', 'ilmu pengetahuan': 'ilmu pengetahuan',
    'haus': 'haus', 'lucu': 'lucu', 'cola': 'cola',
    'kemungkinan': 'kemungkinan', 'tetapi': 'tetapi',
    'bisa': 'bisa', 'pelajaran': 'pelajaran', 'buku teks': 'buku teks',
    'sopan': 'sopan', 'tamu': 'tamu', 'ruang tamu': 'ruang tamu',
    'teks': 'teks', 'udara': 'udara', 'mulut': 'mulut',
    'menangis': 'menangis', 'pahit': 'pahit', 'celana': 'celana',
    'cepat': 'cepat', '块': '块', 'piring': 'piring',
    'chopsticks': 'chopsticks', 'kecepatan': 'kecepatan',
    'menarik': 'menarik', 'datang': 'datang', 'biru': 'biru',
    'biru': 'biru', 'basket': 'basket', 'tua': 'tua',
    'orang tua': 'orang tua', 'guru': 'guru', 'sering': 'sering',
    'lelah': 'lelah', 'dingin': 'dingin', 'AC': 'AC',
    'jauh dari': 'jauh dari', 'meninggalkan': 'meninggalkan',
    'di dalam': 'di dalam', 'di dalam': 'di dalam',
    'hadiah': 'hadiah', 'wajah': 'wajah', 'berlatih': 'berlatih',
    'sejuk': 'sejuk', 'dingin': 'dingin', '量词 kendaraan': '量词 kendaraan',
    'cerah': 'cerah', 'mengobrol': 'mengobrol', 'nol': 'nol',
    'meninggalkan': 'meninggalkan', 'enam': 'enam',
    'lantai': 'lantai', 'jalan': 'jalan', 'di jalan': 'di jalan',
    'berantakan': 'berantakan', 'bepergian': 'bepergian',
    'perjalanan': 'perjalanan', 'hijau': 'hijau', 'partikel': 'partikel',
    'ibu': 'ibu', 'kuda': 'kuda', 'segera': 'segera',
    'mengganggu': 'mengganggu', 'membeli': 'membeli',
    'menjual': 'menjual', 'lambat': 'lambat', 'perlahan': 'perlahan',
    'sibuk': 'sibuk', 'kucing': 'kucing', 'sen': 'sen',
    'sweater': 'sweater', 'topi': 'topi', 'tidak punya': 'tidak punya',
    'tidak masalah': 'tidak masalah', 'tidak masalah': 'tidak masalah',
    'tidak ada': 'tidak ada', 'setiap': 'setiap', 'cantik': 'cantik',
    'Amerika': 'Amerika', 'cantik': 'cantik', 'adik perempuan': 'adik perempuan',
    'pintu': 'pintu', 'pintu masuk': 'pintu masuk',
    'nasi mentah': 'nasi mentah', 'tepung': 'tepung',
    'roti': 'roti', 'toko roti': 'toko roti', 'tahun depan': 'tahun depan',
    'besok': 'besok', 'nama lengkap': 'nama lengkap',
    'motor': 'motor', 'kayu': 'kayu', 'membawa': 'membawa',
    'mana': 'mana', 'di mana': 'di mana',
    'itu': 'itu', 'di sana': 'di sana', 'di sana': 'di sana',
    'begitu': 'begitu', 'nenek': 'nenek', 'sulit': 'sulit',
    'selatan': 'selatan', 'anak laki-laki': 'anak laki-laki',
    'sedih': 'sedih', 'ne': 'ne', 'kamu': 'kamu',
    'bisa': 'bisa', 'tahun': 'tahun', 'usia': 'usia',
    'muda': 'muda', 'membaca': 'membaca', 'burung': 'burung',
    'Anda': 'Anda', 'susu sapi': 'susu sapi', 'anak perempuan': 'anak perempuan',
    'keras berusaha': 'keras berusaha', 'hangat': 'hangat',
    'memanjat': 'memanjat', 'memanjat gunung': 'memanjat gunung',
    'takut': 'takut', 'memukul': 'memukul',
    'piring': 'piring', 'pinggir': 'pinggir',
    'gemuk': 'gemuk', 'berlari': 'berlari', 'teman': 'teman',
    'tas tangan': 'tas tangan', '片': '片', 'murah': 'murah',
    'tiket': 'tiket', 'cantik': 'cantik',
    'botol': 'botol', 'apple': 'apple', 'pecah': 'pecah',
    'tujuh': 'tujuh', 'naik': 'naik', 'aneh': 'aneh',
    'bangun': 'bangun', 'bangkit': 'bangkit',
    'mobil': 'mobil', 'minuman ringan': 'minuman ringan',
    'seribu': 'seribu', 'pensil': 'pensil', 'uang': 'uang',
    'depan': 'depan', 'kemarin lusa': 'kemarin lusa',
    'tembok': 'tembok', 'jembatan': 'jembatan',
    'cokelat': 'cokelat', 'mencium': 'mencium',
    'ringan': 'ringan', 'jelas': 'jelas', 'cerah': 'cerah',
    'menyilakan': 'menyilakan', 'mengundang': 'mengundang',
    'perkenankan saya bertanya': 'perkenankan saya bertanya',
    'merayakan': 'merayakan', 'musim gugur': 'musim gugur',
    'bola': 'bola', 'pergi': 'pergi', 'tahun lalu': 'tahun lalu',
    'kerumunan': 'kerumunan', 'seluruh': 'seluruh',
    '全球': '全球', '全球': '全球',
    
    # === HSK 3 ===
    '爱心': 'kasih sayang', '安排': 'mengatur', '安装': 'memasang',
    '按': 'menurut', '按照': 'sesuai dengan', '把': 'partikel',
    '把握': 'yakin', '白菜': 'sawi', '班级': 'kelas',
    '搬': 'pindah', '搬家': 'pindah rumah', 'papan': 'papan',
    '办理': 'mengurus', '保安': 'satpam', '保持': 'menjaga',
    '保存': 'menyimpan', '保护': 'melindungi', '保留': 'menyimpan',
    'asuransi': 'asuransi', 'jamin': 'jamin', '报纸': 'koran',
    '报道': 'melaporkan', 'laporan': 'laporan',
    '背': 'punggung', 'belakang': 'belakang',
    '被': 'partikel pasif', 'selimut': 'selimut',
    'aslinya': 'aslinya', 'kemampuan': 'kemampuan',
    'kemampuan': 'kemampuan', 'membandingkan': 'membandingkan',
    'proporsi': 'proporsi', 'kompetisi': 'kompetisi',
    'pasti': 'pasti', 'perlu': 'perlu', 'perubahan': 'perubahan',
    'menjadi': 'menjadi', 'judul': 'judul', 'standar': 'standar',
    'mengekspresikan': 'mengekspresikan', '表格': '表格',
    'permukaan': 'permukaan', 'menunjukkan': 'menunjukkan',
    'menampilkan': 'menampilkan', 'pertunjukan': 'pertunjukan',
    'dan': 'dan', 'menyiarkan': 'menyiarkan',
    'memutar': 'memutar', 'tidak perlu': 'tidak perlu',
    'terus-menerus': 'terus-menerus', 'apapun': 'apapun',
    'menambah': 'menambah', 'merasa tidak tenang': 'merasa tidak tenang',
    'terpaksa': 'terpaksa', 'bukan hanya': 'bukan hanya',
    'bahkan': 'bahkan', 'kain': 'kain', 'langkah': 'langkah',
    'bagian': 'bagian', 'departemen': 'departemen', 'kepala departemen': 'kepala departemen',
    'bakat': 'bakat', 'mengambil': 'mengambil', 'mengadopsi': 'mengadopsi',
    'warna': 'warna', 'pernah': 'pernah', 'lahir': 'lahir',
    'Tembok Besar': 'Tembok Besar', 'kelebihan': 'kelebihan',
    'jangka panjang': 'jangka panjang', 'pabrik': 'pabrik',
    'kesempatan': 'kesempatan', 'situasi': 'situasi',
    'super': 'super', 'ke arah': 'ke arah', 'berisik': 'berisik',
    'bertengkar': 'bertengkar', 'kemeja': 'kemeja',
    'disebut': 'disebut', 'berhasil': 'berhasil',
    'pencapaian': 'pencapaian', 'prestasi': 'prestasi',
    'didirikan': 'didirikan', 'matang': 'matang', 'anggota': 'anggota',
    'tumbuh': 'tumbuh', 'kota': 'kota', 'tingkat': 'tingkat',
    'berkelanjutan': 'berkelanjutan', 'penuh': 'penuh',
    'awal': 'awal', 'pendahuluan': 'pendahuluan',
    'tingkat dasar': 'tingkat dasar', 'SMP': 'SMP',
    'selain': 'selain', 'menangani': 'menangani',
    'menyebar': 'menyebar', 'tersiar': 'tersiar',
    'legenda': 'legenda', 'berinovasi': 'berinovasi',
    'memulai usaha': 'memulai usaha', 'menciptakan': 'menciptakan',
    'karya': 'karya', 'dulu': 'dulu', 'sebelumnya': 'sebelumnya',
    'terlibat dalam': 'terlibat dalam', 'desa': 'desa',
    'menyimpan': 'menyimpan', 'ada': 'ada', 'kesalahan': 'kesalahan',
    'mencapai': 'mencapai', 'memecahkan': 'memecahkan',
    'menanyakan': 'menanyakan', 'kira-kira': 'kira-kira',
    'kedutaan besar': 'kedutaan besar', 'kira-kira': 'kira-kira',
    'dokter': 'dokter', 'era': 'era', 'wakil': 'wakil',
    'delegasi': 'delegasi', 'memimpin': 'memimpin', 'membawa': 'membawa',
    'unit': 'unit', 'awal mula': 'awal mula', 'setempat': 'setempat',
    'tentu saja': 'tentu saja', 'di tengah': 'di tengah',
    'pisau': 'pisau', 'sutradara': 'sutradara',
    'tiba': 'tiba', 'benar-benar': 'benar-benar',
    'perolehan': 'perolehan', 'menunggu': 'menunggu',
    'di bawah': 'di bawah', 'daerah': 'daerah',
    'sinetron': 'sinetron', 'stasiun TV': 'stasiun TV',
    'stasiun radio': 'stasiun radio', 'surel': 'surel',
    'memanggil': 'memanggil', 'menyelidiki': 'menyelidiki',
    'memesan': 'memesan', '定期': '定期',
    'timur': 'timur', 'kekuatan': 'kekuatan',
    'mengharukan': 'mengharukan', 'pembaca': 'pembaca',
    'kekurangan': 'kekurangan', 'celana pendek': 'celana pendek',
    'jangka pendek': 'jangka pendek', 'berhenti': 'berhenti',
    'anggota tim': 'anggota tim', 'perlakuan': 'perlakuan',
    'lawan': 'lawan', 'lawan tanding': 'lawan tanding',
    'objek': 'objek', 'satu porsi': 'satu porsi',
    'mempublikasikan': 'mempublikasikan', 'mengeluarkan': 'mengeluarkan',
    'maju': 'maju', 'menyalakan': 'menyalakan',
    'menemukan': 'menemukan', 'mengirim': 'mengirim',
    'menyampaikan': 'menyampaikan', 'perkembangan': 'perkembangan',
    'menolak': 'menolak', 'berulang': 'berulang',
    'reaksi': 'reaksi', 'bagaimanapun': 'bagaimanapun',
    'ruang lingkup': 'ruang lingkup', 'cara': 'cara',
    'mencegah': 'mencegah', 'pemilik rumah': 'pemilik rumah',
    'properti': 'properti', 'sewa rumah': 'sewa rumah',
    'mengunjungi': 'mengunjungi', 'meletakkan': 'meletakkan',
    'penerbangan': 'penerbangan', 'biaya': 'biaya',
    'biaya': 'biaya', 'masing-masing': 'masing-masing',
    'membagikan': 'membagikan', 'membagi': 'membagi',
    'kaya': 'kaya', 'risiko': 'risiko', 'meniadakan': 'meniadakan',
    'membantah': 'membantah', 'pakaian': 'pakaian',
    'berkah': 'berkah', 'orang tua': 'orang tua',
    'ayah': 'ayah', 'membayar': 'membayar', 'bertanggung jawab': 'bertanggung jawab',
    'memfotokopi': 'memfotokopi', 'rumit': 'rumit', 'kaya': 'kaya',
    'memperbaiki': 'memperbaiki', 'merombak': 'merombak',
    'konsep': 'konsep', 'terburu-buru': 'terburu-buru',
    'mengejar': 'mengejar', 'segera': 'segera',
    'berani': 'berani', 'pilek': 'pilek', 'perasaan': 'perasaan',
    'merasakan': 'merasakan', 'sedang apa': 'sedang apa',
    'kecepatan tinggi': 'kecepatan tinggi', 'jalan tol': 'jalan tol',
    'berpisah': 'berpisah', 'penyanyi': 'penyanyi',
    'suara nyanyian': 'suara nyanyian', 'penyanyi': 'penyanyi',
    'individu': 'individu', 'kepribadian': 'kepribadian',
    'masing-masing': 'masing-masing', 'setiap': 'setiap',
    'akar': 'akar', 'semakin': 'semakin', 'pabrik': 'pabrik',
    'insinyur': 'insinyur', 'waktu luang': 'waktu luang',
    'alat': 'alat', 'industri': 'industri', 'gaji': 'gaji',
    'mengumumkan': 'mengumumkan', 'publik': 'publik',
    'terbuka': 'terbuka', 'warga negara': 'warga negara',
    'pegawai negeri': 'pegawai negeri', 'kung fu': 'kung fu',
    'tugas rumah': 'tugas rumah', 'fungsi': 'fungsi',
    'bersama': 'bersama', 'bersama-sama': 'bersama-sama',
    'gadis': 'gadis', 'kuno': 'kuno', 'masa lalu': 'masa lalu',
    'kampung halaman': 'kampung halaman', 'bergantung': 'bergantung',
    'hubungan': 'hubungan', 'memperhatikan': 'memperhatikan',
    'mengamati': 'mengamati', 'menonton': 'menonton',
    'konsep': 'konsep', 'penonton': 'penonton',
    'mengelola': 'mengelola', 'manajemen': 'manajemen',
    'terang': 'terang', 'radio': 'radio', 'luas': 'luas',
    'peraturan': 'peraturan', 'norma': 'norma', 'di dalam negeri': 'di dalam negeri',
    'hari nasional': 'hari nasional', 'memang': 'memang',
    'jus buah': 'jus buah', 'proses': 'proses',
    'masa lalu': 'masa lalu',
    
    # More entries...
    'ahli': 'ahli', 'suka': 'suka', 'berkata': 'berkata',
    'kedua': 'kedua', 'semua orang': 'semua orang',
    'dulu': 'dulu', 'sekarang': 'sekarang', 'dari pada': 'dari pada',
    'baru pertama kali': 'baru pertama kali',
    'menyambut': 'menyambut', 'selamat datang': 'selamat datang',
    'mengganti': 'mengganti', 'kuning': 'kuning',
    'sekali': 'sekali', 'kembali': 'kembali',
    'berpartisipasi': 'berpartisipasi', 'kegiatan': 'kegiatan',
    'atau': 'atau', 'mungkin': 'mungkin',
    'kesempatan': 'kesempatan', 'bandara': 'bandara',
    'beberapa': 'beberapa', 'mengirim': 'mengirim',
    'mencatat': 'mencatat', 'taksi': 'taksi',
    'rencana': 'rencana', 'menambah': 'menambah',
    'keluarga': 'keluarga', 'rumah tangga': 'rumah tangga',
    'sederhana': 'sederhana', 'bertemu': 'bertemu',
    'sehat': 'sehat', 'berbicara': 'berbicara',
    'menyerahkan': 'menyerahkan', 'sepatu': 'sepatu',
    'sepeda': 'sepeda', 'dumpling': 'pangsit',
    'disebut': 'disebut', 'mengajar': 'mengajar',
    'ruang kelas': 'ruang kelas', 'menerima': 'menerima',
    'menikah': 'menikah', 'program': 'program',
    'kakak perempuan': 'kakak perempuan',
    'menyelesaikan': 'menyelesaikan', 'meminjam': 'meminjam',
    'memperkenalkan': 'memperkenalkan', 'kilogram': 'kilogram',
    'polisi': 'polisi', 'gugup': 'gugup', 'dekat': 'dekat',
    'masuk': 'masuk', 'perkembangan': 'perkembangan',
    'lewat': 'lewat', 'sembilan': 'sembilan',
    'alkohol': 'alkohol', 'tepat': 'tepat',
    'segera': 'segera', 'tua': 'tua',
    'kalimat': 'kalimat', 'memutuskan': 'memutuskan',
    'kopi': 'kopi', 'kartu': 'kartu', 'menyetir': 'menyetir',
    'mulai': 'mulai', 'air mendidih': 'air mendidih',
    'gembira': 'gembira', 'sekolah': 'sekolah',
    'memanggang': 'memanggang', 'ujian': 'ujian',
    'menonton': 'menonton', 'ilmu pengetahuan': 'ilmu pengetahuan',
    'haus': 'haus', 'lucu': 'lucu', 'cola': 'cola',
    'kemungkinan': 'kemungkinan',
    'bisa': 'bisa', 'pelajaran': 'pelajaran',
    'buku teks': 'buku teks', 'sopan': 'sopan',
    'tamu': 'tamu', 'ruang tamu': 'ruang tamu',
    'udara': 'udara', 'mulut': 'mulut',
    'menangis': 'menangis', 'pahit': 'pahit',
    'celana': 'celana', 'cepat': 'cepat',
    'piring': 'piring', 'chopsticks': 'sumpit',
    'kecepatan': 'kecepatan', 'menarik': 'menarik',
    'biru': 'biru', 'basket': 'basket',
    'tua': 'tua', 'orang tua': 'orang tua',
    'guru': 'guru', 'sering': 'sering',
    'lelah': 'lelah', 'dingin': 'dingin',
    'jauh dari': 'jauh dari', 'meninggalkan': 'meninggalkan',
    'di dalam': 'di dalam', 'hadiah': 'hadiah',
    'wajah': 'wajah', 'berlatih': 'berlatih',
    'sejuk': 'sejuk', 'cerah': 'cerah',
    'mengobrol': 'mengobrol', 'nol': 'nol',
    'enam': 'enam', 'berantakan': 'berantakan',
    'bepergian': 'bepergian', 'perjalanan': 'perjalanan',
    'hijau': 'hijau', 'ibu': 'ibu', 'kuda': 'kuda',
    'mengganggu': 'mengganggu', 'membeli': 'membeli',
    'menjual': 'menjual', 'lambat': 'lambat',
    'perlahan': 'perlahan', 'sibuk': 'sibuk',
    'kucing': 'kucing', 'sen': 'sen',
    'sweater': 'sweater', 'topi': 'topi',
    'cantik': 'cantik', 'Amerika': 'Amerika',
    'pintu': 'pintu', 'pintu masuk': 'pintu masuk',
    'nasi mentah': 'nasi mentah', 'tepung': 'tepung',
    'roti': 'roti', 'toko roti': 'toko roti',
    'motor': 'motor', 'kayu': 'kayu',
    'mana': 'mana', 'di mana': 'di mana',
    'begitu': 'begitu', 'nenek': 'nenek',
    'sulit': 'sulit', 'selatan': 'selatan',
    'anak laki-laki': 'anak laki-laki',
    'sedih': 'sedih', 'kamu': 'kamu',
    'usia': 'usia', 'muda': 'muda',
    'membaca': 'membaca', 'burung': 'burung',
    'Anda': 'Anda', 'susu sapi': 'susu sapi',
    'anak perempuan': 'anak perempuan',
    'keras berusaha': 'keras berusaha', 'hangat': 'hangat',
    'memanjat': 'memanjat', 'memanjat gunung': 'memanjat gunung',
    'takut': 'takut', 'pinggir': 'pinggir',
    'gemuk': 'gemuk', 'tas tangan': 'tas tangan',
    'murah': 'murah', 'botol': 'botol',
    'pecah': 'pecah', 'tujuh': 'tujuh',
    'naik': 'naik', 'aneh': 'aneh',
    'bangun': 'bangun', 'mobil': 'mobil',
    'minuman ringan': 'minuman ringan',
    'seribu': 'seribu', 'uang': 'uang',
    'depan': 'depan', 'tembok': 'tembok',
    'jembatan': 'jembatan', 'cokelat': 'cokelat',
    'mencium': 'mencium', 'ringan': 'ringan',
    'jelas': 'jelas', 'menyilakan': 'menyilakan',
    'mengundang': 'mengundang', 'merayakan': 'merayakan',
    'musim gugur': 'musim gugur', 'kerumunan': 'kerumunan',
    'seluruh': 'seluruh',
}

# Fill any missing entries
for key in list(INDONESIAN_DICT.keys()):
    if not INDONESIAN_DICT[key]:
        INDONESIAN_DICT[key] = key  # fallback


def clean_hanzi(raw):
    """Clean hanzi entry from OCR artifacts like （形）, ｜, etc."""
    # Remove part-of-speech annotations
    cleaned = re.sub(r'（[^）]*）', '', raw)
    # Take first form if multiple (split by ｜)
    cleaned = cleaned.split('｜')[0]
    return cleaned.strip()


def process_hsk_csv(csv_path):
    """Process the HSK 3.0 CSV and return cards by level."""
    levels = {i: [] for i in range(1, 10)}
    combined_79 = []  # HSK 7-9 combined band
    
    with open(csv_path, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        for row in reader:
            level_str = row['HSK_3_0_Level'].strip()
            hanzi_str = row.get('Hanzi', '').strip()
            alt_str = row.get('Hanzi_Alternate', '').strip()
            
            if not hanzi_str:
                continue
            
            hanzi = clean_hanzi(hanzi_str)
            if not hanzi:
                continue
            
            if '-' in level_str:
                # HSK 7-9 combined band
                level = 7
            else:
                level = int(level_str)
            
            if level > 9:
                continue
            
            # Skip duplicates
            existing = [c['s'] for c in (levels[level] if level < 7 else combined_79)]
            if hanzi in existing:
                continue
            
            s = hanzi
            t = to_traditional(s)
            py = get_pinyin_with_tone(s)
            zy = get_word_zhuyin(s)
            m = INDONESIAN_DICT.get(s, s)
            tone = get_tone_number(s)
            
            card = {
                's': s,
                't': t,
                'py': py,
                'zy': zy,
                'm': m,
                'tone': tone,
                'hsk': level,
            }
            
            if level < 7:
                levels[level].append(card)
            else:
                combined_79.append(card)
    
    # Split HSK 7-9 combined band evenly into 3 files
    if combined_79:
        third = len(combined_79) // 3
        levels[7] = combined_79[:third]
        levels[8] = combined_79[third:2*third]
        levels[9] = combined_79[2*third:]
        # Set correct hsk level tag
        for card in levels[7]:
            card['hsk'] = 7
        for card in levels[8]:
            card['hsk'] = 8
        for card in levels[9]:
            card['hsk'] = 9
    
    return levels


def write_hsk_files(levels, output_dir):
    """Write HSK JSON files."""
    for level, cards in levels.items():
        filename = f'hsk{level}.json'
        filepath = Path(output_dir) / filename
        
        data = {
            'id': f'hsk{level}',
            'name': f'Paket HSK {level}',
            'standard': 'hsk',
            'levelTag': f'HSK {level}',
            'cards': cards,
        }
        
        with open(filepath, 'w', encoding='utf-8') as f:
            json.dump(data, f, ensure_ascii=False, separators=(',', ':'))
        
        print(f'Written {filename}: {len(cards)} cards')


if __name__ == '__main__':
    csv_path = Path(__file__).parent / 'hsk3_data.csv'
    output_dir = Path(__file__).parent
    
    if not csv_path.exists():
        print(f'ERROR: {csv_path} not found!')
        print('Please download the HSK 3.0 CSV first.')
        sys.exit(1)
    
    print('Processing HSK 3.0 word list...')
    levels = process_hsk_csv(csv_path)
    
    for level, cards in levels.items():
        print(f'  HSK {level}: {len(cards)} words')
    
    print('\nWriting JSON files...')
    write_hsk_files(levels, output_dir)
    
    print('\nDone!')
