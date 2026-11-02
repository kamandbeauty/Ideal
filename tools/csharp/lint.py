#!/usr/bin/env python3
"""C# lint that does not need Unity or the .NET SDK.

Two questions, asked of every file in client/Assets:

1. Does it parse? (tree-sitter C# grammar — catches the mistakes that only a compiler would
   otherwise catch: a missing brace, a mangled generic, a bad lambda.)
2. Does every `Type.Member` access point at a member that `Type` actually declares? This is a
   shallow check: it covers static access and nested types, not instance members, overrides or
   extension methods. It is enough to catch the typo that a rename leaves behind, and it is
   honest about what it does not cover.

3. Is every Unity/TMP/UI type the file names actually in scope? A C# compiler asks this question and
   answers it with `CS0246`; a human reading a diff never does, because `NamedBuildTarget` looks
   exactly like something that ought to work. This check caught one real `CS0246` in `CiBuild.cs`
   the first time it ran, which is why it is a gate and not an anecdote.

Both checks run identically here and in CI, which is the point: C# that has never been compiled is
still C# that can be read carefully.

Usage:
    python3 tools/csharp/lint.py            # lint client/Assets
    python3 tools/csharp/lint.py path...
Exit code 0 = clean, 1 = problems (printed to stderr).
"""
from __future__ import annotations

import collections
import sys
from pathlib import Path
from typing import Set

try:
    import tree_sitter_c_sharp
    from tree_sitter import Language, Parser
except ImportError:  # pragma: no cover - CI installs this
    print(
        "lint: tree-sitter is missing.\n"
        "      pip install tree-sitter tree-sitter-c-sharp",
        file=sys.stderr,
    )
    raise SystemExit(2)

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_ROOT = ROOT / "client" / "Assets"

# Types that come from a `using` and not from the repo. Missing one of these is CS0246 at compile
# time; nothing else in this file can see it, because the syntax is perfect and the member access is
# on a type that does exist somewhere. Curated rather than exhaustive: every entry earned its place by
# being a name that reads as if it were in scope when it is not.
NEEDS_USING = {
    "NamedBuildTarget": "UnityEditor.Build",
    "BuildTargetGroup": "UnityEditor",
    "BuildTarget": "UnityEditor",
    "EditorUserBuildSettings": "UnityEditor",
    "EditorBuildSettings": "UnityEditor",
    "EditorBuildSettingsScene": "UnityEditor",
    "PlayerSettings": "UnityEditor",
    "AssetDatabase": "UnityEditor",
    "EditorUtility": "UnityEditor",
    "EditorApplication": "UnityEditor",
    "SceneAsset": "UnityEditor",
    "MenuItem": "UnityEditor",
    "AssetPostprocessor": "UnityEditor",
    "TextureImporter": "UnityEditor",
    "BuildPipeline": "UnityEditor",
    "BuildPlayerOptions": "UnityEditor",
    "BuildOptions": "UnityEditor",
    "BuildReport": "UnityEditor.Build.Reporting",
    "BuildResult": "UnityEditor.Build.Reporting",
    "EditorSceneManager": "UnityEditor.SceneManagement",
    "NewSceneSetup": "UnityEditor.SceneManagement",
    "NewSceneMode": "UnityEditor.SceneManagement",
    "TMP_FontAsset": "TMPro",
    "TMP_Text": "TMPro",
    "TextMeshProUGUI": "TMPro",
    "TextAlignmentOptions": "TMPro",
    "AtlasPopulationMode": "TMPro",
    "GlyphRenderMode": "UnityEngine.TextCore.LowLevel",
    "Image": "UnityEngine.UI",
    "Button": "UnityEngine.UI",
    "EventSystem": "UnityEngine.EventSystems",
    "StandaloneInputModule": "UnityEngine.EventSystems",
    "IPointerClickHandler": "UnityEngine.EventSystems",
}

# Members every value has, so a name that collides with a class called `Type` is never a mistake.
OBJECT_MEMBERS = {
    "GetType", "ToString", "Equals", "GetHashCode", "MemberwiseClone", "ReferenceEquals",
}

TYPE_NODES = {
    "class_declaration",
    "struct_declaration",
    "interface_declaration",
    "enum_declaration",
    "record_declaration",
}


def rel(path: Path) -> str:
    """Path as the reader cares about it: repo-relative when inside the repo, absolute otherwise."""
    try:
        return str(path.resolve().relative_to(ROOT))
    except ValueError:
        return str(path)


def decode(source: bytes, node) -> str:
    return source[node.start_byte:node.end_byte].decode("utf-8", "replace")


def collect_members(source: bytes, node, members: dict[str, set[str]]) -> str | None:
    """Records one type's declared members and returns its name (nested types included)."""
    name_node = node.child_by_field_name("name")
    if name_node is None:
        return None

    type_name = decode(source, name_node)
    members.setdefault(type_name, set())

    body = node.child_by_field_name("body")
    if body is None:
        return type_name

    for member in body.children:
        kind = member.type

        if kind in (
            "method_declaration",
            "property_declaration",
            "constructor_declaration",
            "indexer_declaration",
            "operator_declaration",
            "conversion_operator_declaration",
            "delegate_declaration",
        ):
            member_name = member.child_by_field_name("name")
            if member_name is not None:
                members[type_name].add(decode(source, member_name))

        elif kind == "field_declaration":
            for child in member.children:
                if child.type != "variable_declaration":
                    continue
                for declarator in child.children:
                    if declarator.type != "variable_declarator":
                        continue
                    identifier = declarator.child_by_field_name("name")
                    if identifier is None:
                        identifier = next(
                            (c for c in declarator.children if c.type == "identifier"), None
                        )
                    if identifier is not None:
                        members[type_name].add(decode(source, identifier))

        elif kind == "event_field_declaration":
            for child in member.children:
                if child.type == "variable_declaration":
                    for declarator in child.children:
                        identifier = declarator.child_by_field_name("name")
                        if identifier is not None:
                            members[type_name].add(decode(source, identifier))

        elif kind == "enum_member_declaration":
            for child in member.children:
                if child.type == "identifier":
                    members[type_name].add(decode(source, child))
                    break

        elif kind in TYPE_NODES:
            nested = collect_members(source, member, members)
            if nested:
                members[type_name].add(nested)

    return type_name


def walk(node):
    stack = [node]
    while stack:
        current = stack.pop()
        yield current
        stack.extend(current.children)


def namespace_errors(path: Path, source: bytes, tree) -> list[str]:
    """CS0246, the one compile error that reads as valid code."""
    imported: Set[str] = set()
    for node in walk(tree.root_node):
        if node.type == "using_directive":
            text = " ".join(decode(source, node).split())
            imported.add(text[len("using "):].rstrip(";").strip())

    errors: list[str] = []
    for node in walk(tree.root_node):
        if node.type != "identifier":
            continue

        name = decode(source, node)
        namespace = NEEDS_USING.get(name)
        if namespace is None or namespace in imported:
            continue

        # `UiKit.Button(...)` is a member access and `UnityEngine.UI.Image` is a qualified name;
        # in both the last identifier is a part of a path, not a bare use of the type.
        parent = node.parent
        if parent is not None and parent.type in ("member_access_expression", "qualified_name"):
            named = parent.child_by_field_name("name")
            if named is not None and named.id == node.id:
                continue

        line = node.start_point[0] + 1
        errors.append(f"{rel(path)}:{line}: `{name}` is used without `using {namespace};`")

    return errors


def main(argv: list[str]) -> int:
    targets = [Path(a) for a in argv] or [DEFAULT_ROOT]
    files: list[Path] = []
    for target in targets:
        if target.is_file() and target.suffix == ".cs":
            files.append(target)
        elif target.is_dir():
            files.extend(sorted(target.rglob("*.cs")))

    if not files:
        print(f"lint: no C# files under {', '.join(str(t) for t in targets)}", file=sys.stderr)
        return 1

    parser = Parser(Language(tree_sitter_c_sharp.language()))
    sources = {f: f.read_bytes() for f in files}
    trees = {f: parser.parse(sources[f]) for f in files}

    syntax_errors: list[str] = []
    for path in files:
        for node in walk(trees[path].root_node):
            if node.type == "ERROR" or node.is_missing:
                line = node.start_point[0] + 1
                snippet = " ".join(decode(sources[path], node).split())[:70]
                syntax_errors.append(f"{rel(path)}:{line}: {node.type} `{snippet}`")

    members: dict[str, set[str]] = {}
    for path in files:
        for node in walk(trees[path].root_node):
            if node.type in TYPE_NODES:
                collect_members(sources[path], node, members)

    member_errors: list[str] = []
    for path in files:
        source = sources[path]
        for node in walk(trees[path].root_node):
            if node.type != "member_access_expression":
                continue
            target = node.child_by_field_name("expression")
            name = node.child_by_field_name("name")
            if target is None or name is None:
                continue
            if target.type != "identifier" or name.type != "identifier":
                continue
            type_name = decode(source, target)
            member_name = decode(source, name)
            if type_name not in members or member_name in members[type_name]:
                continue
            if member_name in OBJECT_MEMBERS:
                continue  # GetType/ToString/... exist on everything, whatever the class is called
            line = node.start_point[0] + 1
            member_errors.append(
                f"{rel(path)}:{line}: {type_name} has no member `{member_name}`"
            )

    scope_errors: list[str] = []
    for path in files:
        scope_errors.extend(namespace_errors(path, sources[path], trees[path]))

    problems = syntax_errors + sorted(set(member_errors)) + sorted(set(scope_errors))
    for problem in problems:
        print(problem, file=sys.stderr)

    if problems:
        print(f"\nlint: {len(files)} files, {len(problems)} problem(s)", file=sys.stderr)
        return 1

    print(
        f"lint: {len(files)} files parse clean, "
        f"{len(members)} types, 0 unknown static members, 0 unresolved namespaces"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
