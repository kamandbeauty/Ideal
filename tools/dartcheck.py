#!/usr/bin/env python3
"""Fast syntax check for every Dart file (tree-sitter, no Flutter SDK needed).

This is NOT `flutter analyze`: it only reports parse errors, which is enough to
catch an unbalanced brace or a botched edit in a second or two.
"""
import pathlib
import sys

from tree_sitter import Language, Parser
import tree_sitter_dart

SKIP = {'.git', '.dart_tool', 'build', '.gradle', 'node_modules'}
lang = Language(tree_sitter_dart.language())
parser = Parser(lang)


def main() -> int:
    root = pathlib.Path('.').resolve()
    files = [
        p for p in sorted(root.rglob('*.dart'))
        if not any(part in SKIP for part in p.parts)
    ]
    broken = 0
    for path in files:
        source = path.read_bytes()
        tree = parser.parse(source)
        if not tree.root_node.has_error:
            continue
        broken += 1
        print(f'ERROR {path.relative_to(root)}')
        stack = [tree.root_node]
        while stack:
            node = stack.pop()
            if node.type == 'ERROR' or node.is_missing:
                snippet = source[node.start_byte:node.end_byte][:80].decode('utf8', 'replace')
                print(f'   {node.type} at {node.start_point}: {snippet!r}')
            stack.extend(node.children)
    print(f'--- parsed {len(files)} files, {broken} with syntax errors ---')
    return 1 if broken else 0


if __name__ == '__main__':
    sys.exit(main())
