#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Perbaikan kamus ZHONGWEN SHU:
  1. Hitung ulang field `tone` dari tanda nada pinyin (deterministik).
  2. Koreksi arti calque (terjemahan harfiah per-karakter yang salah).
  3. Bersihkan kebocoran bahasa Inggris.
Hanya field `tone` & `m` yang disentuh. JSON ditulis ulang mengikuti format
satu-kartu-per-baris yang sudah ada (indent ringkas).
"""
import json, glob, io, sys, ast, os
sys.stdout.reconfigure(encoding='utf-8')
os.chdir(os.path.dirname(os.path.abspath(__file__)))

# ----- 1. TONE dari pinyin -----
TONE_MARKS = {1:"āēīōūǖ", 2:"áéíóúǘ", 3:"ǎěǐǒǔǚ", 4:"àèìòùǜ"}
def first_tone(py):
    if not py: return 5
    seg = py.split()[0]
    for ch in seg:
        for t, marks in TONE_MARKS.items():
            if ch in marks: return t
    return 5  # tak ada tanda = netral

# ----- 2. Koreksi arti calque (kunci = simplified headword) -----
# Hanya kartu yang artinya MASIH berupa calque yang akan diganti.
CORR = {
 "吃惊":"terkejut; kaget","出色":"menonjol; luar biasa","窗子":"jendela",
 "大楼":"gedung bertingkat","大陆":"daratan; benua; Tiongkok daratan",
 "付出":"mengeluarkan; mengorbankan","海水":"air laut","黄金":"emas",
 "男女":"pria dan wanita","妻子":"istri","轻易":"dengan mudah; gampang",
 "树叶":"daun","小吃":"jajanan; makanan ringan","叶子":"daun",
 "以内":"di dalam; dalam batas","重量":"berat; bobot","北极":"Kutub Utara",
 "不足":"kurang; tidak cukup","从中":"dari dalamnya; di antaranya",
 "大脑":"otak besar; otak","放大":"memperbesar","更新":"memperbarui; pembaruan",
 "灰色":"abu-abu; kelabu","近来":"akhir-akhir ini; belakangan ini",
 "买卖":"jual beli; dagang","南北":"arah utara dan selatan","南极":"Kutub Selatan",
 "难以":"sulit untuk; sukar","脑子":"otak","入门":"pengantar; dasar; tahap pemula",
 "香肠":"sosis","许可":"izin; mengizinkan","以往":"masa lalu; dahulu",
 "用来":"dipakai untuk; digunakan untuk","中药":"obat herbal Tiongkok",
 "竹子":"bambu","长跑":"lari jarak jauh","长远":"jangka panjang",
 "低头":"menunduk","海外":"luar negeri; mancanegara","街头":"sudut jalan; di jalanan",
 "惊人":"mengejutkan; luar biasa","来往":"hubungan; lalu lalang; bergaul",
 "楼房":"gedung bertingkat","母女":"ibu dan anak perempuan","母子":"ibu dan anak",
 "难忘":"tak terlupakan","内衣":"pakaian dalam","跳水":"loncat indah; terjun ke air",
 "推出":"meluncurkan; merilis","外出":"keluar; bepergian","外来":"dari luar; asing",
 "外头":"di luar","外衣":"pakaian luar; jaket","往来":"hubungan; lalu lalang",
 "往年":"tahun-tahun lalu","心愿":"keinginan; harapan","雨衣":"jas hujan",
 "中外":"dalam dan luar negeri","足以":"cukup untuk","不理":"mengabaikan; tak peduli",
 "不已":"tak henti-henti","长足":"pesat (kemajuan)","丑恶":"keji; buruk",
 "出厂":"keluar dari pabrik","出丑":"mempermalukan diri","出卖":"menjual; mengkhianati",
 "出山":"terjun ke dunia kerja; tampil","出头":"menonjol; lebih dari",
 "出土":"tergali dari tanah; ditemukan","出血":"berdarah; pendarahan",
 "从头":"dari awal","从未":"tidak pernah","打量":"mengamati; menaksir",
 "放水":"mengalirkan air; sengaja mengalah","风水":"fengshui; geomansi",
 "风味":"cita rasa khas","风雨":"badai; suka duka","风云":"situasi bergejolak",
 "高贵":"mulia; agung","贵重":"berharga; bernilai tinggi",
 "海量":"berkapasitas besar; kuat minum","黑心":"berhati jahat; licik",
 "红火":"ramai; berkembang pesat","红眼":"iri; cemburu",
 "灰心":"putus asa; patah semangat","火花":"percikan api","火山":"gunung berapi",
 "火药":"mesiu; bubuk peledak","宽厚":"murah hati; berlapang dada",
 "拉锁":"ritsleting","来电":"ada arus listrik; telepon masuk; tertarik",
 "来年":"tahun depan","老大":"anak tertua; bos","老远":"jauh sekali",
 "脑海":"benak; pikiran","人文":"humaniora; budaya manusia",
 "少量":"sedikit; jumlah kecil","少女":"gadis; remaja putri",
 "树木":"pepohonan","树枝":"ranting; dahan","太极":"taiji",
 "听从":"menuruti; mematuhi","同年":"tahun yang sama; seangkatan",
 "同人":"rekan; sesama komunitas","推理":"penalaran; deduksi",
 "推敲":"mengkaji cermat; menimbang kata","脱落":"terlepas; rontok",
 "文人":"sastrawan; kaum terpelajar","香水":"parfum","香味":"aroma harum; wangi",
 "小丑":"badut","心肠":"hati; perasaan","心声":"suara hati; isi hati",
 "心胸":"kelapangan hati; wawasan","心血":"jerih payah; usaha keras",
 "雪山":"gunung bersalju","眼红":"iri; cemburu","眼色":"isyarat mata",
 "应付":"menghadapi; mengatasi","用人":"merekrut orang; pembantu",
 "友善":"ramah; bersahabat","知足":"merasa puas; tahu cukup",
 "重心":"titik berat; pusat perhatian","坐落":"terletak; berlokasi",
 "室友":"teman sekamar","慢跑":"lari santai; joging","药房":"apotek",
 "花心":"tidak setia; mata keranjang","慢用":"selamat menikmati",
 "年年":"setiap tahun","大半":"sebagian besar; kemungkinan besar",
 "电子":"elektron; elektronik","法子":"cara; metode",
 "花草":"tanaman hias; bunga dan rerumputan","花色":"corak; motif",
 "人心":"hati nurani; sentimen publik","师母":"istri guru","校友":"alumni",
 "小子":"bocah; anak laki-laki","心跳":"detak jantung","细小":"kecil; halus; sepele",
 "雪花":"kepingan salju","许愿":"membuat permohonan; bernazar",
 "须知":"hal yang perlu diketahui; petunjuk","远大":"luhur; muluk (cita-cita)",
 "草药":"obat herbal; jamu","出错":"membuat kesalahan; keliru",
 "法人":"badan hukum","放宽":"melonggarkan; memperlonggar",
 "老子":"ayah (informal); Laozi","每每":"kerap kali; sering",
 "旁人":"orang lain; orang sekitar","旁听":"menyimak (kelas/sidang) sebagai pendengar",
 "轻薄":"genit; kurang ajar","雪人":"manusia salju","长子":"anak laki-laki sulung",
 "中和":"menetralkan; netralisasi","中叶":"pertengahan (abad/zaman)",
 "中风":"stroke","中肯":"tepat sasaran; pas","重用":"mengangkat ke posisi penting",
 "白白":"sia-sia; percuma","长年":"sepanjang tahun; bertahun-tahun",
 "肠子":"usus","重重":"berlapis-lapis; bertubi-tubi","重整":"menata ulang; merestrukturisasi",
 "出声":"bersuara","打从":"sejak; dari","放火":"membakar; menyulut api",
 "放眼":"memandang jauh","风声":"kabar angin; desas-desus",
 "风土":"kondisi alam dan adat setempat","和善":"ramah; baik hati",
 "江湖":"dunia pengembara; dunia persilatan","江山":"tanah air; kekuasaan negara",
 "宽大":"luas; lapang; murah hati","年少":"muda; belia","年头":"tahun; masa; zaman",
 "敲打":"memukul-mukul; menyindir","青山":"perbukitan hijau",
 "轻重":"bobot kepentingan; berat-ringan","人头":"jumlah orang; per kepala",
 "善恶":"baik dan buruk","山水":"pemandangan alam; lanskap",
 "山头":"puncak bukit; faksi","少许":"sedikit; secuil","跳脱":"lincah; lepas dari pakem",
 "头子":"bos; gembong","未知":"tak diketahui","心头":"dalam hati; benak",
 "新知":"pengetahuan baru; kenalan baru","眼皮":"kelopak mata","用以":"untuk; guna",
 "长老":"tetua; sesepuh","足足":"penuh; tepat sebanyak","雨水":"air hujan",
 # kebocoran Inggris
 "法治":"negara hukum; supremasi hukum",
}

# kumpulan calque yang dianggap "masih salah" -> hanya kartu ini yang diganti.
# (kartu yang artinya sudah benar tidak disentuh)
src = open("bootstrap_m.py", encoding="utf-8").read()
i = src.index("{", src.index("M = {")); depth = 0; j = i
for k in range(i, len(src)):
    if src[k] == "{": depth += 1
    elif src[k] == "}":
        depth -= 1
        if depth == 0: j = k; break
M = ast.literal_eval(src[i:j+1])
SINGLE = {k:v for k,v in M.items() if len(k)==1}

def is_calque(s, m):
    if len(s) >= 2 and all(ch in SINGLE for ch in s):
        cg = [SINGLE[ch] for ch in s]
        return m == " ".join(cg)
    return False

tone_fixed = 0; meaning_fixed = 0; eng_fixed = 0
files = sorted(glob.glob("hsk*.json") + glob.glob("tocfl_*.json"))
for f in files:
    d = json.load(open(f, encoding="utf-8"))
    changed = False
    for c in d.get("cards", []):
        # tone
        ft = first_tone(c.get("py") or "")
        if c.get("tone") != ft:
            c["tone"] = ft; tone_fixed += 1; changed = True
        # meaning
        s = c.get("s") or ""; m = (c.get("m") or "").strip()
        if s == "法治" and "rule of law" in m:
            c["m"] = CORR["法治"]; eng_fixed += 1; changed = True
        elif s in CORR and (is_calque(s, m) or m == CORR.get(s)):
            if c["m"] != CORR[s]:
                c["m"] = CORR[s]; meaning_fixed += 1; changed = True
    if changed:
        with io.open(f, "w", encoding="utf-8") as out:
            # tulis ulang: header field + cards satu objek per baris
            head = {k:v for k,v in d.items() if k != "cards"}
            out.write("{")
            parts = ['"%s":%s' % (k, json.dumps(v, ensure_ascii=False)) for k,v in head.items()]
            out.write(",".join(parts))
            out.write(',"cards":[\n')
            cards = d["cards"]
            for idx, c in enumerate(cards):
                out.write(json.dumps(c, ensure_ascii=False, separators=(",",":")))
                out.write(",\n" if idx < len(cards)-1 else "\n")
            out.write("]}\n")
print("tone_fixed   =", tone_fixed)
print("meaning_fixed=", meaning_fixed)
print("eng_fixed    =", eng_fixed)
