"""Shared path and actor-layout rules for the art handoff tools. Run with -B."""
from __future__ import annotations

import copy
import os
from pathlib import Path
import re
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[2]
PACK = ROOT / 'art_sources/refresh_20261019'
REFERENCE_DIR = 'PNG/mcs_style_reference_20261019/originals/'
WRITE_PATHS = set()
_audit_installed = False


def project_path(value):
    """Reject writes outside this D-drive checkout, including junction escapes."""
    if ROOT.drive.upper() != 'D:':
        raise ValueError('Art handoff writes require a checkout on D:')
    path = Path(value)
    path = (path if path.is_absolute() else ROOT / path).resolve()
    path.relative_to(ROOT)
    return path


def relative_path(value):
    return project_path(value).relative_to(ROOT).as_posix()


def configure_writes():
    """Guard Python filesystem mutations as well as the explicit output paths."""
    global _audit_installed
    if not sys.dont_write_bytecode:
        raise SystemExit('Run with python -B to avoid bytecode cache writes.')
    if not _audit_installed:
        def audit(event, args):
            targets = []
            if event == 'open':
                path, mode, flags = args
                if isinstance(path, (str, bytes, os.PathLike)) and (
                    (mode and any(char in mode for char in 'wax+')) or
                    flags & (os.O_WRONLY | os.O_RDWR | os.O_CREAT | os.O_TRUNC | os.O_APPEND)
                ):
                    targets = [path]
            elif event in ('os.mkdir', 'os.remove', 'os.rmdir', 'os.chmod', 'os.utime'):
                targets = [args[0]]
            elif event in ('os.rename', 'os.replace', 'os.link', 'os.symlink'):
                targets = [args[0], args[1]]
            for target in targets:
                WRITE_PATHS.add(relative_path(os.fsdecode(target)))
        sys.addaudithook(audit)
        _audit_installed = True
    work = project_path('.tmp/art_handoff_repair')
    work.mkdir(parents=True, exist_ok=True)
    os.environ['TEMP'] = os.environ['TMP'] = str(work)
    tempfile.tempdir = str(work)
    return work


def normalize_string(value):
    value = value.replace('D:/fqh/flash/', '').replace('D:\\\\fqh\\\\flash\\\\', '')
    value = value.replace('D:\\fqh\\flash\\', '').replace(ROOT.as_posix() + '/', '')
    if value.startswith(('.tmp\\', 'art_sources\\', 'PNG\\', 'assets\\')):
        value = re.sub(r'\\+', '/', value)
    value = value.replace('.tmp/mcs_style_reference_20261019/originals/', REFERENCE_DIR)
    # Confirmed samples ship with the handoff; transient generation caches do not.
    value = value.replace('.tmp/style_samples_20261019/new/',
                          'art_sources/refresh_20261019/approved_samples/')
    value = value.replace('.tmp/imagegen/hero_style_c.png',
                          'art_sources/refresh_20261019/approved_samples/01_hero.png')
    value = value.replace('.tmp/imagegen/shen_mo_style_c_flat.png',
                          'art_sources/refresh_20261019/approved_samples/02_portrait.png')
    return value


def normalize(value):
    if isinstance(value, str):
        return normalize_string(value)
    if isinstance(value, list):
        return [normalize(item) for item in value]
    if isinstance(value, dict):
        return {key: normalize(item) for key, item in value.items()}
    return value


def markdown_paths(value, destination):
    """Markdown links are relative to their document; manifest paths to ROOT."""
    def replace(match):
        target = normalize_string(match.group(1))
        if target.startswith(('https://', 'http://', '#')):
            return match.group(0)
        if not target.startswith(('art_sources/', 'docs/', 'PNG/', '.tmp/')):
            return match.group(0)
        return '](' + Path(os.path.relpath(ROOT / target, destination.parent)).as_posix() + ')'
    return re.sub(r'\]\(([^)]+)\)', replace, value)


def actor_sources(art):
    result = {}
    for actor_id, definition in art['actors'].items():
        for key in ('texture', 'preferred'):
            path = definition.get(key, '').removeprefix('res://')
            if path:
                result.setdefault(path, []).append({
                    'actor_id': actor_id, 'source_role': key, 'definition': copy.deepcopy(definition)})
        # battle_stage.gd formats `look` with foe.sect and foe.gender.
        template = definition.get('look', '').removeprefix('res://')
        if template:
            pattern = re.compile(re.escape(template).replace('%s', r'[^/]+'))
            for image in sorted((ROOT / 'assets/art/actors').glob('*.png')):
                path = image.relative_to(ROOT).as_posix()
                if pattern.fullmatch(path):
                    selected = copy.deepcopy(definition)
                    selected['texture'] = 'res://' + path
                    selected.pop('preferred_layout', None)
                    result.setdefault(path, []).append({
                        'actor_id': actor_id, 'source_role': 'look', 'definition': selected})
    return result
