import json, re, subprocess, sys
from pathlib import Path
root=Path(__file__).resolve().parents[2]
app=root/'Choir Master'
source=json.loads((root/'Tools/localization_source.json').read_text())
languages=json.loads((root/'Tools/languages.json').read_text())
assert len(languages)==31 and len(set(code for code,_ in languages))==31
for code,_ in languages:
    folder=app/(code+'.lproj')
    path=folder/'Localizable.strings'
    pairs=re.findall(r'("(?:[^"\\]|\\.)*") = ("(?:[^"\\]|\\.)*");',path.read_text())
    values={json.loads(k):json.loads(v) for k,v in pairs}
    assert len(pairs)==len(values)==len(source),(code,'duplicate or missing strings')
    assert set(values)==set(source),(code,'key coverage')
    for key,value in values.items():
        assert value.strip(),(code,key,'empty translation')
        assert value.count('%@')==source[key].count('%@'),(code,key,'placeholder mismatch')
        assert '9876543210' not in value and not re.search(r'__\d{3}__',value),(code,key,'translation marker')
    info=(folder/'InfoPlist.strings').read_text()
    assert 'NSMicrophoneUsageDescription' in info and len(info.encode('utf-8'))>65,(code,'missing permission text')
    for file in [path,folder/'InfoPlist.strings']:
        subprocess.run(['plutil','-lint',str(file)],check=True,stdout=subprocess.DEVNULL)
for path in app.glob('*.swift'):
    for key in re.findall(r'T\("([^"\\]*)"',path.read_text()):
        assert key in source,(path.name,key,'unknown localization key')
print(f'PASS: {len(languages)} languages × {len(source)} strings; valid Apple string files, complete key coverage and matching format placeholders')
if len(sys.argv)>1:
    bundle=Path(sys.argv[1])
    for code,_ in languages:
        for name in ['Localizable.strings','InfoPlist.strings']:
            assert (bundle/(code+'.lproj')/name).exists(),(code,name,'missing from built app')
    print('PASS: every language and microphone permission localization is present in the built iPhone app')

# Supplemental tables intentionally ship in Finnish and English; other languages
# use the English fallback. Validate their contents and literal call sites too.
for table, function in [('Tuner', 'tunerText'), ('Analysis', 'analysisText')]:
    translations = {}
    for code in ['fi', 'en']:
        path = app / (code + '.lproj') / (table + '.strings')
        pairs = re.findall(r'("(?:[^"\\]|\\.)*") = ("(?:[^"\\]|\\.)*");', path.read_text())
        values = {json.loads(k): json.loads(v) for k, v in pairs}
        assert len(pairs) == len(values), (code, table, 'duplicate keys')
        assert all(values.values()), (code, table, 'empty translation')
        subprocess.run(['plutil', '-lint', str(path)], check=True, stdout=subprocess.DEVNULL)
        translations[code] = values
    assert set(translations['fi']) == set(translations['en']), (table, 'key coverage')
    for key in translations['fi']:
        assert translations['fi'][key].count('%@') == translations['en'][key].count('%@'), (table, key, 'placeholder mismatch')
    for path in app.glob('*.swift'):
        for key in re.findall(function + r'\("([^"\\]*)"', path.read_text()):
            assert key in translations['en'], (path.name, table, key, 'unknown key')
print('PASS: Finnish/English tuner and analysis tables, format placeholders and literal call sites')
