"""Verify local resources and configuration; does not compile or validate gameplay."""
import json
import plistlib
import wave
from pathlib import Path
import yaml
from PIL import Image

root = Path(__file__).resolve().parents[1]
project = yaml.safe_load((root / 'project.yml').read_text())
assert project['targets']['LastLine']['supportedDestinations'] == ['iOS', 'macOS']
for item in project['targets']['LastLine']['sources']:
    assert (root / item['path']).exists(), item['path']
resources = root / 'App/Resources'
with (resources / 'PrivacyInfo.xcprivacy').open('rb') as handle:
    privacy = plistlib.load(handle)
assert privacy['NSPrivacyTracking'] is False
assert privacy['NSPrivacyAccessedAPITypes'][0]['NSPrivacyAccessedAPITypeReasons'] == ['CA92.1']
with (root / 'App/EnemyLine.entitlements').open('rb') as handle:
    assert plistlib.load(handle)['com.apple.security.app-sandbox'] is True
for event in ['shot', 'damage', 'explosion', 'success']:
    with wave.open(str(resources / f'{event}.wav')) as audio:
        assert audio.getnchannels() == 1
        assert audio.getnframes() > 0
icons = resources / 'Assets.xcassets/AppIcon.appiconset'
for icon in json.loads((icons / 'Contents.json').read_text())['images']:
    size = int(icon['size'].split('x')[0]) * int(icon.get('scale', '1x')[0])
    with Image.open(icons / icon['filename']) as image:
        assert image.size == (size, size), icon
        assert image.mode == 'RGB', 'Icons must be opaque RGB'
yaml.safe_load((root / '.github/workflows/apple.yml').read_text())
print('Packaging checks passed: project paths, privacy, entitlements, 4 audio files, 11 icons, workflow YAML.')
