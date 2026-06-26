import json, sys, os
sys.stdout.reconfigure(encoding='utf-8')

packs_dir = r'D:\CLAUDE\ZHONG-WEN-SHU-2\app\assets\packs'
files = sorted(f for f in os.listdir(packs_dir) if f.endswith('.json') and f != 'manifest.json' and not f.startswith('SCHEMA'))

print("AUDIT STATUS FIELD `m` DI SEMUA FILE")
print("="*70)

for fname in files:
    path = os.path.join(packs_dir, fname)
    with open(path, 'r', encoding='utf-8') as f:
        data = json.load(f)
    cards = data.get('cards', [])
    standard = data.get('standard', '?')
    
    empty_m = sum(1 for c in cards if not c.get('m', '').strip())
    has_m = len(cards) - empty_m
    
    # Sample empty m values
    empty_samples = [c for c in cards if not c.get('m', '').strip()][:3]
    # Sample filled m values
    filled_samples = [c for c in cards if c.get('m', '').strip()][:3]
    
    print(f"\n{fname}: {len(cards)} cards [{standard}]")
    print(f"  `m` kosong: {empty_m}  |  `m` terisi: {has_m}")
    if empty_samples:
        for c in empty_samples:
            print(f"  KOSONG contoh: {c['s']} ({c['py']})")
    if filled_samples:
        for c in filled_samples:
            print(f"  ISI contoh: {c['s']} = \"{c['m']}\"")
