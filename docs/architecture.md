# 仓库架构

## 分层

```text
全局规则
  prompts/global.md
       ↓
领域规则
  prompts/two-wheeler-meter.md
       ↓
项目规则
  project-rules/two-wheeler-meter/AGENTS.md
       ↓
按任务触发的 Skill
  skills/<skill-name>/SKILL.md
  skills/<domain>/<skill-name>/SKILL.md
```

## 设计原则

- 全局规则只描述跨项目通用行为和路由方式。
- 项目规则只描述当前项目的架构、边界和验证方式。
- Skill 只描述可复用的任务处理规范。
- Skill 的深度背景资料放在对应目录的 `references/` 中，避免把所有内容塞进入口文件。
- `skills/` 是 Skill 的安装根目录，仓库校验支持一级 Skill 和按领域分组的嵌套 Skill；其他目录由项目和人工维护。外部安装客户端的递归能力需要单独确认。
- 分组目录（例如 `skills/office/`）本身不是 Skill，只有包含 `SKILL.md` 的目录才是可安装 Skill。
