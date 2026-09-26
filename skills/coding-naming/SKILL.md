---
name: "coding-naming"
description: "C/C++ 标识符、类型、宏和公共 API 的项目命名规范，兼顾嵌入式仪表模块前缀与 Qt 项目边界。Use when Codex creates, modifies, reviews, or refactors C/C++ names, public APIs, types, enums, macros, or modules."
---

# C/C++项目命名规范

## 适用范围
在生成或修改 C/C++ 标识符、公共 API、类型、宏，或进行命名审查时启用。嵌入式仪表项目可采用本文件的模块/作用域/类型前缀；Qt 项目必须优先遵循 Qt 和现有项目命名，不强制套用仪表匈牙利命名法。

## 触发场景
- 新建变量、函数、结构体、枚举、宏定义
- 代码评审中命名合规性检查
- 重构代码、对齐命名规范
- 新增模块、定义公共API

## 核心执行规范
### 1. 命名总公式（强制）
**[模块前缀]_[作用域前缀]_[类型前缀]_语义名_[业务后缀]**

示例：`met_g_u8_vehicle_speed_sta`

### 2. 模块前缀表（项目强制）
| 前缀 | 对应模块 | 说明 |
| :--- | :--- | :--- |
| met | 仪表业务总控 | 车速、里程、工况、告警逻辑 |
| ui | LVGL界面模块 | 页面、控件、动画、UI刷新 |
| can | CAN通信模块 | 报文收发、过滤、协议解析 |
| rs485 | RS485通信模块 | 串口收发、Modbus/自定义协议 |
| onewire | 一线通通信模块 | 单总线协议、控制器/电池数据 |
| batt | 电池管理模块 | 电压、电量、充电、故障 |
| drv | 底层驱动模块 | GPIO、UART、ADC、定时器等 |
| sys | 系统内核模块 | RT-Thread任务、时基、内存管理 |
| dat | 数据池模块 | 全局数据缓存、统一数据接口 |

### 3. 作用域前缀（不可省略）
| 前缀 | 定义 | 示例 |
| :--- | :--- | :--- |
| g_ | 全局变量，跨文件可见 | `can_g_u8_rx_flg` |
| s_ | 静态变量，文件/函数内可见 | `sys_s_u32_run_tick` |
| l_ | 局部变量，函数栈内生效 | `batt_l_f32_volt_val` |

### 4. 类型前缀（强制匹配stdint）
| 前缀 | 对应类型 | 前缀 | 对应类型 |
| :--- | :--- | :--- | :--- |
| u8 | uint8_t | s8 | int8_t |
| u16 | uint16_t | s16 | int16_t |
| u32 | uint32_t | s32 | int32_t |
| f32 | float | p_ | 指针类型（叠加使用） |

**指针叠加示例：**
- `uint8_t *pu8_buf` — u8类型指针
- `met_speed_data_t *pst_speed` — 结构体指针

### 5. 业务后缀表
| 后缀 | 含义 | 示例 |
| :--- | :--- | :--- |
| _flg | 事件标志位 | `can_g_u8_rx_flg` |
| _sta | 运行状态 | `met_g_u8_work_sta` |
| _en | 功能使能 | `ui_g_u8_screen_en` |
| _err | 故障标志 | `batt_g_u8_volt_err` |
| _cnt | 计数器 | `drv_s_u8_debounce_cnt` |
| _tick | 系统时基 | `sys_g_u32_refresh_tick` |
| _thr | 阈值参数 | `met_g_u16_speed_alarm_thr` |

### 6. 函数命名规范
#### 6.1 公共API（LVGL风格）
- 公共API以模块缩写开头，后跟动作和主题
- 格式：`模块_动作_主题`，动词开头
- 构造类用 `_create`，析构用 `_delete`
- 设置类用 `_set_`，获取类用 `_get_`

**示例：**
```c
int32_t can_meter_init(void);           /* CAN模块初始化 */
void lv_obj_create(lv_obj_t *parent);  /* 创建LVGL对象 */
uint16_t met_get_speed(void);           /* 获取车速 */
```

#### 6.2 私有静态函数
- 文件内私有函数加 `_` 前缀标记
- 必须用 `static` 修饰

**示例：**
```c
static void _can_rx_parse(void);       /* CAN接收解析，仅本文件调用 */
static void _lv_obj_draw(lv_event_t *e); /* LVGL对象绘制回调 */
```

#### 6.3 推荐动词表
init / deinit / get / set / calc / parse / refresh / clear / check / reset / send / receive / create / delete

### 7. 类型定义规范
#### 7.1 结构体
- 使用 `typedef struct`，全小写下划线，类型名以 `_t` 结尾
- 通信帧、存储结构体强制 `__attribute__((packed))` 避免对齐

```c
typedef struct {
    uint16_t u16_speed;
    uint32_t u32_odo;
} met_speed_data_t;
```

#### 7.2 枚举
- 使用 `typedef enum`，类型名以 `_e` 结尾
- 成员全大写，加模块前缀
- 末尾加 `_MAX` 成员用于范围校验

```c
typedef enum {
    MET_GEAR_PARK = 0,
    MET_GEAR_DRIVE,
    MET_GEAR_REVERSE,
    MET_GEAR_MAX
} met_gear_e;
```

#### 7.3 宏定义
- 全大写下划线分隔
- 数值后缀加 U/UL/F 明确类型

```c
#define MET_SPEED_MAX      120U    /* 车速最大值 */
#define MET_TIMEOUT_MS     1000UL  /* 超时时间 */
```

### 8. 允许的缩写表（可扩展）
| 缩写 | 全称 | 备注 |
|------|------|------|
| dsc | descriptor | 描述符/私有数据 |
| param | parameter | 参数 |
| indev | input device | 输入设备 |
| anim | animation | 动画 |
| buf | buffer | 缓冲区 |
| str | string | 字符串 |
| min/max | minimum/maximum | 最小/最大 |
| alloc | allocate | 分配 |
| ctrl | control | 控制 |
| pos | position | 位置 |
| cfg | config | 配置 |
| init / deinit | initialize / deinitialize | 初始化/反初始化 |
| dev | device | 设备 |
| drv | driver | 驱动 |
| intf | interface | 接口 |
| mem | memory | 内存 |
| cb | callback | 回调函数 |
| odo | odometer | 总里程 |
| trip | trip meter | 小计里程 |
| batt | battery | 电池 |
| curr | current | 电流 |
| volt | voltage | 电压 |
| temp | temperature | 温度 |

**注意**：新增缩写需在本文件登记，禁止私自使用未定义缩写。

### 9. 全局禁止项
1. 禁止变量无作用域前缀、类型前缀与实际类型不匹配
2. 禁止函数名词开头、语义笼统
3. 禁止枚举不带 `_e` 后缀、宏定义小写
4. 禁止 typedef 类型不带 `_t` 后缀
5. 禁止自创未定义前缀后缀、使用拼音歧义缩写
6. 禁止单字母变量名（循环变量 i/j/k 除外）

## 输出要求
1. 所有命名必须对照本规范校验，不符合的立即整改
2. 交付代码末尾附：【命名自检结论：已对照命名规范全部校验整改完毕，所有命名符合项目规范】
3. 新增模块/API时，说明命名规则的选用依据
