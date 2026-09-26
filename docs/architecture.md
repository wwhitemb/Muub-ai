# 仓库架构

## 分层

```text
全局规则
  prompts/codex-global.md
       ↓
领域规则
  prompts/two-wheeler-meter.md
       ↓
项目规则
  project-rules/two-wheeler-meter/AGENTS.md
       ↓
按任务触发的 Skill
  skills/<skill-name>/SKILL.md
```

## 设计原则

- 全局规则只描述跨项目通用行为和路由方式。
- 项目规则只描述当前项目的架构、边界和验证方式。
- Skill 只描述可复用的任务处理规范。
- Skill 的深度背景资料放在对应目录的 `references/` 中，避免把所有内容塞进入口文件。
- CC Switch 只安装 `skills/` 下的目录，其他目录由项目和人工维护。
