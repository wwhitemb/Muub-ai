---
name: guider-engineering
description: GUI Guider 1.x/2.x 工程路由 Skill。仅在 LVGL 工程同时具备同级 custom/ 和 generated/，且用户要求修改 GUI Guider 设计源或导出源代码时使用。
---

# GUI Guider 完整工程路由

## 适用范围

本 Skill 统一处理 GUI Guider 1.x 和 2.x 的两类任务：

- `project-edit`：修改 GUI Guider 原始设计工程，包括 `.guiguider`、页面、控件、样式、事件、动画和设计资源。
- `source-edit`：修改 GUI Guider 导出的 LVGL/C 源代码，包括 `generated/`、`custom/`、平台适配、数据绑定、刷新、资源和构建配置。

普通手写 LVGL 工程、LVGL 模拟器、显示/输入驱动和只读查看生成代码不触发本 Skill。只读查看 `generated/` 时不加载四份修改细则。

## 路由顺序

### 1. 确认 LVGL 工程

在目标工程根目录及直接构建配置中寻找至少一项证据：

- `lvgl.h`、`lv_conf.h`、`lv_conf_ext.h`；
- `lv_` API 或 LVGL 源码目录；
- CMake、SCons、Makefile 或平台工程中的 LVGL 配置；
- `custom/` 或 `generated/` 文件中的 `lvgl.h`、`LVGL_VERSION_*` 或 LVGL 构建目标；
- `.guiguider` 中的 LVGL 工程配置。

没有明确 LVGL 证据时停止 Guider 路由，并说明缺少的证据。

### 2. 确认 Guider 工程和工程状态

目标工程必须存在同级的 `custom/` 和 `generated/`。只有其中一个目录时，不自动认定为 Guider 工程。

- 同级存在一个 `.guiguider`：原始设计工程；
- 没有 `.guiguider`：导出工程；
- 存在多个 `.guiguider` 且无法根据用户指令和目录结构确定目标：停止并报告。

版本识别前先记录工程根目录、两个目录和 `.guiguider` 命中情况。不要把 Git 状态作为触发条件或阻塞条件。

### 3. 判断 Guider 版本

版本证据优先级：

1. 用户明确指定的版本；
2. `.guiguider` 顶层结构和版本字段；
3. `generated/` 文件结构；
4. LVGL 版本和构建配置。

Guider 1.x 证据：

- `.guiguider` 含 `FrontJson`、`Application`；
- `generated/gui_guider.c/h`；
- `setup_scr_*.c`、`events_init.c/h`、`widgets_init.c/h` 或 `generated.mk`。

Guider 2.x 证据：

- `.guiguider` 的 `version` 或 `createVersion` 表示 `2.*`，并含 `UI.screen_list`；
- `generated/gg_utils.c/h`；
- `generated/screens/gg_screen_*.c`、`gg_layer_*.c`；
- `generated/events/gg_event_*.c`；
- `generated/assets/`。

版本证据冲突、不足或互相矛盾时停止修改并报告具体路径。2.x 专有结构命中时优先按 2.x 处理，不能仅凭 `generated/gui_guider.h` 判定为 1.x。

### 4. 判断任务类型

选择 `project-edit`：

- 用户明确要求修改 `.guiguider`、GUI Guider 源工程或设计源；
- 用户要求改变页面、控件树、样式、事件结构、动画目标或设计资源，并需要重新生成代码。

选择 `source-edit`：

- 用户要求修改导出的 C/LVGL、`generated/`、`custom/`、数据绑定、刷新函数、资源适配、平台移植或构建配置；
- 用户要求修复 LVGL API 兼容、事件回调或导出后的句柄适配。

`.guiguider` 的存在只表示工程状态，不强制所有任务走 `project-edit`。原始工程中的导出代码或 `custom/` 适配任务仍走 `source-edit`。

## 文件权限矩阵

权限由工程状态和任务类型共同决定：

| 工程状态 | `project-edit` | `source-edit` |
| --- | --- | --- |
| 存在 `.guiguider` 的原始工程 | `.guiguider`、`custom/` 可写；`generated/` 只读复核 | `generated/`、`custom/`、平台/业务/构建文件可读写 |
| 不存在 `.guiguider` 的导出工程 | 停止并报告缺少设计源 | `generated/`、`custom/`、平台/业务/构建文件可读写 |

在原始工程执行 `source-edit` 时，`generated/` 的修改仅用于导出 C/LVGL、事件、资源和构建适配。页面布局、控件树、样式和设计事件结构仍必须回到 `.guiguider` 修改。GUI Guider 重新导出后可能覆盖这些修改，交付时必须报告覆盖风险。

在导出工程执行 `source-edit` 时，`generated/` 已经是当前工程源代码，不要求寻找不存在的 `.guiguider`。资源、事件、屏幕初始化、头文件和构建清单均可按任务直接维护。

## 参考文件选择

一次任务只能加载一个版本和任务类型对应的参考文件：

| 工程版本 | 任务类型 | 参考文件 |
| --- | --- | --- |
| Guider 1.x | `project-edit` | `references/guider-1x-project-edit.md` |
| Guider 1.x | `source-edit` | `references/guider-1x-source-edit.md` |
| Guider 2.x | `project-edit` | `references/guider-2x-project-edit.md` |
| Guider 2.x | `source-edit` | `references/guider-2x-source-edit.md` |

如果请求同时修改设计源和导出代码，分三个阶段执行：

1. 使用对应的 `project-edit` 参考文件修改设计源；
2. 用户重新生成 GUI Guider 输出；
3. 使用对应的 `source-edit` 参考文件修改导出工程。

不能同时加载两份参考文件，也不能用 `source-edit` 生成代码修改替代设计源修改。

## 与其他 Skill 的叠加

`project-edit` 只执行本 Skill 中匹配版本的设计源规则。

`source-edit` 修改 C/LVGL/嵌入式代码时，按实际证据叠加：

- `coding-c-safety`：嵌入式 C、安全边界、并发和资源生命周期；
- `coding-style`、`coding-naming`：修改 C/C++、公共 API、命名或注释；
- `coding-rtthread-style`：检测到 RT-Thread；
- `embedded-arch`：涉及分层、平台移植或启动流程；
- `can-bus-dev`、`meter-datapool`、`meter-storage`：只有任务明确涉及对应领域时启用。

普通 LVGL 工程不能仅凭 `lvgl` 标签启用本 Skill。

## 交付要求

交付时说明：

- LVGL、Guider 版本和原始/导出工程判断依据；
- 唯一加载的参考文件及叠加的通用 Skill；
- 修改的 `.guiguider`、`custom/`、`generated/` 和其他持久文件；
- `project-edit` 中 `generated/` 的只读复核结果，或 `source-edit` 中 `generated/`/`custom/` 的实际修改；
- 原始工程 source-edit 修改的重新生成覆盖风险；
- JSON、静态一致性、句柄、引用和资源验证结果；
- 实际编译结果或未执行编译的原因；
- 尚未验证的运行时风险和新增/修改注释语言。
