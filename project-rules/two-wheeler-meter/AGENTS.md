# 二轮车仪表项目规则

## 项目范围

- 技术栈：RT-Thread、LVGL、CAN、RS485、一线通通信和车载仪表固件。
- UI 流程：GUI Guider 设计、导出 C 代码、工程适配开发。
- 使用中文沟通；不编造硬件参数、寄存器地址、引脚、协议 ID、SDK API、构建命令或测试结果。

## 架构约束

- UI 只负责显示，业务和硬件数据统一经过全局数据池。
- 通信层负责 CAN、RS485 和一线通报文解析，UI 与业务层不得直接解析协议或访问硬件。
- GUI Guider 按 `guider-engineering` 的任务路由处理：`project-edit` 中 `generated/` 只读，`source-edit` 中 `generated/` 与 `custom/` 可读写。保留 `.guiguider` 的原始工程在重新导出时可能覆盖 `source-edit` 对 `generated/` 的修改；页面布局和控件树变化仍应回到设计源。
- 硬件参数、协议 ID 和阈值使用集中宏或配置定义，禁止散落魔法数字。

## 安全约束

- 指针解引用前判空，数组和通信缓冲区读写必须检查长度和边界。
- 中断服务函数保持极简，不阻塞、不打印、不执行复杂计算。
- 中断与任务共享的数据使用项目实际提供的同步机制，避免数据撕裂。
- 外设操作检查返回值，通信帧校验帧头、长度和校验字段，并处理异常和超时。
- 初始化遵循时钟使能、GPIO 配置、外设参数和中断使能的顺序。
- 优先静态分配；通信缓冲区优先使用静态存储和环形队列。

## Skill 路由

- C/C++ 命名：`coding-naming`
- C/C++ 风格和注释：`coding-style`
- 嵌入式 C 安全：`coding-c-safety`
- RT-Thread：`coding-rtthread-style`
- 分层架构：`embedded-arch`
- LVGL/GUI Guider：`guider-engineering`
- CAN/CAN FD：`can-bus-dev`
- 全局数据池：`meter-datapool`
- 参数和故障存储：`meter-storage`

## 交付要求

- 修改前读取目标文件、直接关联接口、调用方和配置。
- 交付时说明修改文件、关键行为、验证方式和未验证风险。
- 新增或修改公共 API、状态切换、资源生命周期、输入校验和错误路径时，同步补充说明原因、触发来源、结果和失败影响的中文注释。
- 涉及协议解析、算法、并发或用户可见行为时，增加针对性验证。
