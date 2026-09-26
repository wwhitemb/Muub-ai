# 与 CC Switch 同步

## 首次接入

将本仓库发布到 GitHub 后，在 CC Switch 的 Skills 仓库管理中添加：

```text
仓库：Muub-ai
分支：main
子目录：skills
```

CC Switch 会扫描 `skills/` 下的每个 Skill，不会安装 `prompts/`、`project-rules/`、`docs/` 或 `scripts/`。

## 更新流程

```text
修改 skills/<skill-name>/SKILL.md
    ↓
运行 scripts/validate-skills.ps1
    ↓
git add / git commit / git push
    ↓
CC Switch 刷新仓库并更新 Skill
    ↓
核对 Codex 和 Claude 的部署副本
```

不要直接修改 Codex 或 Claude 的部署副本作为长期来源。项目级 `AGENTS.md` 仍应随具体项目维护。

## 注意事项

- 当前仓库只保留个人 `lark-user-skill`，不包含飞书官方其他 Skill。
- 不要将 `cc-switch.db`、Provider 配置、账号信息或密钥复制进仓库。
- 更新前保留 Git 提交，便于回滚 Skill 内容。
