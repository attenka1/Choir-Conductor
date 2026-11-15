import json
from pathlib import Path
root=Path(__file__).resolve().parent.parent
app=root/'Choir Master'
source=json.loads((root/'Tools/localization_source.json').read_text())
pidgin=json.loads((root/'Tools/pidgin_translations.json').read_text())
missing=set(source.values())-set(pidgin)
assert not missing, missing
q=lambda s:json.dumps(s,ensure_ascii=False)
values={k:pidgin[v] for k,v in source.items()}
folder=app/'pcm.lproj';folder.mkdir(exist_ok=True)
if "Choir Master" not in values["Mikrofonin käyttölupa"]: values["Mikrofonin käyttölupa"] = "Choir Master: " + values["Mikrofonin käyttölupa"]
(folder/'Localizable.strings').write_text('\n'.join(f'{q(k)} = {q(v)};' for k,v in values.items())+'\n')
(folder/'InfoPlist.strings').write_text(f'"NSMicrophoneUsageDescription" = {q(values["Mikrofonin käyttölupa"])};\n\"CFBundleDisplayName\" = \"Choir Master\";\n')
# Apply curated terminology after machine translations. Keep overrides separate for future review.
import re
overrides=json.loads((root/'Tools/localization_overrides.json').read_text())
for code, changes in overrides.items():
 path=app/(code+'.lproj')/'Localizable.strings'
 strings=dict(re.findall(r'("(?:[^"\\]|\\.)*") = ("(?:[^"\\]|\\.)*");', path.read_text()))
 for key, value in changes.items():
  assert key in source, key
  strings[q(key)]=q(value)
 path.write_text('\n'.join(f'{k} = {v};' for k,v in strings.items())+'\n')
# Make dynamic volume labels unambiguous: this is sound level, not a book or folder.
for code,_ in json.loads((root/'Tools/languages.json').read_text()):
 if code in ('fi','ar-EG','wuu'): continue
 path=app/(code+'.lproj')/'Localizable.strings'
 pairs=re.findall(r'("(?:[^"\\]|\\.)*") = ("(?:[^"\\]|\\.)*");',path.read_text())
 values={json.loads(k):json.loads(v) for k,v in pairs}
 values['%@ äänenvoimakkuus']=values['Äänenvoimakkuudet']+': %@'
 path.write_text('\n'.join(f'{q(k)} = {q(v)};' for k,v in values.items())+'\n')
# Egyptian Arabic uses formal written Arabic, Wu uses standard written Chinese.
# These are explicit written-language choices, not invented colloquial translations.
for target,base in [('ar-EG','ar'),('wuu','zh-Hans')]:
 folder=app/(target+'.lproj');folder.mkdir(exist_ok=True)
 for filename in ['Localizable.strings','InfoPlist.strings']:
  (folder/filename).write_text((app/(base+'.lproj')/filename).read_text())
print('PASS: three additional written-language resources generated')
