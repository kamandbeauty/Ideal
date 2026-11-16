#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
بازسازی محیط ساخت PDF — بعد از هر clone تازه اجرا کن:

    python3 pipeline/bootstrap.py

کارها:
  1) ساخت .venv (اگر نباشد)
  2) نصب وابستگی‌ها از requirements.txt
  3) نصب شیم محلیِ rlbidi (ReportLab روی PyPI منتشر نشده)
"""
import os
import shutil
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
VENV = os.path.join(ROOT, '.venv')
BIN = 'bin' if os.name != 'nt' else 'Scripts'
VENV_PY = os.path.join(VENV, BIN, 'python.exe' if os.name == 'nt' else 'python')
VENV_PIP = os.path.join(VENV, BIN, 'pip.exe' if os.name == 'nt' else 'pip')


def run(cmd):
    print('$', ' '.join(cmd))
    subprocess.check_call(cmd)


def main():
    if not os.path.exists(VENV_PY):
        run([sys.executable, '-m', 'venv', VENV])
    run([VENV_PIP, 'install', '--quiet', '--upgrade', 'pip'])
    run([VENV_PIP, 'install', '--quiet', '-r', os.path.join(ROOT, 'requirements.txt')])

    site_packages = subprocess.check_output(
        [VENV_PY, '-c', 'import sysconfig; print(sysconfig.get_paths()["purelib"])'],
        text=True).strip()
    src = os.path.join(ROOT, 'pipeline', 'vendor', 'rlbidi.py')
    dst = os.path.join(site_packages, 'rlbidi.py')
    shutil.copyfile(src, dst)
    print('✔ rlbidi shim ->', dst)
    print('✔ محیط آماده است. ساخت نمونه:')
    print('  .venv/bin/python pipeline/build.py examples/sample.md output/sample-template-fa.pdf --toc')


if __name__ == '__main__':
    main()
