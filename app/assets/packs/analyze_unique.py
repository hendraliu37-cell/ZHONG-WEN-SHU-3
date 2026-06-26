import json, sys, os
sys.stdout.reconfigure(encoding='utf-8')

packs_dir = r'D:\CLAUDE\ZHONG-WEN-SHU-2\app\assets\packs'
files = sorted(f for f in os.listdir(packs_dir) if f.endswith('.json') and f != 'manifest.json' and not f.startswith('SCHEMA'))

all_words = {}  # word -> list of (file, pinyin)
by_len = {}     # for analysis

for fname in files:
    path = os.path.join(packs_dir, fname)
    with open(path, 'r', encoding='utf-8') as f:
        data = json.load(f)
    cards = data.get('cards', [])
    for c in cards:
        w = c['s']
        if w not in all_words:
            all_words[w] = []
        all_words[w].append((fname, c.get('py','')))
        l = len(w)
        by_len[l] = by_len.get(l, 0) + 1

print(f"Total kartu: 22,692")
print(f"Kata unik: {len(all_words)}")
print()

# Distribution by character length
for l in sorted(by_len.keys()):
    print(f"  {l} karakter: {by_len[l]} kemunculan")

# Show first 100 unique words sorted
print("\n--- 100 KATA UNIK PERTAMA (sorted) ---")
count = 0
for w in sorted(all_words.keys()):
    first_file, first_py = all_words[w][0]
    total_occur = len(all_words[w])
    print(f"{w}\t{first_py}\tmuncul di {total_occur} file\tcontoh: {first_file}")
    count += 1
    if count >= 100:
        break

print(f"\n... dan {len(all_words) - 100} kata unik lainnya")

# Save all unique words to a file for reference
with open(os.path.join(packs_dir, 'unique_words.txt'), 'w', encoding='utf-8') as f:
    for w in sorted(all_words.keys()):
        first_py = all_words[w][0][1]
        f.write(f"{w}\t{first_py}\n")
print(f"\nUnique words saved to unique_words.txt")
