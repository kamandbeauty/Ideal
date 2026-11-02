# Driving Unity with an MCP client (mcp-unity)

[`CoderGamester/mcp-unity`](https://github.com/CoderGamester/mcp-unity) (MIT) puts an MCP server in
front of the Unity **Editor**: an MCP-capable assistant on the same machine can run menu items, read the
console, run the Test Runner, and start or stop play mode.

I cannot use it from the review sandbox — it talks to an editor over a local bridge, and this sandbox
has no route to your machine. **You can**, and it maps almost one-to-one onto the only thing M5 is
waiting for: a machine that can compile and run the project.

## Why it is worth the ten minutes

| what M5 needs | the MCP tool that gives it |
| --- | --- |
| the first compile | `recompile_scripts`, then `get_console_logs` (type: error) |
| the 150 tests actually run | `run_tests` (EditMode), then the Test Runner summary |
| the boot log — the first sign the game works | `set_play_mode_status: play`, then `get_console_logs` |
| the scenes that do not exist yet | `execute_menu_item` on `کاخ شازده/Create scenes` |
| poking the layout live | `load_scene`, `get_scene_info`, `update_component`, `select_gameobject` |

It has **no screenshot tool**. The one thing you have to do by hand is look at the Game view and, if
something looks wrong, take a screenshot — that is the only way the layout and the Persian shaping get
judged.

## Install (once)

1. **Node 18+** on the same machine as the editor (`node --version`).
2. Unity → **Window → Package Manager → + → Add package from git URL**:
   `https://github.com/CoderGamester/mcp-unity.git`
3. Unity → **Tools → MCP Unity → Server Window** → **Configure [your client]**. Prefer the
   **(Project)** variant if your client has one — it writes a relative path.
4. Open the project (`client/` in this repo) and let the console go quiet before asking for anything.

## Do not commit the tool

Two files this touches are tracked by this repo:

| file | what happens | what to do |
| --- | --- | --- |
| `client/Packages/manifest.json` | the package manager adds `"com.gamelovers.mcp-unity": "https://github.com/…"` | it is a *dev tool*: before committing anything, run `git checkout client/Packages/manifest.json`. If you keep it, CI installs it too, and a third-party editor bridge has no business in a store build |
| `client/.mcp.json` (or `.cursor/`, `.vscode/`) | the client config | git-ignored already; keep it local |

Nothing here is a game dependency. A build that contains it is not the build we ship.

## The exact run

Paste this into the assistant that has the MCP connection, from the repository root:

> You are driving the Unity Editor for a project that has never been compiled. Do exactly this and
> report after each step, in order, without skipping:
>
> 1. `recompile_scripts`, then `get_console_logs` with type `error`. Report **every** error verbatim:
>    file, line and message. If there are none, say "0 errors" and continue.
> 2. `execute_menu_item` on `کاخ شازده/Create scenes`. Report the Console lines it prints.
> 3. `run_tests` with mode EditMode. Report the totals (passed / failed / skipped) and, for every
>    failure, the test name and the first line of its message.
> 4. `load_scene` on `Assets/Scenes/App.unity`, then `set_play_mode_status: play`.
> 5. Wait three seconds, then `get_console_logs`. Paste the last 30 lines — I specifically need the
>    line that starts with `[boot]`.
> 6. `get_scene_info` and paste the hierarchy: I need to know whether the canvas and its children are
>    there at all.
> 7. `set_play_mode_status: stop`.
>
> Then stop and summarise: what broke, what passed, and what the boot line said.

Step 1 is the whole point. Everything after it is upside.

## What to send back

Just the step-1 error list, verbatim. With that, the fix is mechanical — it is the first message this
project has ever received from the compiler that will actually ship it. Screenshots of the Game view
from step 4 are the second most useful thing, because no test can tell me whether a Persian label is
clipped or a tile is half a cell off.
