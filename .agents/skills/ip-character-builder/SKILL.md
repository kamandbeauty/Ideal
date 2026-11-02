---
name: ip-character-builder
description: 从清晰人物照片、插画参考或已有角色三视图创建、校验并保存可携带的个人 IP 包，生成统一的正面、侧面、背面三视图和 character-spec.md。适用于个人 IP 设计、角色设定、character turnaround、IP pack、avatar builder、角色一致性与后续插图复用等任务。
---

# 通用 IP 角色构建器

## 开始前

完整读取：

- `references/turnaround-workflow.md`：输入、设计迭代、三视图生成和一致性检查。
- `references/ip-pack-format.md`：包结构、字段、安全、许可和非覆盖规则。

将 `assets/ip-pack-template/manifest.json` 与 `assets/ip-pack-template/references/character-spec.md` 作为文本模板。创建包时另建 `assets/` 与 `references/`，替换全部尖括号占位符。

## 明确目标

1. 接受一张或多张清晰人物照片、插画参考，或已有角色三视图。
2. 从用户输入提取显示名称、角色气质、固定身份特征、标志性服装、配件、配色、允许变化和禁止漂移。
3. 只追问真正影响身份一致性的缺失信息；用户已经给出明确反馈时直接迭代。
4. 将人物标识规范化为简短英文小写 kebab-case `ip-id`。
5. 固定使用 `~/.agents/ip-character-builder` 保存包；不可写时报告错误并停止写入。
6. 同名包存在时不覆盖，使用首个可用的 `-v2`、`-v3` 版本，或遵循用户指定的新 ID。

## 保护参考素材

- 只把真人照片作为当前设计和生成过程的视觉参考。
- 不复制或保存原始照片到 IP 包、Skill、插图目录或其他长期目录。
- 不在 manifest、角色规范、提示词或交付说明中记录原始照片的本机路径。
- 不从照片推断姓名、住址、单位、联系方式或其他无关隐私。
- 用户拥有或获准使用的卡通三视图可在确认后作为包内唯一角色视觉资产。

## 设计与生成

按照 `references/turnaround-workflow.md` 完成人物特征总结、造型迭代和同一角色三视图。

- 有图像生成能力时直接生成；将全部相关参考图传给工具。
- 没有图像生成能力时输出完整可执行 brief，并明确尚未形成可用 IP 包。
- 已有合格三视图时先校验，不强制重画。
- 三视图须在一张统一画布中展示正面、标准侧面和背面，不得理解成三名角色。
- 展示最终候选并取得用户确认后，才能写入正式包。

## 写入角色规范与包

用户确认三视图后：

1. 基于可见且确认的事实填写 `references/character-spec.md`。
2. 创建 `packs/<ip-id>/assets/` 和 `packs/<ip-id>/references/`。
3. 写入 `assets/turnaround.png`、`references/character-spec.md` 和 `manifest.json`。
4. 自定义包在没有明确许可时使用 `license: private`；如实保留用户提供的明确许可和署名。
5. 验证相对路径、文件存在性、包目录边界和三视图内容。

任何已有包、图片、规范或 manifest 都不得静默覆盖。

## 交付

报告 `ip-id`、显示名称、包目录、三视图和角色规范的绝对路径，以及仍需关注的一致性问题。需要文章配图时，引导用户使用 `ip-article-illustrations` 导入该完整包。
