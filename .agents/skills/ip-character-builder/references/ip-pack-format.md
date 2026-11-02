# 可携带 IP 包格式

## 目录

固定使用 `~/.agents/ip-character-builder`：

```text
<builder-home>/
└── packs/
    └── <ip-id>/
        ├── manifest.json
        ├── assets/
        │   └── turnaround.png
        └── references/
            └── character-spec.md
```

私人包不写入 Skill 源码仓库。根目录不可写时报告错误并停止。

## ID 与版本

- 使用简短、稳定的英文小写 kebab-case，例如 `alex-creator`。
- 拒绝空格、绝对路径、`..`、斜杠和控制字符。
- 同名目录存在时不覆盖，依次尝试 `<ip-id>-v2`、`-v3`。

## manifest.json

```json
{
  "schemaVersion": 1,
  "id": "alex-creator",
  "displayName": "Alex Creator",
  "style": "editorial-surrealism",
  "assets": {
    "turnaround": "assets/turnaround.png"
  },
  "characterSpec": "references/character-spec.md",
  "license": "private"
}
```

规则：

- `id` 与包目录名一致。
- `style` 是建议的插图画风，不是人物身份；默认 `editorial-surrealism`，可由用户明确指定其他稳定风格 ID。
- 资产和规范只使用相对路径。
- 拒绝绝对路径、`..` 路径穿越，以及解析后离开包目录的符号链接。
- 未提供明确来源许可时使用 `private`；不要自动把私人或第三方素材标成开放许可。
- 需要署名时增加 `attribution`，并保留来源许可要求。

## character-spec.md

使用固定章节：

```markdown
# <显示名称> 角色规范

## 角色定位
## 固定身份特征
## 标志性服装与配件
## 允许变化
## 禁止漂移
## 生图提示词片段
## 一致性检查清单
```

只写可观察、可执行并经用户确认的视觉规则，不写原始照片路径、私人背景或未确认推断。

## 完成验证

1. 包目录名与 `manifest.id` 一致。
2. 三视图和角色规范存在且可读。
3. 相对路径解析后仍在包目录内。
4. 三视图包含同一角色的正面、侧面和背面。
5. manifest 没有虚构许可或署名。
6. 包内不含原始真人照片和本机来源路径。
