"""خواندنِ خط‌های روایت از content/script.fa.js (بدون وابستگی به node)."""
import ast
import re
from pathlib import Path

_PROJECT = Path(__file__).resolve().parent.parent


def lines():
    src = (_PROJECT / 'content' / 'script.fa.js').read_text()
    body = re.search(r'export const SCRIPT_FA\s*=\s*(\[[\s\S]*?\n\])', src).group(1)
    body = re.sub(r'//[^\n]*', '', body)
    return ast.literal_eval(body)
