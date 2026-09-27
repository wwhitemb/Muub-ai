---
name: "embedded-arch"
description: "嵌入式工程分层、模块边界、驱动/HAL/OSAL、GUI 适配、跨平台移植和初始化架构规范。Use when Codex designs or refactors embedded project structure, module boundaries, driver ports, OSAL interfaces, GUI integration, or startup order."
---

# 嵌入式工程分层架构规范

## 适用范围
在嵌入式工程进行目录架构、模块边界、驱动/HAL/OSAL、GUI 适配或跨平台移植设计时启用。默认示例面向 RT-Thread + LVGL 仪表项目；若当前工程不是该组合，只继承分层原则，不照搬目录、初始化宏或 API。

## 触发场景
- 新建工程、目录结构设计
- 新增模块、文件拆分
- GUI Guider工程导入与代码隔离
- 代码重构、解耦优化
- 驱动移植、跨平台适配

## 核心执行规范

### 1. 标准目录架构（基于实际项目）

#### 1.1 四层架构模型
```
应用层 (application/rt-thread/helloworld/app_xxx/)
    ↓ 单向依赖
业务层 (packages/artinchip/lvgl-ui/aic_demo/guider_xxx_demo/custom/)
    ↓ 单向依赖
组件层 (packages/artinchip/xxx/, packages/third-party/xxx/)
    ↓ 单向依赖
驱动层 (bsp/artinchip/drv/, bsp/artinchip/hal/)
    ↓ 单向依赖
内核层 (kernel/rt-thread/, kernel/common/)
```

#### 1.2 目录结构详解

**应用层（业务代码入口）**
```
application/rt-thread/helloworld/app_1048_rgb_long/
├── user_can.c/h              # CAN通信模块：报文收发、协议解析、数据池写入
├── user_io.c/h               # 输入模块：按键检测、GPIO状态、模式切换
├── user_file.c/h             # 存储模块：参数持久化、文件读写、CRC校验
├── user_wifi_sta.c/h         # WiFi模块（可选）：网络通信、远程监控
├── Kconfig                   # 模块配置菜单
└── SConscript                # 构建脚本
```

**业务层（UI适配层）**
```
packages/artinchip/lvgl-ui/aic_demo/guider_1048_rgb_long_demo/
├── custom/                   # 【核心】适配层（用户可修改）
│   ├── custom.c/h           # 数据池定义、定时器刷新、显示更新函数
│   ├── custom_file.c/h      # 图片路径宏定义、动画图片数组声明
│   └── lv_conf_ext.h        # LVGL配置扩展（board/simulator差异化）
│
├── generated/                # project-edit 只读复核；source-edit 可维护的导出源（1.x/2.x结构由版本决定）
│   ├── gui_guider.* 或 gg_*.*
│   ├── screens/、events/、assets/（2.x可能存在）
│   └── images/、guider_fonts/（1.x可能存在）
│
├── ui_init.c/h              # UI初始化入口（调用custom_init/setup_ui/events_init）
├── lv_conf_custom.h         # LVGL自定义配置
└── SConscript               # 构建脚本
```

**组件层（第三方+厂商组件）**
```
packages/
├── artinchip/               # 原厂组件包
│   ├── lvgl-ui/            # LVGL UI框架
│   ├── mpp/                # 多媒体处理包
│   ├── ota/                # OTA升级组件
│   └── sys/                # 系统组件包
│
└── third-party/            # 第三方组件
│   ├── lwip/               # 网络协议栈
│   ├── cherryusb/          # USB协议栈
│   └── lvgl/               # LVGL图形库
```

**驱动层（硬件抽象）**
```
bsp/artinchip/
├── drv/                    # RT-Thread驱动框架层
│   ├── can/               # CAN驱动
│   ├── uart/              # UART驱动
│   ├── gpio/              # GPIO驱动
│   └── adc/               # ADC驱动
│
├── hal/                    # 硬件抽象层（HAL）
│   ├── can/               # CAN硬件操作（不依赖OS）
│   ├── uart/              # UART硬件操作
│   └── clk/               # 时钟配置
│
└── include/               # 驱动头文件
    ├── drv/               # DRV层头文件
    └── hal/               # HAL层头文件
```

**内核层（OS抽象）**
```
kernel/
├── rt-thread/             # RT-Thread内核源码
├── freertos/              # FreeRTOS内核源码（可选）
├── common/                # OS抽象层（OSAL）
│   ├── include/osal/      # OSAL接口头文件
│   └── src/               # OSAL实现源码
│
└── baremetal/             # 裸机模式（可选）
```

### 2. 模块边界定义

#### 2.1 应用层职责
- **通信模块**（user_can.c）：CAN/RS485/一线通报文收发、协议解析、数据池写入
- **输入模块**（user_io.c）：按键检测、GPIO状态、模式切换、事件上报
- **存储模块**（user_file.c）：参数持久化、文件读写、CRC校验、事件响应
- **业务模块**：车速里程计算、告警判断、逻辑控制、状态管理

**设计原则：**
- 应用层仅调用组件层接口，不直接操作驱动层
- 应用层通过数据池与UI层解耦，禁止直接调用LVGL接口
- 应用层模块间通过IPC（信号量/互斥锁/事件组）通信，禁止全局变量无保护共享

#### 2.2 业务层职责（UI适配层）
- **数据池定义**（custom.h）：定义全局数据结构体，作为UI与业务层的唯一数据接口
- **数据绑定**（custom.c）：定时器刷新函数、显示更新函数、主题切换逻辑
- **资源管理**（custom_file.h）：图片路径宏定义、动画图片数组声明
- **LVGL配置**（lv_conf_ext.h）：board/simulator差异化配置

**设计原则：**
- 业务层仅从数据池读取数据，禁止直接访问通信缓冲区
- 业务层仅调用LVGL接口更新显示，禁止做业务计算
- 业务层与 Guider 代码保持边界：`project-edit` 中 `generated/` 只读复核，`source-edit` 中 `generated/` 与 `custom/` 可读写；原始工程重新导出可能覆盖 source-edit 对 `generated/` 的修改

#### 2.3 驱动层职责
- **DRV层**：对接RT-Thread驱动框架，注册设备（rt_device），使用OSAL接口
- **HAL层**：纯硬件操作，不依赖任何OS，可被baremetal应用直接调用

**设计原则：**
- DRV层负责中断注册、互斥锁、信号量，调用HAL层接口
- HAL层负责寄存器配置、硬件初始化，不使用IPC、不注册中断
- 驱动层与应用层严格解耦，禁止业务逻辑侵入驱动层

### 3. 分层依赖原则

#### 3.1 单向依赖规则
```
应用层 → 业务层 → 组件层 → 驱动层 → 内核层
     ↓        ↓        ↓        ↓        ↓
   数据池    LVGL    SDK组件   HAL    OSAL
```

**强制约束：**
- 上层可调用下层接口，下层禁止调用上层接口
- 同层模块间可相互调用，但需通过IPC通信
- 跨层调用必须通过中间层代理，禁止跨层直接访问

#### 3.2 数据流向规则
```
硬件 → 驱动层(HAL) → 驱动层(DRV) → 应用层(通信模块) → 数据池 → 业务层(UI) → 显示
                                                            ↓
                                                         应用层(存储模块) → 文件系统
```

**强制约束：**
- 硬件数据单向流动：硬件 → 驱动 → 应用 → 数据池 → UI/存储
- UI数据仅从数据池读取，禁止反向写入
- 存储数据从数据池读取，异步写入文件系统

### 4. GUI Guider工程隔离机制

#### 4.1 两层隔离架构
```
guider_xxx_demo/
├── custom/                  # 适配层（用户可修改）
│   ├── custom.c/h          # 数据池、刷新函数、主题切换
│   ├── custom_file.c/h     # 图片路径、动画数组
│   └── lv_conf_ext.h       # LVGL配置扩展
│
└── generated/               # project-edit 只读复核；source-edit 可维护的导出源
    ├── 1.x：gui_guider.*、setup_scr_*.c、events_init.*、widgets_init.*
    └── 2.x：gg_utils.*、screens/、events/、assets/
```

#### 4.2 按任务类型的代码边界
- `project-edit`：存在 `.guiguider` 的原始工程中，`generated/` 下的 C/H、图片、字体、资源清单和构建文件只读，只用于句柄、资源和生成结果复核；设计改动写回 `.guiguider`，适配逻辑写入 `custom/` 或适配层。没有 `.guiguider` 时，不能从 `generated/` 反推设计源，应停止并报告。
- `source-edit`：`generated/` 与 `custom/` 可读写，可维护 1.x 的 `gui_guider.*`、`setup_scr_*.c`、`events_init.*`、`widgets_init.*`，以及 2.x 的 `gg_utils.*`、`screens/`、`events/`、`assets/`、资源和构建文件。保留 `.guiguider` 的原始工程再次导出时，这些 `generated/` 修改可能被覆盖。
- 无论工程状态，页面布局、控件树、样式和设计事件结构都应回到 `project-edit` 修改设计源，不能用 source-edit 的生成代码代替设计源。
- `custom/` 下的 `custom.c`、`custom_file.c`、`lv_conf_ext.h`，以及 `ui_init.c/h`、`lv_conf_custom.h` 按任务需要维护；共享数据和平台适配仍应与生成界面解耦。

#### 4.3 迭代修改流程
1. UI布局、样式、控件增删：按 `guider-engineering` 的 project-edit 规则修改设计源，再重新生成
2. 数据绑定、业务逻辑和平台适配：按 `guider-engineering` 的 source-edit 规则修改 `custom/`、`generated/` 和适配层；若保留 `.guiguider`，记录重新导出覆盖风险
3. 导出后验证：按版本检查 `lv_ui` 或 `gg_ui_t` 句柄，并同步适配代码
4. 重大改版前备份 `custom/` 和记录生成头文件接口，防止句柄不兼容

### 5. 模块间通信规范

> IPC选型速查表详见 `coding-rtthread-style` Skill §3.1。本节聚焦架构层面的通信模式。

#### 5.1 IPC通信模式（架构视角）

#### 5.2 数据池通信模式
```
通信模块(写入) ──[互斥锁保护]──> 数据池(全局缓存) ──[互斥锁保护]──> UI线程(读取)
                                      ↓
                               存储线程(读取)
```

**设计原则：**
- 数据池为唯一数据中台，所有模块通过数据池交互
- 写入时加互斥锁，读取时加互斥锁
- 使用局部变量临时存储读取的数据，避免持锁期间执行耗时操作

### 6. 跨平台适配规范

> 完整OSAL速查表见 `coding-rtthread-style` Skill。本节聚焦分层架构中的OSAL使用原则。

#### 6.1 OS抽象层（OSAL）使用原则
所有OS相关操作必须通过OSAL接口，禁止直接调用内核API。常用映射：

| 功能 | OSAL接口 | 禁止用法 |
| :--- | :--- | :--- |
| 延时 | aicos_msleep() | rt_thread_mdelay() / vTaskDelay() |
| 互斥锁 | aicos_mutex_t | rt_mutex_t / SemaphoreHandle_t |
| 信号量 | aicos_sem_t | rt_sem_t / SemaphoreHandle_t |
| 线程 | aicos_thread_create() | rt_thread_create() / xTaskCreate() |
| 内存 | aicos_malloc() | rt_malloc() / pvPortMalloc() |

> 注意：Skill示例中为便于说明使用了RT-Thread原生API，生产代码应替换为OSAL接口。

#### 6.2 驱动移植原则
- HAL层代码可直接移植到其他平台（不依赖OS）
- DRV层代码需适配目标平台的驱动框架（修改OSAL调用）
- 应用层代码仅需修改数据池定义和通信协议（不依赖硬件）

### 7. 初始化顺序规范

#### 7.1 系统启动顺序
```
1. 内核初始化 (kernel init)
2. 设备驱动初始化 (drv init - INIT_COMPONENT_EXPORT)
3. 文件系统挂载 (dfs mount)
4. UI框架初始化 (lvgl init)
5. 业务模块初始化 (app init - INIT_APP_EXPORT)
   5.1 CAN通信模块初始化
   5.2 存储模块初始化（加载参数）
   5.3 UI初始化（ui_init）
   5.4 输入模块初始化
6. 任务启动 (thread create)
```

#### 7.2 模块初始化级别
- `INIT_BOARD_EXPORT`：板级初始化（时钟、GPIO配置）
- `INIT_COMPONENT_EXPORT`：组件初始化（驱动、文件系统）
- `INIT_APP_EXPORT`：应用初始化（业务模块）

## 输出要求
1. 新增模块必须说明：所属层级、职责边界、依赖关系、初始化顺序
2. 模块间通信必须说明：IPC选型、数据流向、互斥锁保护
3. GUI Guider工程必须说明：隔离机制、迭代修改流程、兼容性注意事项
4. 跨平台适配必须说明：OSAL接口使用、驱动移植原则

## 典型架构示例

### 应用层模块划分（推荐）
```
app_1048_rgb_long/
├── user_can.c              # CAN通信模块（高优先级线程，中断+信号量驱动）
├── user_io.c               # 输入模块（中优先级线程，定时器轮询）
├── user_file.c             # 存储模块（低优先级线程，事件驱动）
└── Kconfig                 # 模块配置菜单
```

### 业务层与Guider隔离（推荐）
```
guider_1048_rgb_long_demo/
├── custom/custom.c         # 数据池定义：meter_can_struct、meter_btn_struct
├── custom/custom_file.h    # 图片路径：IMG_PATH_LIGHT_xxx、IMG_PATH_DARK_xxx
├── generated/gui_guider.h  # 1.x 的 lv_ui，或 2.x 的 gg_ui_t/gg_screen_* 结构
└── ui_init.c               # 初始化：custom_init → setup_ui → events_init
```

### 数据池通信模式（推荐）
```c
/* CAN线程写入数据池 */
can_meter_mutex_take();
g_meter_can_variable.speed = l_mcu1.bus_speed;
can_meter_mutex_release();

/* UI定时器读取数据池 */
can_meter_mutex_take();
meter_can_struct meter_can_variable = g_meter_can_variable; // 局部变量拷贝
can_meter_mutex_release();

/* 使用局部变量刷新UI */
lv_user_img_speed_show(meter_can_variable.speed, ...);
```

### 模块间IPC通信（推荐）
```c
/* CAN接收中断 → 接收线程（信号量） */
rt_sem_release(&can_rx_sem);  // 中断释放信号量
rt_sem_take(&can_rx_sem, RT_WAITING_FOREVER);  // 线程等待

/* 里程更新 → 存储线程（事件组） */
rt_event_send(g_file_event, EVENT_ODO_SAVE);  // CAN线程发送事件
rt_event_recv(g_file_event, EVENT_ODO_SAVE, RT_EVENT_FLAG_OR | RT_EVENT_FLAG_CLEAR, ...);  // 存储线程等待

/* 数据池访问（互斥锁） */
can_meter_mutex_take();  // 加锁
meter_can_variable = g_meter_can_variable;  // 拷贝数据
can_meter_mutex_release();  // 解锁
```
