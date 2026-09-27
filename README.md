# Muub-ai

个人 AI Skills 与项目规则仓库。

## 用途

- 集中维护个人编程、嵌入式、LVGL、仪表和文档类 Skill。
- 将项目规则与全局规则分层管理，避免把二轮车仪表约束误用于其他项目。
- 通过 Git 记录变更，并将 `skills/` 子目录提供给 CC Switch 拉取。

## 目录

| 目录 | 用途 |
| --- | --- |
| `skills/` | 可由 CC Switch 安装的个人 Skill |
| `project-rules/` | 特定项目使用的 `AGENTS.md` 和说明 |
| `prompts/` | 全局及领域提示词源文件 |
| `templates/` | 新建 Skill 和项目规则的模板 |
| `scripts/` | 仓库校验脚本 |
| `docs/` | 维护和同步说明 |

## 当前 Skills

当前仓库只维护个人或技术类 Skill。飞书官方 `lark-*` Skill 不复制，个人维护的 `lark-user-skill` 除外。

GUI Guider 统一使用 `guider-engineering`：总入口按 LVGL、Guider 版本和 project-edit/source-edit 任务类型只加载一个 `references/` 规范。`project-edit` 将原始工程的 `generated/` 作为只读输出，`source-edit` 可读写 `generated/` 与 `custom/`；保留 `.guiguider` 时需注意重新导出覆盖风险。普通 LVGL 工程不自动启用该 Skill。

Skill 仓库维护使用 `skill-repo-maintenance`：它只在本仓库的 Skill、路由、引用、模板、校验或分发规则发生变化时分析反向引用和同步范围；Skill 内容创作与结构设计由 `skill-creator` 负责，必要时组合使用。普通工程开发不触发该维护 Skill。

## CC Switch

在 CC Switch 中添加该仓库时，将仓库子目录设置为 `skills`。提示词、项目规则和文档不作为 Skill 安装。

详细流程见 [`docs/sync-with-cc-switch.md`](docs/sync-with-cc-switch.md)。

## 校验

在 PowerShell 中运行：

```powershell
.\scripts\validate-skills.ps1
```

## 维护原则

1. 先修改本仓库，再提交 Git。
2. 不把密钥、数据库、Provider 配置或本地绝对路径提交到仓库。
3. 项目专属约束放入对应项目的 `AGENTS.md`，不要全部塞进全局提示词。
4. Skill 的详细背景资料放在对应 Skill 的 `references/` 中。
5. 新增或修改 Skill 时，按 [`docs/skill-maintenance.md`](docs/skill-maintenance.md) 检查实际受影响的反向引用，不批量修改无关文件。
