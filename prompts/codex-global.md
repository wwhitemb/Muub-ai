# 全局开发规则

本文件适用于所有编程环境。它只定义通用协作与工程约束，不把 RT-Thread、LVGL、Qt 或某一项目的约定强加给其他环境。

## 1. 工作方式

1. 使用中文分析和沟通；代码注释默认使用中文，只有用户明确要求其他语言注释时才使用其他语言。不得因代码、SDK、示例、项目现有英文注释或默认习惯改用英文。除非用户要求统一翻译，不批量改动既有原有注释。
2. MCP读写文件、执行高危终端命令、修改启动/时钟/链接脚本前，必须二次确认，未经授权不得执行。
3. 修改代码前先读取目标文件及其直接关联的接口、调用方和配置，遵循最小改动原则。
4. 不编造硬件参数、寄存器地址、引脚、协议 ID、SDK API、构建命令或测试结果；缺少依据时明确标注未知并优先查找项目证据。
5. 先识别当前编程环境，再选择对应 Skill。未命中明确环境时，只使用本文件和项目已有约定，不擅自套用专用 Skill。
6. 涉及启动流程、时钟、链接脚本、寄存器、分区、删除数据或其他高风险操作时，先说明影响并请求确认。
7. 完成修改后说明变更文件、行为变化、验证方式、未验证风险和适用边界；新增/修改代码必须输出【修改前/后】对比。注释属于实现的一部分：新增或修改公共 API、回调/事件、状态或模式切换、资源生命周期、输入校验和错误路径时，必须在编码时同步补充“为什么/触发来源/状态结果/失败影响”所需注释，并在交付前仅针对本次 diff 逐项自检；不适用的项目应明确说明，不得以最小改动或后续补充为由遗漏。交付前还必须检查本次新增或修改的注释语言；默认明确报告新增/修改注释均为中文，只有用户指定其他语言时才按该语言生成并报告。

## 2. 环境识别与 Skill 路由

### 2.1 识别顺序

按以下顺序判断，允许多个环境同时命中：

1. 用户明确指定的环境优先。
2. 项目文件和目录证据：`Kconfig`、`SConscript`、`rtthread.h`、`lvgl.h`、`.pro`、`CMakeLists.txt`、`*.ui`、`QObject`、`QWidget`、`QML` 等；GUI Guider 还要检查同一工程下的 `custom/` 与 `generated/` 目录及其生成文件。
3. 当前代码 API 和构建工具证据：RT-Thread API、LVGL API、Qt API、CMake/qmake、交叉编译工具链等。单独出现 LVGL API、`lv_ui` 或模拟器配置，不构成 GUI Guider 证据。
4. 任务语义：驱动/中断/协议、界面控件、Qt 信号槽、QML、数据持久化等。

### 2.2 环境标签

- `embedded_generic`：MCU、裸机、HAL、寄存器、驱动、RTOS、交叉编译、UART/SPI/I2C/CAN 等嵌入式任务。
- `rtthread`：出现 RT-Thread API、`rtthread.h`、`rt_device`、`rt_thread`、`rt_mutex`、`INIT_APP_EXPORT` 等证据。
- `lvgl`：出现 `lv_` API、`lvgl.h`、`lv_ui`、屏幕/控件/定时器刷新等通用 LVGL 证据；该标签本身不代表 GUI Guider。
- `guider`：先确认 LVGL 证据，再检查目标工程是否存在同级 `custom/` 与 `generated/`。两者同时存在时进入 Guider 版本识别；存在同级 `.guiguider` 是原始工程，没有则是导出工程。只有单个 `custom/` 或 `generated/` 目录时不得自动命中。
- `qt`：出现 Qt/C++、`QObject`、`QWidget`、`QQuick`、QML、signals/slots、`.pro`、Qt CMake 包等证据。
- `can_meter_domain`：任务涉及本项目仪表 CAN、数据池、里程、故障码或参数存储时才启用。

### 2.3 路由规则

- 通用 C/C++ 修改：只启用与语言和任务直接相关的规则。
- `embedded_generic`：启用 `coding-c-safety`；涉及架构或移植时启用 `embedded-arch`。
- `rtthread`：在 `embedded_generic` 基础上启用 `coding-rtthread-style`。
- `lvgl`：仅按通用 LVGL 线程模型和项目现有规则处理；不得仅凭 `lvgl` 标签启用 `guider-engineering`。LVGL PC/SDL/Windows 模拟器、手写 LVGL UI、显示/输入驱动默认不启用 Guider Skill。
- `guider`：启用 `guider-engineering`，并按版本和任务只加载一个 `references/guider-{1x|2x}-{project-edit|source-edit}.md`。明确修改 `.guiguider`、GUI Guider 源工程、页面或控件设计时选 `project-edit`；修改导出 C/LVGL、`generated/`、`custom/`、数据绑定、刷新或移植时选 `source-edit`。`project-edit` 中原始工程的 `generated/` 只读；`source-edit` 中 `generated/` 和 `custom/` 可读写，但原始工程再次导出时可能覆盖这些修改。若同时运行于 RT-Thread，再叠加 `coding-rtthread-style`；若涉及嵌入式 C、命名、风格或架构，按证据叠加对应通用 Skill。目录证据与任务描述冲突时停止并说明假设。
- `skill_repo_maintenance`：仅当用户在 Muub-ai 仓库中创建、修改、重命名或删除 Skill，或调整 Skill 的路由、引用、模板、校验或分发流程时启用 `skill-repo-maintenance`；需要设计或编写 Skill 内容时同时启用 `skill-creator`。普通工程任务中调用既有 Skill、阅读 Skill 文档或修改业务代码不触发维护 Skill。维护 Skill 依据实际反向引用判断同步文件，不要求批量修改无关项目规则。
- `can_meter_domain`：按任务叠加 `can-bus-dev`、`meter-datapool`、`meter-storage`，不因打开本项目就全部启用。
- 飞书嵌入式技术文档：用户要求创建、编写、整理或修改飞书文档，且主题涉及 MCU、单片机、STM32、CubeMX、Keil、HAL、RTOS、LVGL、驱动、外设、通信、存储、显示、调试或移植时，启用 `lark-user-skill`；实际读取或写入飞书文档时同时启用 `lark-doc`，浏览知识库目录或参考 Wiki 时同时启用 `lark-wiki`。
- C/C++ 命名和格式：仅在生成或修改对应代码、公共 API 或进行代码审查时启用 `coding-naming` 与 `coding-style`。
- `qt`：启用 `qt-cpp-dev`；不得调用 RT-Thread、LVGL、仪表数据池或 GUI Guider Skill，除非代码中有明确跨平台集成证据。
- 环境证据冲突时，暂停专用假设，向用户询问目标平台或以现有代码接口为准。

## 3. 通用代码质量要求

1. 保持接口兼容，除非用户明确要求修改接口。
2. 输入、外部数据、文件、网络和硬件边界必须校验；内部由框架保证的条件不重复增加无意义防御。
3. 错误路径必须可观察且有明确处理；不吞掉返回值，不伪造成功。
4. 并发访问共享状态时使用项目实际提供的同步机制；不要跨框架混用同步 API。
5. 优先复用仓库已有模式，避免一次性抽象、无关重构和新增依赖。
6. 测试范围与风险匹配：协议、算法、公共 API、跨线程和用户可见行为需要重点验证。

## 4. 按环境执行的项目约束

以下约束只有命中对应环境或领域标签时生效：

- 嵌入式：优先定宽整数类型，关注中断、内存、栈、边界、并发和硬件返回值。
- RT-Thread：任务、IPC、初始化级别和线程协作遵循 `coding-rtthread-style`。
- LVGL：所有 LVGL 操作遵循其线程模型；UI 与业务/数据源解耦。
- GUI Guider：`project-edit` 将 `generated/` 作为只读输出复核；`source-edit` 可按版本规则修改 `generated/` 和 `custom/`，但保留 `.guiguider` 的工程需报告重新导出覆盖风险。
- 仪表领域：通信层、数据池、UI、存储按对应 Skill 的边界协作。
- Qt：遵循 Qt 对象树、信号槽、线程亲和性、事件循环、资源和 CMake/qmake 约定；不套用嵌入式命名或 RT-Thread API。

## 5. 交付格式

交付时简要列出：

- 已识别的环境标签及实际启用的 Skill；
- 修改内容和关键行为变化；
- 测试/构建/静态检查结果；
- 尚未验证的前置条件或风险。

未实际执行的命令不得声称已执行，未实际通过的测试不得声称通过。

## 6. Skill 目录

### 通用语言规则

- `coding-naming`：C/C++ 项目命名；仅用于命名设计和审查。
- `coding-style`：C/C++ 格式、注释、公共 API 结构；仅用于代码风格和审查。
- `coding-c-safety`：嵌入式 C 安全；仅用于嵌入式 C 任务。

### 嵌入式与 RTOS

- `embedded-arch`：嵌入式分层、驱动/HAL/OSAL 和移植；需要架构或跨平台证据时启用。
- `coding-rtthread-style`：RT-Thread 任务、IPC、初始化和调度；检测到 RT-Thread 时启用。

### LVGL 与仪表领域

- `guider-engineering`：GUI Guider 1.x/2.x 原始工程和导出 LVGL 工程的版本识别、互斥路由与适配规范。
- `can-bus-dev`：CAN/CAN FD 报文、解析、过滤和故障处理。
- `meter-datapool`：仪表数据池、有效性、并发读写和数据流。
- `meter-storage`：仪表参数、里程和故障记录持久化。

### Skill 仓库维护

- `skill-creator`：设计和编写 Skill 的入口、触发条件、规则和参考文件。
- `skill-repo-maintenance`：分析 Muub-ai 内 Skill 变更的反向引用和影响面，按实际需要同步路由、文档、模板、校验和分发说明。

### Qt

- `qt-cpp-dev`：Qt Widgets/QML/C++ 工程开发、信号槽、对象生命周期、线程和构建适配。
