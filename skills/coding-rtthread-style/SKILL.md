---
name: coding-rtthread-style
description: RT-Thread 线程、IPC、初始化、资源生命周期和 LVGL 协同规范。Use when Codex designs, implements, reviews, or debugs RT-Thread tasks, devices, IPC, startup, or scheduler interactions.
---

# RT-Thread 开发规范

## 适用范围

检测到 `rtthread.h`、`rt_thread`、`rt_device`、IPC 或 RT-Thread 初始化入口时启用。C/C++ 基础规则使用 `coding-cpp-core`，嵌入式边界使用 `coding-c-safety`。

## 按需参考

创建或修改线程、信号量、互斥锁、事件集、设备回调、启动入口或资源释放流程时，加载 `references/rtthread-ipc-templates.md`。不为普通 RT-Thread 代码审阅自动加载全部模板。

## 线程与调度

- 一个线程只承担清晰职责；通信接收、业务计算、存储写入和 UI 刷新按实际时序拆分。
- 优先级数字越小通常优先级越高，但最终以当前 `RT_THREAD_PRIORITY_MAX` 和项目配置为准；不要复制固定数值。
- 线程入口必须处理创建、启动、退出和失败路径；栈大小、时间片和周期由测量或项目配置决定。
- 阻塞等待优先使用事件、信号量、消息队列或设备通知，避免无条件轮询和忙等。
- 线程退出或模块卸载时成对释放线程、IPC、设备和动态资源；若系统不支持卸载，明确其永久生命周期。

## IPC 选择

| 场景 | 首选 | 约束 |
| --- | --- | --- |
| ISR 通知任务 | 信号量、事件或设备通知 | ISR 只发送快速通知 |
| 传递带内容的数据 | 消息队列或环形缓冲区 | 明确所有权和溢出策略 |
| 保护短时共享快照 | 互斥锁 | 锁内只复制数据 |
| 多来源状态位 | 事件集 | 定义清除、合并和丢失语义 |

IPC 名称、超时、优先级和初始化级别必须使用项目现有约定。不要在本 Skill 中重复 CAN、数据池或存储格式规则。

## 启动与设备

- 初始化顺序遵循“底层设备可用 -> IPC/线程 -> 业务服务 -> UI/上层入口”，具体宏和阶段以工程配置为准。
- 检查设备查找、打开、配置、发送、接收和关闭返回值；失败时保留可观察日志或向上传递错误。
- 设备回调只做轻量通知或数据转移，复杂处理放到线程上下文。
- 与 LVGL 交互时遵循项目指定的 UI 线程/锁模型，业务线程不得直接跨线程调用控件 API。

## 与领域 Skill 的边界

- CAN 收发和协议解析：`can-bus-dev`
- 数据池契约和快照：`meter-datapool`
- 文件、CRC 和掉电保存：`meter-storage`
- 分层和移植：`embedded-arch`
- GUI Guider 导出源：`guider-engineering` 的单一版本/任务参考文件

## 交付前检查

确认阻塞点、IPC 所有权、优先级依据、初始化依赖、资源生命周期、错误返回和 UI 线程边界；不要输出无项目依据的线程栈、优先级或 API 参数。
