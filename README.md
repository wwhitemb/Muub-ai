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

当前仓库只维护个人或技术类 Skill。飞书官方 `lark-*` Skill 不复制，个人维护的 `lark-user-skill` 除外。Skill 可以直接放在 `skills/` 下，也可以按领域放在分组目录下，例如 `skills/office/xls-io-mapping/`。

基础 C/C++ 规则统一使用 `coding-cpp-core`，它是唯一的通用 C/C++ 基础 Skill。GUI Guider 统一使用 `guider-engineering`：总入口按 LVGL、Guider 版本和 project-edit/source-edit 任务类型只加载一个 `references/` 规范。`project-edit` 将原始工程的 `generated/` 作为只读输出，`source-edit` 可读写 `generated/` 与 `custom/`；保留 `.guiguider` 时需注意重新导出覆盖风险。普通 LVGL 工程不自动启用该 Skill。

高价值代码骨架、检查清单和输出记录模板放在各 Skill 的 `references/` 中。入口 `SKILL.md` 只负责触发、边界和路由；只有当前任务需要时才加载对应参考文件，Guider 的版本和 `project-edit`/`source-edit` 参考文件互斥。参考模板使用占位符，不能替代对目标工程 API、配置和硬件证据的确认。

Skill 仓库维护使用 `skill-repo-maintenance`：它只在本仓库的 Skill、路由、引用、模板、校验或分发规则发生变化时分析反向引用和同步范围；Skill 内容创作与结构设计由 `skill-creator` 负责，必要时组合使用。普通工程开发不触发该维护 Skill。

## CC Switch

在 CC Switch 中添加该仓库时，将仓库子目录设置为 `skills`。本仓库按递归目录组织包含 `SKILL.md` 的 Skill，`office` 等分组目录不单独作为 Skill；实际客户端是否支持嵌套目录需在部署时确认。提示词、项目规则和文档不作为 Skill 安装，`prompts/global.md` 与 `prompts/two-wheeler-meter.md` 必须由实际运行环境单独注入或复制到项目规则中，否则其中的全局路由和中文注释门槛不会生效。

详细流程见 [`docs/sync-with-cc-switch.md`](docs/sync-with-cc-switch.md)。

## 校验

在 PowerShell 中运行：

```powershell
.\scripts\validate-skills.ps1
.\scripts\measure-skill-bundles.ps1
```

校验脚本负责格式、引用和编码门禁；测量脚本用于观察单个 Skill、参考文件和典型组合的上下文预算，不把估算值当成模型实际 Token 数。

## 维护原则

1. 先修改本仓库，再提交 Git。
2. 不把密钥、数据库、Provider 配置或本地绝对路径提交到仓库。
3. 项目专属约束放入对应项目的 `AGENTS.md`，不要全部塞进全局提示词。
4. Skill 的详细背景资料、可复用代码骨架和检查模板放在对应 Skill 的 `references/` 中，并按任务按需加载。
5. 新增或修改 Skill 时，按 [`docs/skill-maintenance.md`](docs/skill-maintenance.md) 检查实际受影响的反向引用，不批量修改无关文件。
6. 入口文件保持短小；版本、平台和任务差异放入按需加载的 `references/`，不要把完整示例复制到多个 Skill。
