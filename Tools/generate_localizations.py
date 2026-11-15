"""Development-only generation. Sends only public, generic English UI phrases.
No app runtime networking. Existing translations are cached. Put terminology edits in
localization_overrides.json and always run finish_localizations.py after this script.
Translations need native-speaker review, especially music terminology.
"""
import json, re, time, urllib.request, urllib.parse
from pathlib import Path
root = Path(__file__).resolve().parent.parent
source = json.loads((root / 'Tools/localization_source.json').read_text())
app = root / 'Choir Master'
languages = [
 ('fi','Suomi'), ('en','English'), ('zh-Hans','中文（普通话）'), ('hi','हिन्दी'),
 ('es','Español'), ('ar','العربية'), ('fr','Français'), ('bn','বাংলা'),
 ('pt','Português'), ('id','Bahasa Indonesia'), ('ur','اردو'), ('ru','Русский'),
 ('de','Deutsch'), ('ja','日本語'), ('pcm','Naijá'), ('ar-EG','العربية المصرية'),
 ('mr','मराठी'), ('vi','Tiếng Việt'), ('te','తెలుగు'), ('sw','Kiswahili'),
 ('ha','Hausa'), ('tr','Türkçe'), ('pa-Arab','پنجابی'), ('tl','Tagalog'),
 ('ta','தமிழ்'), ('yue','粵語'), ('wuu','吴语（书面中文）'), ('fa','فارسی'),
 ('ko','한국어'), ('am','አማርኛ'), ('th','ไทย')]
(root/'Tools/languages.json').write_text(json.dumps(languages,ensure_ascii=False,indent=2))
cache = root/'Tools/translation_cache'; cache.mkdir(exist_ok=True)
keys = list(source)

def translate(code):
    path=cache/(code+'.json')
    existing=json.loads(path.read_text()) if path.exists() else {}
    if set(existing)==set(keys): return existing
    chunks=[]; batch=[]; size=0
    for i,key in enumerate(keys):
        if key in existing: continue
        text=source[key].replace('%@','9876543210')
        line=f'__{i:03}__ {text}'
        if size+len(line)>2400 and batch: chunks.append(batch);batch=[];size=0
        batch.append(line);size+=len(line)+1
    if batch: chunks.append(batch)
    result=dict(existing)
    for batch in chunks:
        query='\n'.join(batch)
        url='https://translate.googleapis.com/translate_a/single?'+urllib.parse.urlencode({'client':'gtx','sl':'en','tl':code,'dt':'t','q':query})
        for attempt in range(3):
            try:
                data=json.load(urllib.request.urlopen(url,timeout=25))
                translated=''.join(part[0] for part in data[0] if part[0]);break
            except Exception:
                if attempt==2: raise
                time.sleep(2)
        entries=list(re.finditer(r'^\s*(?:_\s*)*(\d{1,3})\s*(?:_\s*)+', translated,re.MULTILINE))
        if len(entries)!=len(batch): raise RuntimeError(f'{code}: lost markers {len(entries)}/{len(batch)}: {translated}')
        for j,match in enumerate(entries):
            end=entries[j+1].start() if j+1<len(entries) else len(translated)
            value=translated[match.end():end].strip().replace('9876543210','%@')
            key=keys[int(match.group(1))]
            if not value.strip(): raise RuntimeError(f'{code}: empty translation {key}')
            if value.count('%@')!=source[key].count('%@'): raise RuntimeError(f'{code}: placeholder mismatch {key}: {value}')
            result[key]=value
        time.sleep(.25)
    if set(result)!=set(keys): raise RuntimeError(code+': key mismatch')
    path.write_text(json.dumps(result,ensure_ascii=False,indent=2))
    return result

def quote(s): return json.dumps(s,ensure_ascii=False)
for code,name in languages:
    if code=='fi': values={k:k for k in keys};values['Mikrofonin käyttölupa']='Choir Master käyttää mikrofonia harjoitusten äänittämiseen tällä laitteella.'
    elif code=='en': values=source
    elif code in ('pcm','ar-EG','wuu'): continue # curated / shared written form generated after base languages
    else: values=translate('zh-CN' if code=='zh-Hans' else code)
    folder=app/(code+'.lproj');folder.mkdir(exist_ok=True)
    if "Choir Master" not in values["Mikrofonin käyttölupa"]: values["Mikrofonin käyttölupa"] = "Choir Master: " + values["Mikrofonin käyttölupa"]
    (folder/'Localizable.strings').write_text('\n'.join(f'{quote(k)} = {quote(v)};' for k,v in values.items())+'\n')
    (folder/'InfoPlist.strings').write_text(f'"NSMicrophoneUsageDescription" = {quote(values["Mikrofonin käyttölupa"])};\n\"CFBundleDisplayName\" = \"Choir Master\";\n')
    print(code, len(values), flush=True)
