---
name: guider-engineering
description: GUI Guider 1.x/2.x 的 LVGL 工程路由与文件权限规范。Use only when LVGL evidence and same-level custom/ plus generated/ directories are present and the task changes Guider design or exported source.
---

# GUI Guider 工程路由

## 触发与排除

必须同时确认 LVGL 证据和同级 `custom/`、`generated/`。普通手写 LVGL、模拟器、驱动、只读查看生成代码不触发本 Skill。

工程状态：

- 有 `.guiguider`：原始设计工程，可进行 `project-edit` 或 `source-edit`；
- 无 `.guiguider`：导出工程，只能按 `source-edit` 维护现有导出源；
- 多个设计源且目标不明确：停止并报告。

## 路由顺序

1. 从用户指令、`.guiguider` 字段、`generated/` 结构和构建配置确认版本；证据冲突时不猜测。
2. 修改页面、控件树、样式、设计事件、动画或设计资源，选择 `project-edit`。
3. 修改导出 C/LVGL、`generated/`、`custom/`、数据绑定、刷新、平台适配或构建配置，选择 `source-edit`。
4. 只加载一个版本和任务对应的参考文件，不同时加载 project-edit 与 source-edit。

版本提示：

- 1.x 常见 `FrontJson`/`Application`、`gui_guider.*`、`setup_scr_*`；
- 2.x 常见 `UI.screen_list`、`gg_utils.*`、`screens/`、`events/`、`assets/`。

这些只是定位证据，最终以当前工程文件为准。

## 文件权限

| 工程状态 | project-edit | source-edit |
| --- | --- | --- |
| 有 `.guiguider` | 设计源和允许的 `custom/` 可写；`generated/` 只读复核 | `generated/`、`custom/` 和适配文件可写 |
| 无 `.guiguider` | 停止并说明缺少设计源 | `generated/`、`custom/` 和适配文件可写 |

有 `.guiguider` 时，source-edit 对 `generated/` 的修改可能被再次导出覆盖；页面结构和设计事件仍应回到设计源。没有设计源时，现有 `generated/` 按普通工程源代码维护。

## 参考文件

只按版本和任务加载以下一个文件：

| 版本 | project-edit | source-edit |
| --- | --- | --- |
| 1.x | `references/guider-1x-project-edit.md` | `references/guider-1x-source-edit.md` |
| 2.x | `references/guider-2x-project-edit.md` | `references/guider-2x-source-edit.md` |

若同时修改设计源和导出源，先完成 project-edit，重新生成后再进行 source-edit；不要用生成代码补丁代替设计源修改。

## 叠加规则

source-edit 仅按实际代码和领域证据追加 `coding-cpp-core`、`coding-c-safety`、`coding-rtthread-style`、`embedded-arch`、`can-bus-dev`、`meter-datapool` 或 `meter-storage`。不要因为出现 LVGL 就自动加载 Guider。

## 交付检查

说明版本/工程状态证据、唯一参考文件、实际写入的 `.guiguider`/`generated/`/`custom/`、覆盖风险、句柄/引用/资源一致性、编译与未验证风险。
