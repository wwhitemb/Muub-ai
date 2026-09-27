---
name: skill-creator
description: 创建、修改和优化 Skill 的内容与目录结构。用户要求新增 Skill、编辑现有 Skill、调整 Skill 的触发条件或重构其参考文件时使用；仅使用既有 Skill 完成普通工程任务时不使用。
---

# Skill Creator

负责 Skill 本身的设计和编写。先明确 Skill 的职责边界、触发条件、排除条件和所需工具，再创建或修改对应文件。该 Skill 处理内容创作，不替代仓库级影响分析。

## Muub-ai 仓库约定

当目标是 Muub-ai 仓库时：

1. Skill 源文件放在仓库的 `skills/<skill-name>/` 下，入口文件必须是 `skills/<skill-name>/SKILL.md`。
2. 目录名使用小写 kebab-case，并与 frontmatter 的 `name` 完全一致。
3. 详细规则放在同一 Skill 的 `references/`，可执行检查或辅助程序放在 `scripts/`，示例或静态资源放在 `assets/`；只有确实需要时才创建这些目录。
4. 使用仓库相对路径引用本地文件，不把个人机器路径或某个部署工具的目录写入 Skill 内容。
5. Muub-ai 仓库是 Skill 的源文件位置。除非用户明确要求或分发流程本身发生变化，不直接修改 Codex、Claude 或其他工具的部署副本。

## 与仓库维护 Skill 的分工

创建或修改 Muub-ai 中的 Skill 时，按需要组合使用 `skill-repo-maintenance`：

- `skill-creator` 负责定义用途、触发/排除条件、正文规则、参考文件、脚本和资源，并完成 Skill 文件本身的修改。
- `skill-repo-maintenance` 负责检查反向引用和路由影响，判断是否需要同步全局提示词、项目规则、README、CHANGELOG、模板、校验脚本、架构文档或分发文档。
- 只修改 Skill 内容但不改变名称、触发条件、路由或仓库接口时，仍应让维护 Skill 检查影响面，但不要求修改无关文件。
- 新增触发条件、重命名/删除 Skill、调整目录或 references 结构、改变校验/分发行为时，必须同时执行仓库维护流程。
- 普通工程任务中调用既有 Skill，不触发 `skill-repo-maintenance`；这时只按被调用 Skill 的规则处理工程。

如果任务同时包含 Skill 内容创作和仓库同步，先完成本 Skill 的内容修改，再由 `skill-repo-maintenance` 根据实际引用关系执行联动检查。不要把固定的全仓库同步清单硬编码到每个 Skill 中。

## 创建或修改流程

1. **确定职责**：写清 Skill 解决的问题、适用环境、触发语义和明确排除项，避免仅凭关键词触发。
2. **检查现有内容**：修改前读取目标 `SKILL.md` 及其直接引用的 `references/`、`scripts/` 和模板，保留已有有效约定，避免无关重写。
3. **设计目录**：新建 Skill 时只创建必需的 `SKILL.md` 和辅助目录；目录和文件名保持稳定、可预测。
4. **编写入口文件**：入口文件使用合法 YAML frontmatter，包含 `name` 和同时说明“功能 + 使用时机”的 `description`，正文聚焦执行规则和路由边界。
5. **拆分详细规则**：正文过长、存在版本差异或需要示例时，将详细内容放入 `references/`，并在入口文件中说明加载条件；不要把同一规则复制到多个入口。
6. **检查交叉引用**：确认引用的其他 Skill、脚本和文档名称真实存在，并使用仓库相对路径或稳定名称。
7. **验证**：运行仓库提供的 Skill 校验脚本；必要时检查 Markdown 本地链接、frontmatter、目录命名和敏感信息。没有实际运行的命令不得声称已通过。
8. **交付说明**：说明修改的 Skill 文件、触发变化、辅助文件、验证结果和尚未验证的影响面；若仓库维护流程另有结果，单独列出。

## SKILL.md Format

```markdown
---
name: your-skill-name
description: What it does. Use when [trigger conditions].
---

# Your Skill Name

## Instructions

### Step 1: [First Major Step]
Clear explanation of what happens.

### Step 2: [Next Step]
...
```

## Rules
- Folder name must be kebab-case (e.g., `my-cool-skill`)
- File must be exactly `SKILL.md` (case-sensitive)
- Description must include what it does AND when to use it
- No XML angle brackets in frontmatter
- Keep `SKILL.md` focused on core instructions; put detailed docs in `references/`
- Preserve UTF-8 text and existing repository formatting; avoid unrelated file changes
- Do not claim validation, compilation, deployment, or synchronization that was not actually performed
