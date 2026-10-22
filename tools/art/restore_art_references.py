"""Restore original reference bytes to ignored PNG/, with SHA-256 verification.

Default mode is offline: reuse matching local files. --download explicitly
enables HTTPS for missing references. No AI, browser, editor or API is launched.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import urllib.request

from handoff_support import PACK, ROOT, configure_writes, normalize, project_path


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest().lower()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--download', action='store_true')
    args = parser.parse_args()
    work = configure_writes()
    records = normalize(json.loads((PACK / 'reference_sources.json').read_text(encoding='utf-8-sig')))
    local = {}
    for path in (ROOT / 'PNG').rglob('*'):
        if path.suffix.lower() in ('.png', '.jpg', '.jpeg') and path.is_file():
            local.setdefault(digest(path), path)
    results = []
    for record in records:
        target = project_path(record['file'])
        target.relative_to(ROOT / 'PNG/mcs_style_reference_20261019/originals')
        expected = record['sha256'].lower()
        item = {'file': record['file'], 'status': 'missing'}
        try:
            if target.is_file() and digest(target) == expected:
                item['status'] = 'verified'
            elif expected in local:
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(local[expected], target)
                item['status'] = 'copied_verified_local'
            elif args.download:
                url = record['image_url']
                if not url.startswith('https://'):
                    raise ValueError('Only HTTPS reference downloads are supported')
                request = urllib.request.Request(url, headers={'User-Agent': 'ArtReferenceRestore/1.0'})
                with urllib.request.urlopen(request, timeout=20) as response:
                    data = response.read(32 * 1024 * 1024 + 1)
                if len(data) > 32 * 1024 * 1024 or hashlib.sha256(data).hexdigest() != expected:
                    raise ValueError('Reference changed or exceeded size limit; original not replaced')
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(data)
                item['status'] = 'downloaded_verified'
        except Exception as error:
            item.update(status='unavailable', error=str(error))
        results.append(item)
        print(item['status'], target.name, flush=True)
    report = project_path(work / 'reference_restore.json')
    report.write_text(json.dumps(results, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    missing = [item for item in results if item['status'] in ('missing', 'unavailable')]
    print(f'REFERENCES {len(results) - len(missing)}/{len(results)}; report: {report.relative_to(ROOT).as_posix()}')
    return 1 if missing else 0


if __name__ == '__main__':
    raise SystemExit(main())
