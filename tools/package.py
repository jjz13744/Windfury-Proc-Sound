#!/usr/bin/env python3
"""Validate the install layout and build a deterministic, addon-only ZIP."""
from pathlib import Path
import hashlib
import re
import json
import zipfile
root = Path(__file__).resolve().parents[1]
addon = root / 'WindfuryProcSound'
for toc in addon.glob('*.toc'):
    lines = toc.read_text().splitlines()
    assert '## Interface: 16001' in lines
    for line in lines:
        if line and not line.startswith('#'):
            assert (addon / line).is_file(), f'Missing {line}'
audio = list((addon / 'sounds').glob('*.ogg'))
assert len(audio) == 20, f'Expected 20 custom originals, got {len(audio)}'
for file in audio:
    assert file.read_bytes().startswith(b'OggS'), file
assert len(re.findall(r'id\s*=', (addon / 'Sounds.lua').read_text())) == 21
assert (addon / 'SOUND_CREDITS.md').is_file()
manifest = json.loads((addon / 'volume_manifest.json').read_text())
assert manifest['summary']['passed'] and len(manifest['originals']) == 20 and len(manifest['variants']) == 180
expected_audio = set()
for entry in manifest['originals'] + manifest['variants']:
    path = addon / entry['path']
    expected_audio.add(path)
    assert path.is_file() and hashlib.sha256(path.read_bytes()).hexdigest() == entry['sha256'], path
assert set((addon / 'sounds').rglob('*.ogg')) == expected_audio
catalog = json.loads((addon / 'sound-catalog.json').read_text())
assert len(catalog) == 21
assert sum('file' in item for item in catalog) == 20
assert sum(item.get('kind') == 'native_sound_kit' for item in catalog) == 1
assert 'wolf_howl.ogg' not in (addon / 'Sounds.lua').read_text()
for name in ['README.md', 'LICENSE']:
    (addon / name).write_bytes((root / name).read_bytes())
version = re.search(r'^## Version: ([0-9.]+)$', (addon / 'WindfuryProcSound.toc').read_text(), re.M).group(1)
for toc in addon.glob('*.toc'):
    assert f'## Version: {version}' in toc.read_text().splitlines()
out = root / 'dist' / f'WindfuryProcSound-{version}.zip' 
out.parent.mkdir(exist_ok=True)
with zipfile.ZipFile(out, 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
    for file in sorted(addon.rglob('*')):
        if file.is_file():
            info = zipfile.ZipInfo(file.relative_to(root).as_posix(), (2026, 11, 15, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o644 << 16
            archive.writestr(info, file.read_bytes())
with zipfile.ZipFile(out) as archive:
    assert archive.testzip() is None
print(out)
print(f'{out.stat().st_size} bytes')
print('SHA256 ' + hashlib.sha256(out.read_bytes()).hexdigest())
