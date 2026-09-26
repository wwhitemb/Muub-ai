# Skill 维护

## 新建 Skill

1. 复制 `templates/SKILL.md.template` 到 `skills/<skill-name>/SKILL.md`。
2. 将 `name` 设置为目录名，将 `description` 写成明确的触发条件和适用范围。
3. 复杂背景资料放入该 Skill 的 `references/` 目录。
4. 运行 `scripts/validate-skills.ps1`。
5. 提交 Git 后再推送远程仓库。

## 修改 Skill

- 只修改仓库中的 Skill 源文件。
- 保持公共名称和目录名稳定，避免 CC Switch 产生重复安装记录。
- 规则变更时同步更新 `CHANGELOG.md`。
- 删除规则前先通过 Git 提交保留可回滚版本。

## 项目规则

项目专属要求放入具体工程根目录的 `AGENTS.md`，不要把硬件型号、协议 ID、目录路径和项目特殊约束写入全局规则。
