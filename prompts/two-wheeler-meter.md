# 二轮车仪表领域规则

本文件是领域注入兼容层；若目标项目已注入 `project-rules/two-wheeler-meter/AGENTS.md`，二者二选一，不要同时注入。

## 项目事实

- 技术栈：RT-Thread、LVGL、CAN、RS485、一线通和车载仪表固件。
- 数据流：通信解析 -> 数据池 -> 业务/UI/存储；UI 不直接解析协议或访问硬件。
- UI 流程：GUI Guider 设计源 -> 导出 C -> 工程适配。

## 领域路由

- C/C++：`coding-cpp-core`；嵌入式 C：追加 `coding-c-safety`。
- RT-Thread：`coding-rtthread-style`；分层/移植：`embedded-arch`。
- GUI Guider：`guider-engineering`，只加载对应版本和 `project-edit`/`source-edit` 参考文件。
- CAN、数据池、存储：按任务分别追加 `can-bus-dev`、`meter-datapool`、`meter-storage`。

## 不可替代的项目约束

- 协议 ID、硬件参数、阈值、线程配置和路径必须来自项目证据或配置。
- 中断、通信、共享数据和 UI 线程边界遵循对应 Skill；不要在本文件复制实现模板。
- 修改前读取目标文件及直接调用关系；交付说明变更、验证和未验证风险。
