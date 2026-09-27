---
name: "coding-rtthread-style"
description: "RT-Thread 任务、优先级、线程、IPC、LVGL 协同、内存和初始化规范。Use when Codex designs, implements, reviews, or debugs RT-Thread tasks, semaphores, mutexes, message queues, event sets, scheduling, or startup code."
---

# RT-Thread系统开发规范

## 适用范围
仅在检测到 RT-Thread 头文件/API、`Kconfig`/`SConscript` RT-Thread 工程或用户明确要求 RT-Thread 开发时启用。本 Skill 不适用于 FreeRTOS、裸机或 Qt；其他 RTOS 需要依据其自身 API 和项目约定。

## 触发场景
- 任务创建、优先级划分、调度周期设计
- 信号量、互斥锁、消息队列、事件组选型
- 内存管理、堆栈分配与溢出防护
- 系统调试、代码评审、线程安全分析

> 本 Skill 聚焦通用 RT-Thread 模式。业务领域实现详见：
> - CAN收发/解析 → `can-bus-dev` Skill
> - 数据池读写 → `meter-datapool` Skill
> - 存储写入 → `meter-storage` Skill
> - UI刷新/LVGL → `guider-engineering` Skill 的 source-edit 参考文件
> - 架构分层/OSAL/初始化 → `embedded-arch` Skill

## 核心执行规范

### 1. 任务划分标准（仪表推荐架构）
#### 1.1 优先级分层（RT-Thread 中数字越小优先级越高；具体范围以 `RT_THREAD_PRIORITY_MAX` 为准）
| 层级 | 优先级范围 | 任务类型 | 示例 |
|------|-----------|---------|------|
| 最高 | 0~3 | 系统时基、关键实时线程 | CAN接收线程 |
| 高 | 4~7 | 通信收发、协议解析 | CAN发送线程 |
| 中 | 8~12 | 业务逻辑、数据池更新 | 车速里程计算、告警判断 |
| 低 | 13~16 | UI刷新（LVGL timer） | LVGL定时器回调 |
| 最低 | 17~24 | 后台存储、日志 | 文件写入线程 |

#### 1.2 推荐任务划分
按业务模块拆分任务，单一任务单一职责，禁止大而全的超级任务：
1. **系统时基任务**：最高优先级，负责毫秒级计时、超时检测
2. **通信接收任务**：高优先级，处理CAN/RS485/一线通帧接收与初步校验
3. **业务逻辑任务**：中优先级，车速里程计算、告警判断、数据池更新
4. **LVGL刷新任务**：低优先级，调用 `lv_timer_handler`、UI刷新，固定周期调度
5. **存储后台任务**：最低优先级，参数持久化、故障记录，异步写入Flash

#### 1.3 调度设计原则
1. 周期任务统一用定时器或系统时基调度，禁止空循环软件延时
2. 通信任务推荐中断+信号量驱动（ISR仅释放信号量），不采用轮询模式
3. 存储任务推荐事件组驱动，不主动轮询数据池
4. 任务栈大小按实际使用量预留30%余量，关键任务开启栈溢出检测

### 2. 线程创建代码模板
新建业务线程时统一使用以下模板，将 `xx` 替换为业务模块名：

```c
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <rtthread.h>
#include "rtdevice.h"
#include <aic_core.h>
#include "ulog.h"

/* user_xx 线程参数 */
#define THREAD_USER_XX_PRIORITY         18      // 线程优先级，数字越大优先级越高
#define THREAD_USER_XX_STACK_SIZE       1024    // 线程堆栈大小，决定了线程可以使用的内存空间
#define THREAD_USER_XX_TIMESLICE        5       // 线程时间片，决定了线程在调度时能占用CPU的最长时间

/* user_xx 线程变量 */
static rt_thread_t user_xx_thread = RT_NULL;    // user_xx 线程
static struct rt_mutex user_xx_mutex;           // user_xx 数据互斥锁

/* 线程入口函数，这是线程启动后执行的函数 */
static void user_xx_thread_entry(void *param)
{

    while(1) // 无限循环，使线程持续运行
    {
        
        rt_thread_mdelay(20);
    }
}

/* 初始化xx的函数，在系统启动时调用 */
static int usr_xx_init(void)
{
    rt_err_t ret;

    /* 初始化 user_xx 数据互斥锁 */
    ret = rt_mutex_init(&user_xx_mutex, "user_xx_mutex", RT_IPC_FLAG_PRIO);
    if (ret != RT_EOK)
    {
        LOG_E("init user_xx_mutex failed!\n");
        return RT_ERROR;
    }

    /* 创建线程，名称是 user_xx_thread，入口是 user_xx_thread_entry */
    user_xx_thread = rt_thread_create("user_xx_thread",             // 线程名称
                                  user_xx_thread_entry, RT_NULL,    // 线程入口函数和参数
                                  THREAD_USER_XX_STACK_SIZE,        // 线程堆栈大小
                                  THREAD_USER_XX_PRIORITY,          // 线程优先级
                                  THREAD_USER_XX_TIMESLICE);        // 线程时间片
    if (user_xx_thread == RT_NULL) // 如果线程创建失败，打印错误信息并返回
    {
        LOG_E("Failed to create the user_xx_thread\n");
        return RT_ERROR; // 线程创建失败，直接返回，防止对无效的线程进行操作
    }

    /* 如果获得线程控制块，启动这个线程 */
    rt_thread_startup(user_xx_thread); // 启动线程，使其开始执行
    return RT_EOK; // 返回RT_EOK表示成功
}

INIT_APP_EXPORT(usr_xx_init); // 导出函数自动运行，在系统初始化时调用usr_xx_init函数
```

**模板使用说明**：
1. 将所有 `xx` 替换为业务模块名（如 `can`、`ui`、`batt` 等）
2. 根据业务需求调整优先级、栈大小、时间片参数（参考 §1.1 优先级分层表和 §5.2 栈大小参照表）
3. 线程入口函数内实现具体业务逻辑，禁止在线程内使用空循环软件延时
4. 共享数据访问必须通过互斥锁保护，防止数据竞争
5. 所有错误路径必须有日志输出和错误返回值

### 3. IPC通信选型
#### 3.1 选型速查表
| 场景 | 推荐IPC | 选型理由 |
|------|---------|----------|
| 中断 → 线程同步 | **信号量** | 最轻量，ISR只能调用非阻塞释放接口 |
| 线程间数据同步（多事件） | **事件组** | 支持多事件位，支持OR/AND组合等待 |
| 资源互斥访问 | **互斥锁** | 支持优先级继承，防优先级反转 |
| 批量数据传递 | **消息队列** | 支持多字节数据拷贝传递 |

#### 3.2 信号量：ISR驱动模式
**核心原则**：中断回调仅做 `rt_sem_release`，所有解析逻辑放在独立线程中。禁止在中断回调中调用 `rt_thread_mdelay`、`LOG_*`、协议解析。

> 完整代码示例见 `can-bus-dev` Skill §3.1（CAN接收中断→信号量→接收线程三层架构）。

#### 3.3 互斥锁：数据池保护模式
**核心原则**：
- 持锁期间仅做数据拷贝，禁止在锁内做IPC、文件操作、LVGL函数调用
- 每个数据域配备独立互斥锁，避免锁粒度过大
- 禁止嵌套持锁（不同类别的锁不可同时持有），防止死锁
- 互斥锁初始化必须使用 `RT_IPC_FLAG_PRIO`（优先级继承）

**锁内拷贝→锁外操作**（核心模式）：
```c
/* 1. 锁内仅拷贝数据 */
mutex_take();
local_copy = g_shared_data;
mutex_release();

/* 2. 锁外执行耗时操作（LVGL刷新/文件写入） */
lv_xxx_show(local_copy.value, ...);
```

> 完整代码示例见 `meter-datapool` Skill §5（互斥锁封装+读写模式）、`can-bus-dev` Skill §4.2（持锁原则+锁外事件通知）。

#### 3.4 事件组：异步通知模式
**核心原则**：
- 事件触发方式统一使用 `RT_EVENT_FLAG_OR | RT_EVENT_FLAG_CLEAR`
- 发送端（高优先级）仅设置事件位，不执行实际写操作
- 接收端（低优先级）阻塞等待，收到后执行耗时操作

> 完整代码示例见 `meter-storage` Skill §3（事件定义→发送→阻塞等待→文件写入）。

### 4. LVGL任务协同
1. LVGL所有操作必须在专属UI任务中执行，禁止在通信任务、中断中直接操作控件
2. UI刷新通过 `lv_timer` 驱动（主页200ms，设置页500ms）
3. 定时器生命周期管理：`LV_EVENT_SCREEN_LOADED` 创建 → `LV_EVENT_SCREEN_UNLOADED` 删除
4. 定时器回调中使用局部变量拷贝数据池数据，持锁时间最小化

> 完整实现见 `guider-engineering` Skill 的对应 source-edit 参考文件（数据绑定、定时器回调和主题切换）。

### 5. 内存与资源管理
#### 5.1 分配策略
1. 优先使用静态内存分配（全局数组、栈变量），动态内存仅用于系统初始化阶段
2. 动态申请内存必须判空，释放后置空，禁止野指针
3. 所有任务、IPC对象必须有明确的生命周期，禁止资源泄漏

#### 5.2 栈大小参照表
| 线程类型 | 推荐栈大小（字节） | 说明 |
|----------|------------------|------|
| 简单通信收发 | 1024 ~ 1536 | CAN/UART收发线程 |
| 协议解析 | 1536 ~ 2048 | 含解析逻辑、数据池写入 |
| 业务逻辑 | 2048 ~ 3072 | 含计算、交互 |
| 文件存储 | 4096 ~ 6144 | 文件系统操作栈开销大 |
| LVGL UI | 4096 ~ 8192 | LVGL渲染栈开销大 |

#### 5.3 线程命名约定
| 元素 | 命名规则 | 示例 |
|------|---------|------|
| 线程名称 | `模块_功能` | `can_com_rx`、`file_thread` |
| 线程入口函数 | `模块_功能_thread_entry` | `can_rx_thread_entry` |
| 线程变量 | `模块_功能_thread` | `can_rx_thread`、`file_thread` |
| 互斥锁变量 | `模块_mutex` | `can_history_mutex`、`user_io_mutex` |
| 互斥锁初始化名 | 可缩写 | `"hist_mutex"` 对应 `history_mutex` |
| 信号量变量 | `模块_方向_sem` | `can_rx_sem` |
| 事件组变量 | `g_模块_event` | `g_file_event` |

### 6. 初始化顺序
| 宏 | 初始化阶段 | 典型用途 |
|----|-----------|----------|
| `INIT_BOARD_EXPORT` | 板级初始化（最早） | 时钟、GPIO配置 |
| `INIT_COMPONENT_EXPORT` | 组件初始化 | 驱动、文件系统 |
| `INIT_APP_EXPORT` | 应用初始化 | 业务模块（CAN/存储/UI/输入） |

**启动顺序**：内核 → 驱动(INIT_COMPONENT) → 文件系统挂载 → LVGL初始化 → 业务模块(INIT_APP) → 线程启动。

> 详细启动顺序和OSAL兼容层见 `embedded-arch` Skill §6~7。

### 7. 常见设计模式速查
| 模式 | 一句话描述 | 详见 |
|------|-----------|------|
| ISR→信号量→线程 | 中断只释放信号量，线程做所有逻辑 | can-bus-dev §3.1 |
| 锁内拷贝→锁外操作 | 持锁仅做数据拷贝，锁外执行耗时操作 | meter-datapool §5 |
| 事件驱动写入 | 高优先级发事件，低优先级执行写入 | meter-storage §3 |
| 计数器分频 | 单定时器+计数器实现多周期调度 | can-bus-dev §3.2 |
| 页面生命周期管理 | SCREEN_LOADED创建timer，UNLOADED删除 | guider-engineering source-edit 参考文件 |
| 故障码偏移映射 | 不同来源故障码+偏移量区分优先级 | can-bus-dev §6 |

### 8. 反面模式与常见错误
| 反面模式 | 错误示例 | 正确做法 |
|----------|---------|---------|
| 中断中阻塞延时 | ISR内调用 `rt_thread_mdelay` | ISR仅释放信号量，线程中延时等待 |
| 中断中打印日志 | ISR内调用 `LOG_E` | 将日志移到线程中输出 |
| 锁内调用LVGL | 持锁期间调用 `lv_image_set_src` | 锁内拷贝数据，锁外调用LVGL |
| 锁内发事件 | 持锁期间调用 `rt_event_send` | 先释放锁，再发送事件 |
| 嵌套持锁 | 同时持有 `meter_mutex` 和 `history_mutex` | 每次只持一把锁，用完释放 |
| 空循环延时 | `for(int i=0;i<1000000;i++);` | 使用 `rt_thread_mdelay` 或定时器 |
| 未判空启动 | `rt_thread_create` 后直接 `startup` | 检查返回值是否为 `RT_NULL` |
| 栈溢出 | 栈上定义大数组 `uint8_t buf[4096]` | 改为全局静态分配或堆分配 |

## 输出要求
1. 任务设计必须说明优先级、栈大小、调度周期、核心职责
2. IPC使用必须说明选型理由与同步时序
3. 涉及内存操作必须提示风险与校验方法
4. 新创建的线程必须对齐 §2 代码模板，说明参数调整依据
