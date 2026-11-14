# Ideal

پروژهٔ تازهٔ بازی با **Godot 4.7**. مخزن خالی شده و اسکلت پروژه آماده است؛
بازیِ اصلی روی همین پایه ساخته می‌شود.

A fresh **Godot 4.7** game project. The repository was cleared and this scaffold
is the starting point for the new game.

## وضعیت / Status

| بخش | مسیر |
| --- | --- |
| پروژهٔ Godot | [`project.godot`](project.godot) |
| صحنهٔ اصلی | [`scenes/main.tscn`](scenes/main.tscn) |
| اسکریپت‌ها | [`scripts/`](scripts/) |
| آیکون | [`icon.svg`](icon.svg) |

The entry scene is a placeholder title screen: it exists so the project boots
and can be imported by the engine. It is replaced by the real game.

## اجرا / Running

```bash
# Requires Godot 4.7.x
godot --path .              # run the game
godot --path . --editor     # open in the editor
godot --headless --path . --editor --import   # import assets without a display
```

## ساختار پیشنهادی / Layout

```
scenes/    scenes and levels
scripts/   GDScript
assets/    art, audio, fonts (imported by the engine)
tests/     headless test scenes and suites
```
