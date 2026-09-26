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
