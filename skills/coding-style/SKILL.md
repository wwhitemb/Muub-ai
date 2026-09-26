---
name: "coding-style"
description: "C/C++ 文件结构、格式、Doxygen 注释、类型、头文件、错误路径和代码审查规范。Use when Codex creates or modifies C/C++ modules, headers, public APIs, comments, formatting, or performs a style review."
---

# C/C++编码风格与注释规范

## 适用范围
在新建或修改 C/C++ 模块、公共 API、代码格式、注释或进行代码审查时启用。具体缩进、文件结构、构建格式和 Qt/LVGL 约定以当前项目既有风格为准；本 Skill 不覆盖 RT-Thread、Qt 或业务领域的专用设计。

## 触发场景

- 新建模块、编写公共API头文件
- 代码评审、格式规范化整改
- 编写SDK级别的可复用组件
- 需要生成API文档的模块开发

> **与其他Skill的边界**：
>
> - 命名规则 → 见 `coding-naming` Skill
> - 安全编码 → 见 `coding-c-safety` Skill
> - 本Skill聚焦：代码格式、注释规范、编码约定

## 核心执行规范

### 0. 注释同步工作流

将注释视为实现的一部分，不得把“功能先完成、注释后补”作为默认流程。对每个新增或修改的函数，按以下顺序执行：

1. 编码前列出本次变更中的公共 API、回调、状态切换、资源生命周期、边界与错误路径。
2. 编写对应代码块时同步添加注释；除非代码尚未稳定，不得将关键注释留为待办。
3. 修改完成后只检查本次 diff：逐项确认上述对象均已有恰当注释，或在代码自解释且不属于第 1.5 节强制项时记录为无需注释。
4. 交付前从调用方视角复读公共 API 与回调：调用前提、触发来源、状态结果和失败后果必须可由注释与接口直接得知。

不得以“最小改动”为由省略新增行为需要的注释；最小改动是避免无关重构，不是降低可维护性要求。

#### 0.1 注释语言优先级

注释默认使用中文。只有用户明确要求其他语言注释时，才允许本次新增或修改的注释使用其他语言；不得因代码、SDK、示例、目标文件既有注释或模型默认习惯改用英文。该规则覆盖 Doxygen、块注释、行内注释、`@brief`、`@param` 和 `@return`。既有英文注释仅在用户要求统一翻译或本次必须修改该注释时才处理，避免无关的全文件翻译。

### 1. Doxygen注释规范

#### 1.1 文件头注释

每个 .c 和 .h 文件开头必须包含文件头注释：

```c
/**
 * @file    user_can.c
 * @brief   CAN通信模块，负责CAN报文收发与协议解析
 * @author  Muub
 * @date    2026-07-15
 */
```

#### 1.2 函数注释（头文件公共API）

头文件中每个公共函数必须有完整Doxygen注释：

```c
/**
 * @brief   初始化CAN通信模块
 * @param   baudrate: 波特率，单位bps，范围50000~1000000
 * @return  0: 成功, -1: 失败
 * @note    必须在系统初始化后调用
 */
int32_t can_meter_init(uint32_t baudrate); // 初始化CAN通信模块
```

#### 1.3 结构体与枚举注释

```c
/**
 * @brief   车速数据结构体
 */
typedef struct {
    uint16_t    u16_speed;      /* 当前车速，单位0.1km/h */
    uint32_t    u32_odo;        /* 总里程，单位0.1km */
    uint8_t     u8_valid_flg;   /* 数据有效标志 */
} met_speed_data_t; // 车速数据结构体

/**
 * @brief   档位枚举
 */
typedef enum {
    MET_GEAR_PARK = 0,      /* P档停车 */
    MET_GEAR_DRIVE,         /* D档前进 */
    MET_GEAR_REVERSE,       /* R档倒车 */
    MET_GEAR_MAX            /* 枚举最大值 */
} met_gear_e; // 档位枚举
```

#### 1.4 代码内注释

- 注释说明**为什么**这样做，而非描述代码做了什么
- 引用变量时使用反引号括起来：`/* 更新 \`g\_enc\_cnt\` 的值，防止溢出 \*/`
- 允许简短的代码摘要注释，如 `/* 计算新坐标 */`
- 复杂算法添加步骤说明注释

#### 1.5 行内注释覆盖要求

生成或修改C代码时，以下代码必须添加行内注释：

1. 所有用户可配置宏必须说明用途、单位、取值范围或默认行为。
2. 所有线程参数宏必须说明优先级、栈大小、时间片和调度周期。
3. 所有状态变量赋值必须说明状态变化的业务含义。
4. 所有资源申请、释放、注册、注销操作必须说明生命周期和失败后果。
5. 所有条件分支必须在分支意图不明显时说明判断目的。
6. 所有回调函数必须说明触发来源和回调中允许执行的操作。
7. 所有通信连接、订阅、发布、重连和超时处理必须说明时序和失败处理。
8. 所有边界判断、长度检查、空指针检查和错误返回必须说明防护目的。
9. 复杂函数必须按“准备、执行、清理、结果处理”等步骤添加分段注释。
10. 不要求机械地为每一条简单赋值语句添加注释；但不得遗漏会影响理解、调试或安全性的关键语句。

行内注释应说明“为什么这样做、改变了什么状态、失败时会怎样”，禁止只重复代码本身的含义。

推荐格式：

```c
/* 默认关闭原始MQTT报文输出，避免大量日志影响通信线程和系统调度。 */
#define MQTT_RAW_MESSAGE_LOG_ENABLE   0

if (mqtt_client == RT_NULL) {
    /* MQTT客户端未创建时无法继续连接，直接返回并保留错误状态。 */
    return -RT_ENOMEM;
}
```

#### 1.6 行内注释自检清单

代码生成完成后必须检查：

- 配置宏是否都有用途和单位说明；
- 线程、信号量、互斥锁等RT-Thread对象是否说明生命周期；
- 网络连接和MQTT状态切换是否说明原因；
- 错误分支是否说明失败影响；
- 缓冲区和长度判断是否说明边界目的；
- 清理代码是否说明释放对象和避免资源泄漏的原因；
- 注释是否解释“为什么”，而不是简单翻译代码。

#### 1.7 按变更类型的完成门禁

完成 C/C++ 代码变更前，必须针对实际改动逐项检查：

| 变更对象 | 必需注释内容 |
| --- | --- |
| 新增或修改的公共 API | Doxygen：用途、参数约束、返回值/失败语义、调用前提与副作用。 |
| 回调、事件处理或定时器 | 触发来源、执行上下文、允许的操作，以及不应在其中执行的阻塞或生命周期操作（若适用）。 |
| 状态、焦点、模式或组切换 | 切换原因、切换后谁拥有该状态、恢复条件和退出路径。 |
| 资源或注册关系 | 创建/注册者、释放/注销者、失败时是否已部分生效。 |
| 输入校验和错误路径 | 防护的边界条件及失败对调用方或系统状态的影响。 |

表中未命中的简单局部计算无需凑注释。代码评审或自检发现某项缺失时，应先补注释再宣称实现完成。

### 2. 代码格式规范

#### 2.1 缩进与换行

- 使用**4个空格**缩进，禁止使用制表符Tab
- 单行代码最长不超过**120字符**，逻辑运算符后换行
- 函数主括号在新行，if/for/while等语句括号内联开始

```c
/* 函数括号在新行 */
void can_meter_init(void)
{
    /* if/for/while 括号内联 */
    if (condition) {
        do_something();
    } else {
        do_other();
    }
}
```

#### 2.2 空格规则

- 运算符两侧加空格：`a = b + c`，而非 `a=b+c`
- 括号内侧不加空格：`func(a, b)`，而非 `func( a, b )`
- 逗号后加空格：`func(a, b)`，而非 `func(a,b)`
- 指针星号靠类型：`uint8_t *pu8_buf`，而非 `uint8_t * pu8_buf`

#### 2.3 文件编码

- 文件编码强制使用 **UTF-8**
- 换行符使用 **LF**（Unix风格）

### 3. 编码约定

#### 3.1 函数设计

- 函数应**单一职责**，一个函数只做一件事
- 函数圈复杂度控制在**10以内**，避免巨型函数
- 尽可能使用 `static` 关键字限制作用域，仅暴露必要的公共API
- 私有静态函数加 `_` 前缀标记：`static void _can_rx_parse(void)`
- 函数参数命名应清晰明确，避免单字母参数（循环变量i/j/k除外）
- 参数个数控制在5个以内，超过则用结构体封装

#### 3.2 变量声明

- 在**需要的地方**声明变量，不要全部在函数开头声明
- 使用最小必要的作用域，能在块内声明就不提到函数级
- 文件级变量（函数外部）必须是 `static`，避免不必要的全局变量
- 全局变量通过封装的 get/set 函数访问，不直接暴露
- 禁止声明未初始化的变量（除非立即被赋值）

#### 3.3 类型与常量

- 强制使用 `<stdint.h>` 定宽类型（uint8\_t、int32\_t等），禁止int/long
- 推荐使用 **enum** 而非宏定义来表示一组相关的常量
- 宏定义全大写下划线，数值后缀加 U/UL/F 明确类型
- 优先使用 `typedef struct` / `typedef enum`，类型名以 `_t` / `_e` 结尾
- 禁用隐式类型转换，必须显式强转

#### 3.4 头文件规范

- 所有头文件必须包含 `#ifndef` 格式防重复包含宏
- 公用头文件应包含 `extern "C"` 块以支持C++编译
- 头文件只放**声明**，不放实现（内联函数除外）
- 优先前向声明，减少头文件嵌套包含
- 禁止在头文件中定义全局变量

**标准头文件模板：**

```c
#ifndef USER_CAN_H
#define USER_CAN_H

#ifdef __cplusplus
extern "C" {
#endif

/* 头文件内容 */

#ifdef __cplusplus
}
#endif

#endif /* USER_CAN_H */
```

#### 3.5 数组参数约定

- 传递数组时**同时传递大小参数**，不依赖调用方约定
- 参数顺序：目标数组在前，大小在后

```c
/* 正确：同时传数组和大小 */
void can_frame_unpack(uint8_t *pu8_buf, uint32_t u32_len);
```

#### 3.6 指针类型化

- 优先使用**具体类型指针**，而非 `void *`
- 结构体指针优于单独参数传递，减少参数个数
- 指针解引用前必须判空（安全规则详见 embedded\_c\_safety Skill）

### 4. 条件编译规范

- 条件编译使用统一配置宏前缀（`AIC_USE_`、`CONFIG_`）
- `#else` / `#endif` 后添加注释标记对应条件：`#endif /* AIC_USE_CAN */`
- 条件编译块保持适当缩进
- 条件编译嵌套不超过**2层**，超出则重构为独立配置

```c
#ifdef AIC_USE_CAN
    /* CAN功能代码 */
    #ifdef AIC_USE_CAN_FD
        /* CAN FD 扩展 */
    #endif /* AIC_USE_CAN_FD */
#else
    /* 降级处理：返回错误码或空实现 */
#endif /* AIC_USE_CAN */
```

### 5. 完整模块示例

以下为符合本规范的完整模块示例（命名规范详见 coding\_naming Skill）。

#### 5.1 头文件 user\_led.h

```c
/**
 * @file    user_led.h
 * @brief   LED控制模块头文件
 * @author  Muub
 * @date    2024-01-15
 */

#ifndef USER_LED_H
#define USER_LED_H

#ifdef __cplusplus
extern "C" {
#endif

#include <stdint.h>

/**
 * @brief LED颜色枚举
 */
typedef enum {
    LED_COLOR_RED = 0,     /* 红色 */
    LED_COLOR_GREEN,       /* 绿色 */
    LED_COLOR_BLUE,        /* 蓝色 */
    LED_COLOR_MAX          /* 枚举最大值 */
} led_color_e;

/**
 * @brief   初始化LED模块
 * @return  0: 成功, -1: 失败
 */
int32_t user_led_init(void);

/**
 * @brief   设置LED颜色和亮度
 * @param   color: 颜色，见 led_color_e
 * @param   brightness: 亮度，范围0~100
 * @return  0: 成功, -1: 参数错误
 */
int32_t user_led_set(led_color_e color, uint8_t brightness);

#ifdef __cplusplus
}
#endif

#endif /* USER_LED_H */
```

#### 5.2 源文件 user\_led.c

```c
/**
 * @file    user_led.c
 * @brief   LED控制模块实现
 * @author  Muub
 * @date    2024-01-15
 */

#define LOG_TAG "led"
#include "aic_core.h"
#include "user_led.h"

#define LED_BRIGHTNESS_MAX     100U    /* 最大亮度值 */

static uint8_t s_u8_led_brightness;   /* 当前LED亮度 */
static led_color_e s_led_cur_color;   /* 当前LED颜色 */

/**
 * @brief   配置LED硬件PWM
 * @param   duty: PWM占空比
 * @note    内部静态函数，外部不调用
 */
static void _led_pwm_config(uint16_t duty)
{
    /* 配置PWM输出寄存器 */
}

int32_t user_led_init(void)
{
    s_u8_led_brightness = 0U;
    s_led_cur_color = LED_COLOR_RED;

    _led_pwm_config(0U);
    LOG_DBG("led init done");
    return 0;
}

int32_t user_led_set(led_color_e color, uint8_t brightness)
{
    /* 校验参数范围，防止越界 */
    if (color >= LED_COLOR_MAX) {
        LOG_E("invalid color: %d", color);
        return -1;
    }
    if (brightness > LED_BRIGHTNESS_MAX) {
        LOG_E("invalid brightness: %d", brightness);
        return -1;
    }

    s_led_cur_color = color;
    s_u8_led_brightness = brightness;

    /* 亮度线性转换为PWM占空比，分辨率0.1% */
    uint16_t l_u16_duty = (uint16_t)brightness * 10U;
    _led_pwm_config(l_u16_duty);

    return 0;
}
```

## 输出要求

1. 新建模块必须遵循以上格式，头文件和源文件结构对齐示例
2. 公共API必须包含完整Doxygen注释
3. 代码格式按本规范校验，缩进、空格、命名全部对齐
4. 交付时说明本模块与规范的对齐情况
5. 对新增或修改的公共 API、回调、状态切换、资源生命周期和错误路径，交付时说明已检查的注释项；不存在的项明确标为“不适用”。
6. 交付前检查本次新增或修改的注释语言；默认报告“新增/修改注释已使用中文”，只有用户明确指定其他语言时才按该语言生成并报告。

