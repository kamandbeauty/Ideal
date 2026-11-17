"""Heuristic project-symbol checker (stand-in for `flutter analyze`).

For every Dart file it resolves the project-relative imports/exports and then
reports identifiers that are declared somewhere in the project but are neither
declared in the file nor reachable through its imports. That is exactly the
class of error that keeps biting (JobScheduler / jobsProvider / …).
It also reports project imports whose symbols are never used.
"""
import pathlib, re, sys
from tree_sitter import Language, Parser
import tree_sitter_dart

lang = Language(tree_sitter_dart.language())
parser = Parser(lang)

ROOT = pathlib.Path('.').resolve()
SKIP = {'.git', '.dart_tool', 'build', '.gradle'}

def iter_dart():
    for p in sorted(ROOT.rglob('*.dart')):
        if any(part in SKIP for part in p.parts):
            continue
        yield p

def node_text(src, node):
    return src[node.start_byte:node.end_byte].decode('utf8', 'replace')

NAMED_DECLS = {
    'class_definition', 'mixin_declaration', 'enum_declaration',
    'extension_declaration', 'function_declaration', 'mixin_definition',
    'extension_definition', 'extension_type_declaration',
    'function_signature', 'getter_signature', 'setter_signature',
}

DART_CORE = {
    'DateTime', 'Duration', 'String', 'int', 'double', 'num', 'bool', 'List',
    'Map', 'Set', 'Iterable', 'Future', 'Stream', 'Object', 'Never', 'Null',
    'Function', 'Type', 'Symbol', 'RegExp', 'Match', 'Exception', 'Error',
    'Uri', 'BigInt', 'Comparable', 'Enum', 'Record', 'Stopwatch', 'DateTime',
    'IconData', 'Widget', 'BuildContext', 'Color', 'Size', 'Offset', 'Rect',
    'TextStyle', 'TextEditingController', 'Key', 'ValueKey', 'State', 'Widget',
}

# Names whose declaration lives in a Flutter/SDK package: the import graph of
# this project cannot be expected to provide them.
FLUTTER_NAMES = {
    'IconData', 'Widget', 'BuildContext', 'Color', 'Size', 'Offset', 'Rect',
    'TextStyle', 'TextEditingController', 'Key', 'ValueKey', 'State',
}

class FileInfo:
    def __init__(self, path, src, tree):
        self.path = path
        self.src = src
        self.tree = tree
        self.imports = []   # (uri, is_project, resolved Path)
        self.exports = []
        self.declared = set()
        self.used = set()
        self.package_imports = []

def analyze(path):
    src = path.read_bytes()
    tree = parser.parse(src)
    info = FileInfo(path, src, tree)
    for child in tree.root_node.children:
        t = child.type
        if t == 'import_or_export' or t in ('import_specification', 'library_import', 'library_export'):
            pass
    # tree-sitter-dart: top-level nodes are `import_or_export`? Inspect generically.
    def walk(node, depth=0):
        if node.type in ('import_specification', 'library_import', 'import_directive', 'import_or_export'):
            pass
        for c in node.children:
            walk(c, depth+1)
    # Generic: find every string literal following 'import ' or 'export '
    text = src.decode('utf8', 'replace')
    for m in re.finditer(r"^\s*(import|export)\s+'([^']+)'", text, re.M):
        kind, uri = m.group(1), m.group(2)
        resolved = None
        if uri.startswith('package:javid_ai/'):
            is_proj = True
            resolved = (ROOT / 'lib' / uri[len('package:javid_ai/'):]).resolve()
        elif uri.startswith('dart:') or uri.startswith('package:'):
            is_proj = False
        else:
            # Relative imports are written without a leading './' in this repo.
            is_proj = True
            resolved = (path.parent / uri).resolve()
        target = info.imports if kind == 'import' else info.exports
        target.append((uri, is_proj, resolved))
        if not is_proj:
            info.package_imports.append(uri)
    # Names introduced by a declaration node, top-level or not. Nested names
    # only shadow; for import resolution this is close enough and avoids the
    # tree-sitter-dart quirk where the first import swallows the next node.
    def decls(node):
        if node.type in ('function_signature', 'getter_signature', 'setter_signature'):
            # the declared name is the identifier right before the parameter list
            children = list(node.named_children)
            for i, c in enumerate(children):
                nxt = children[i + 1].type if i + 1 < len(children) else ''
                if c.type == 'identifier' and nxt in ('formal_parameter_list', ''):
                    info.declared.add(node_text(src, c))
                    break
        elif node.type in NAMED_DECLS:
            for c in node.named_children:
                if c.type in ('identifier', 'type_identifier'):
                    info.declared.add(node_text(src, c))
                    break
        elif node.type == 'variable_declaration':
            # Only a *top-level* var introduces a file symbol; locals are noise.
            pass
        elif node.type == 'initialized_variable_definition':
            pass
        for c in node.children:
            decls(c)

    decls(tree.root_node)

    def collect(node):
        if node.type in ('identifier', 'type_identifier'):
            info.used.add(node_text(src, node))
        for c in node.children:
            collect(c)

    collect(tree.root_node)
    return info

infos = {p.resolve(): analyze(p) for p in iter_dart()}

# name -> files declaring it
owner = {}
for path, info in infos.items():
    for name in info.declared:
        owner.setdefault(name, set()).add(path)

def reachable(info, seen=None):
    """Names reachable through this file's imports (transitively via exports)."""
    seen = seen or set()
    names = set(info.declared)
    for uri, is_proj, resolved in info.imports:
        if not is_proj:
            continue
        if resolved in seen or resolved not in infos:
            continue
        seen.add(resolved)
        names |= reachable(infos[resolved], seen)
    return names

problems = 0
for path, info in sorted(infos.items()):
    avail = reachable(info)
    for name in sorted(info.used - avail):
        owners = owner.get(name)
        if not owners:
            continue
        # lowercase identifiers are fields/locals/named args far more often than
        # they are top-level symbols; a type-style name is unambiguous.
        if name == 'main':
            continue
        is_func = any(
            any(child.type == 'identifier' and node_text(infos[p].src, child) == name
                for child in node.named_children)
            for p in owners
            for node in infos[p].tree.root_node.children
            if node.type in ('function_signature', 'getter_signature')
        )
        if not name[:1].isupper() and not is_func:
            continue
        # dart:core types are implicitly available in every file.
        if name in DART_CORE:
            continue
        rel = path.relative_to(ROOT)
        where = ', '.join(str(p.relative_to(ROOT)) for p in owners)
        print(f'UNDEFINED {rel}: {name} is declared in {where} but not imported')
        problems += 1
    for uri, is_proj, resolved in info.imports:
        if not is_proj or resolved not in infos:
            continue
        exported = infos[resolved].declared - info.declared
        if not exported:
            continue
        # names this file could only have obtained from that import
        others = set()
        for uri2, proj2, res2 in info.imports:
            if not proj2 or res2 == resolved or res2 not in infos:
                continue
            others |= reachable(infos[res2])
        exclusive = exported - others
        hits = info.used & exclusive
        if exclusive and not hits:
            print(f'UNUSED-IMPORT {path.relative_to(ROOT)}: {uri}')
            problems += 1
print(f'--- {len(infos)} files, {problems} problem(s) ---')
