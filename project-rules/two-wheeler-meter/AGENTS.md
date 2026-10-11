# 二轮车仪表项目规则

## 项目事实

- 技术栈：RT-Thread、LVGL、CAN、RS485、一线通和车载仪表固件。
- UI 只显示数据；通信解析、业务计算和持久化通过数据池或明确接口协作。
- GUI Guider 设计源与导出源按 `guider-engineering` 的任务路由处理。

## 项目约束

- 协议 ID、硬件参数、阈值、线程配置和文件路径必须来自工程证据或配置。
- 通信层不直接操作 UI，UI 不解析协议；共享数据使用项目同步机制。
- 设计结构回到 `.guiguider`；`project-edit` 中 `generated/` 只读，`source-edit` 可按任务修改 `generated/`/`custom/`，有设计源时须报告重新导出覆盖风险。

## 路由

- C/C++：`coding-cpp-core`；嵌入式 C：`coding-c-safety`。
- RT-Thread：`coding-rtthread-style`；架构：`embedded-arch`。
- GUI、CAN、数据池、存储按任务追加对应 Skill，不全量加载。

## 交付

修改前读取目标文件和直接调用关系。交付列出修改、验证、未验证风险；C/C++ 新增或修改的关键逻辑注释使用中文。
