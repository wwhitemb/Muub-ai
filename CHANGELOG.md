# 变更记录

## 2026-09-28

- 新增 `taobao-product-inquiry`，支持按商品关键词检索淘宝/天猫、按不同商家发送用户自定义询价，并在达到目标数量后汇总客服回复和过程日志。
- 增加浏览器会话、登录、验证码、风控、对外消息确认和固定等待窗口的边界规则。
- 扩展 `taobao-product-inquiry` 的只搜索模式：按商品数量收集去重结果，并输出页面可见价格、店铺名和原始商品链接。

## 2026-09-27

- 新增 `skill-repo-maintenance`，用于分析 Skill 变更的反向引用和仓库联动影响面。
- 扩展 `docs/skill-maintenance.md`、全局路由和仓库校验，明确 `skill-creator` 与维护 Skill 的组合边界，并增加本地 Markdown 链接检查。
- 将 `guider-lvgl-port` 重构为 `guider-engineering` 总 Skill。
- 增加 Guider 1.x/2.x 的 `project-edit` 和 `source-edit` 四路由参考文件。
- 明确先确认 LVGL、再识别同级 `custom/` 与 `generated/`、再判断原始/导出工程和版本。
- 明确按任务路由 `generated/` 权限：`project-edit` 只读复核，`source-edit` 可读写；保留 `.guiguider` 的原始工程重新导出时可能覆盖 `generated/` 修改，并更新仓库路由与动态 Skill 校验。

## 2026-09-26

- 创建 Muub-ai 个人 AI 仓库。
- 纳入 13 个个人和技术类 Skill。
- 保留个人的 `lark-user-skill`，排除其他飞书官方 Skill。
- 增加全局规则、二轮车仪表规则、项目规则模板和仓库校验脚本。
