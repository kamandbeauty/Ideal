import sys, pathlib
from tree_sitter import Language, Parser
import tree_sitter_dart

lang = Language(tree_sitter_dart.language())
parser = Parser(lang)

bad = 0
files = 0
for path in sorted(pathlib.Path('.').rglob('*.dart')):
    if any(part in {'.dart_tool', 'build', '.git'} for part in path.parts):
        continue
    files += 1
    src = path.read_bytes()
    tree = parser.parse(src)
    if tree.root_node.has_error:
        bad += 1
        print(f'ERROR {path}')
        def walk(node, depth=0):
            if node.type == 'ERROR' or node.is_missing:
                print('   ', node.type, node.start_point, repr(src[node.start_byte:node.end_byte][:80]))
            for child in node.children:
                walk(child, depth+1)
        walk(tree.root_node)
print(f'--- parsed {files} files, {bad} with syntax errors ---')
sys.exit(1 if bad else 0)
