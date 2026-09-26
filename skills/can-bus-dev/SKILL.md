---
name: "can-bus-dev"
description: "CAN/CAN FD 通信开发与协议解析规范，涵盖驱动初始化、过滤器、报文收发、字节序、位域、DLC、DTC、里程和并发保护。Use when Codex modifies or reviews CAN/CAN FD drivers, frames, filters, protocol parsing, diagnostics, periodic transmission, or bus fault handling."
---

# CAN/CAN FD 总线开发规范

## 适用范围
仅在任务涉及 CAN/CAN FD 报文、驱动、过滤器、协议解析、DTC、周期发送或总线故障处理时启用。RT-Thread API 仅在当前工程确实使用 RT-Thread 时采用；其他平台必须替换为项目实际驱动和同步接口。

> 通用RT-Thread模式（线程模板、IPC选型、命名约定）见 `coding-rtthread-style` Skill。

## 触发场景
- CAN驱动开发、过滤器配置、波特率设置
- CAN报文解析、封装、字节序处理、位域解析
- DTC故障码定义、优先级管理、故障恢复逻辑
- 里程计算、丢帧估算、事件通知机制
- 多任务共享数据保护（互斥锁）
- J1939/自定义CAN协议实现

## 核心执行规范

### 1. 报文与ID管理
**强制要求：**
1. 所有CAN ID、帧格式、周期全部用宏定义集中管理，禁止硬编码
2. 标准帧/扩展帧必须用 `RT_CAN_STDID` / `RT_CAN_EXTID` 明确区分
3. 过滤器配置必须按需分配，禁止全开接收，降低CPU占用
4. 报文ID、信号定义必须配套注释说明：含义、单位、偏移、缩放因子、原始值范围

**代码模板：**
```c
/* ---------- 接收报文 ID (MCU/BMS → METER) ---------- */
#define CAN_ID_MCU1                         0x1801F4EF   /* MCU → METER, 200ms, 8B, 扩展帧 */
#define CAN_ID_MCU2                         0x1802F4EF   /* MCU → METER, 50ms,  8B, 扩展帧 */
#define CAN_ID_MCU3                         0x760        /* MCU → METER, 100ms, 8B, 标准帧 */

/* ---------- 发送报文 ID (METER → TBOX/MCU) ---------- */
#define CAN_ID_METER1                       0x230        /* METER → TBOX, 100ms, 8B, 标准帧 */
#define CAN_ID_METER                        0x1802F5EF   /* METER → MCU, 100ms, 8B, 扩展帧 */

/* ---------- 基础配置 ---------- */
#define CAN_DEV_NAME                 "can0"
#define CAN_BAUDRATE                 CAN500kBaud
```

### 2. 数据解析规范

#### 2.1 字节序解析宏
车载CAN报文普遍采用Intel字节序（Little-Endian，低字节在前），必须统一使用解析宏：

```c
/* 工具宏：解析 intel 字节序 (Little-Endian, 低字节在前) */
#define GET_U16_LE(data, start)   ((uint16_t)((data)[start]) | \
                                   ((uint16_t)((data)[(start) + 1]) << 8))

#define GET_U24_LE(data, start)   ((uint32_t)((data)[start]) | \
                                   ((uint32_t)((data)[(start) + 1]) << 8) | \
                                   ((uint32_t)((data)[(start) + 2]) << 16))

#define GET_U32_LE(data, start)   ((uint32_t)((data)[start]) | \
                                   ((uint32_t)((data)[(start) + 1]) << 8) | \
                                   ((uint32_t)((data)[(start) + 2]) << 16) | \
                                   ((uint32_t)((data)[(start) + 3]) << 24))

/* 工具宏：封装 intel 字节序 */
#define PUT_U16_LE(data, start, val)   do { \
    (data)[start]     = (uint8_t)((val) & 0xFF); \
    (data)[(start)+1] = (uint8_t)(((val) >> 8) & 0xFF); \
} while (0)

#define PUT_U24_LE(data, start, val)   do { \
    (data)[start]     = (uint8_t)((val) & 0xFF); \
    (data)[(start)+1] = (uint8_t)(((val) >> 8) & 0xFF); \
    (data)[(start)+2] = (uint8_t)(((val) >> 16) & 0xFF); \
} while (0)
```

#### 2.2 位域解析规范
按位解析时必须使用带掩码和范围说明的位运算，禁止不加说明的裸位运算：

```c
/* Byte6: 组合信号位域解析 */
l_mcu1.pow_down_flag        = data[6] & 0x01;                /* bit[0]: 降功率标志 */
l_mcu1.mcu_self_check_status = (data[6] >> 1) & 0x07;        /* bit[1:3]: 自检状态 */
l_mcu1.mcu_messageg_counter1 = (data[6] >> 4) & 0x0F;        /* bit[4:7]: 发送计数 */
```

#### 2.3 数据结构定义
协议解析默认使用原始字节数组和显式偏移、掩码、缩放，不把 CAN 报文字节直接映射为 C bit-field。只有在编译器 ABI、字节序和布局已验证，且确实需要固定二进制布局时，才允许对不含 bit-field 的定宽字段使用 `packed` 结构体。

```c
typedef struct __attribute__ (( packed )) {
    uint16_t mcu_motor_dc_volt;             /* Byte0-1: 母线高压 0-300V, raw 0x0000-0xBB8, 分辨率0.1V */
    uint16_t mcu_motor_dc_current;          /* Byte2-3: 母线电流 -300~500A, raw 0x0000-0x1F40, offset=-300，分辨率0.1A */
    uint8_t  mcu_mcu_temp;                  /* Byte4: 控制器温度 -40~210°C, raw 0x00-0xFA, offset=-40 */
    uint8_t  mcu_motor_temp;                /* Byte5: 电机温度 -40~210°C, raw 0x00-0xFA, offset=-40 */
    uint8_t  status;                        /* Byte6: 使用上方掩码解析 bit[0:7]，避免 bit-field 布局依赖 */
    uint8_t  bus_speed;                     /* Byte7: 车速 0-150km/h, raw 0x00-0x96 */
} mcu1_data_t;
```

#### 2.4 DLC长度校验
接收线程必须校验报文长度，超出范围直接丢弃：

```c
size = rt_device_read(can_dev, 0, &rxmsg, sizeof(rxmsg));
if (!size) {
    LOG_E("CAN read error\n");
    continue;
}
/* 校验 DLC：仅处理8字节报文 */
if (rxmsg.len != 8) {
    LOG_E("DLC error: ID=0x%08X LEN=%d\n", rxmsg.id, rxmsg.len);
    continue;
}
```

### 3. 收发流程设计

#### 3.1 接收架构（中断+信号量+独立线程）
强制采用三层架构：中断回调仅释放信号量，解析逻辑在独立线程执行：

```c
/* 接收回调 (中断上下文，极简设计) */
static rt_err_t can_rx_callback(rt_device_t dev, rt_size_t size)
{
    rt_sem_release(&can_rx_sem);  /* 仅置标志，禁止复杂操作 */
    return RT_EOK;
}

/* 接收线程 (独立线程上下文) */
static void can_rx_thread_entry(void *parameter)
{
    struct rt_can_msg rxmsg = {0};
    while (1) {
        rt_sem_take(&can_rx_sem, RT_WAITING_FOREVER);  /* 等待中断通知 */
        rxmsg.hdr = -1;  /* 直接从 uselist 链表读取 */
        size = rt_device_read(can_dev, 0, &rxmsg, sizeof(rxmsg));

        /* 根据报文ID分发解析 */
        switch (rxmsg.id) {
            case CAN_ID_MCU1: parse_mcu1(rxmsg.data); break;
            case CAN_ID_MCU2: parse_mcu2(rxmsg.data); break;
            default: LOG_E("Unknown ID 0x%08X\n", rxmsg.id); break;
        }
    }
}
```

#### 3.2 发送架构（独立线程+周期调度）
周期性报文采用独立线程定时发送，禁止阻塞等待：

```c
/* 发送线程 */
static void can_tx_thread_entry(void *parameter)
{
    uint8_t cnt = 0;
    uint8_t l_can_data[8];

    while (1) {
        /* KEY报文: 50ms周期 */
        pack_meter_push_button_send(l_can_data);
        can_send_message(CAN_ID_KEY, RT_CAN_EXTID, l_can_data, 8);

        /* METER报文: 100ms周期（每2次循环发送一次） */
        if ((cnt & 0x01) == 0) {
            pack_meter(l_can_data);
            can_send_message(CAN_ID_METER, RT_CAN_EXTID, l_can_data, 8);
        }

        cnt++;
        rt_thread_mdelay(50);  /* 50ms基准周期 */
    }
}
```

#### 3.3 通用发送函数
封装通用发送接口，自动处理标准帧/扩展帧、长度截断、0xFF填充：

```c
static rt_err_t can_send_message(uint32_t id, uint8_t ide, const uint8_t *data, uint8_t len)
{
    struct rt_can_msg txmsg = {0};
    txmsg.id  = id;
    txmsg.ide = ide;  /* RT_CAN_STDID 或 RT_CAN_EXTID */
    txmsg.rtr = RT_CAN_DTR;  /* 数据帧 */
    txmsg.len = len > 8 ? 8 : len;

    rt_memcpy(txmsg.data, data, txmsg.len);
    /* 不足8字节填充0xFF */
    if (txmsg.len < 8) {
        rt_memset(&txmsg.data[txmsg.len], 0xFF, 8 - txmsg.len);
    }

    size = rt_device_write(can_dev, 0, &txmsg, sizeof(txmsg));
    if (size != sizeof(txmsg)) {
        LOG_E("CAN TX (0x%08X) failed\n", id);
        return -RT_ERROR;
    }
    return RT_EOK;
}
```

### 4. 多任务共享数据保护

#### 4.1 互斥锁分层设计
CAN模块涉及多线程数据共享，必须使用互斥锁保护：

```c
static struct rt_mutex meter_mutex;      /* 仪表数据互斥锁（CAN线程 ↔ UI线程） */
static struct rt_mutex can_mutex;        /* CAN数据互斥锁（TX线程 ↔ RX线程） */
static struct rt_mutex history_mutex;    /* 历史里程互斥锁（CAN线程 ↔ 文件线程） */

/* 初始化 */
rt_mutex_init(&meter_mutex, "meter_mutex", RT_IPC_FLAG_PRIO);
rt_mutex_init(&can_mutex, "can_mutex", RT_IPC_FLAG_PRIO);
rt_mutex_init(&history_mutex, "hist_mutex", RT_IPC_FLAG_PRIO);

/* 封装接口 */
void can_meter_mutex_take(void) { rt_mutex_take(&meter_mutex, RT_WAITING_FOREVER); }
void can_meter_mutex_release(void) { rt_mutex_release(&meter_mutex); }
```

#### 4.2 持锁原则
- **禁止嵌套持锁**：不同类别的锁不可同时持有，防止死锁
- **最小持锁时间**：持锁期间仅做数据拷贝，禁止在锁内做IPC、文件操作
- **锁外事件通知**：里程更新事件在释放history_mutex后发送

```c
/* 正确示例：锁内拷贝，锁外通知 */
can_history_mutex_take();
odo_updated = update_distance(speed, counter, &g_history_distance, &l_can_odo);
l_odo_raw = g_history_distance.odo_raw;
l_trip_raw = g_history_distance.trip_raw;
can_history_mutex_release();

/* 锁外发送事件（避免在持锁期间做IPC） */
if (odo_updated) {
    rt_event_send(g_file_event, EVENT_ODO_SAVE);
}
```

### 5. 里程计算与丢帧估算

#### 5.1 基于车速的里程累加
利用CAN报文周期性特性，按车速积分累加里程：

```c
#define CAN_ID_MCU1_PERIOD      200.0f      /* MCU1报文周期 200ms */
#define SPEED_1S_SCALE_FACTOR   3.6f        /* km/h → m/s 缩放因子 */
#define SPEED_SCALE_FACTOR      (SPEED_1S_SCALE_FACTOR * (1000.0f / CAN_ID_MCU1_PERIOD))

static bool update_distance(uint8_t speed_now, uint8_t counter,
                            history_distance_t *p_history, uint32_t *p_can_odo)
{
    static uint8_t s_speed_last = 0;
    static uint8_t s_counter_last = 0;
    static bool s_first_frame = true;
    float dist;
    bool updated = false;

    if (speed_now > 0 && speed_now <= 150) {
        if (s_first_frame) {
            dist = (float)speed_now / SPEED_SCALE_FACTOR;
            s_first_frame = false;
        }
        /* 检查计数器连续性（0-7循环） */
        else if (counter == ((s_counter_last + 1) & 0x07)) {
            dist = (float)speed_now / SPEED_SCALE_FACTOR;
        }
        else {
            /* 丢帧估算：用前后速度平均值计算丢失期间距离 */
            uint8_t lost_count = (counter - s_counter_last - 1 + 8) & 0x07;
            float avg_speed = (float)(s_speed_last + speed_now) / 2.0f;
            dist = avg_speed / SPEED_SCALE_FACTOR * (float)(lost_count + 1);
        }

        p_history->acc_dist += dist;
        /* 每累积100米（0.1公里）进位 */
        while (p_history->acc_dist >= 100.0f) {
            p_history->acc_dist -= 100.0f;
            p_history->trip_raw += 1;
            p_history->odo_raw += 1;
            updated = true;
        }
    }

    s_speed_last = speed_now;
    s_counter_last = counter;
    return updated;
}
```

#### 5.2 里程事件通知机制
里程进位后使用事件组通知文件线程持久化存储：

```c
/* CAN线程：里程进位后发送事件 */
if (odo_updated) {
    rt_event_send(g_file_event, EVENT_ODO_SAVE);
}

/* 文件线程：等待事件后存储 */
rt_event_recv(g_file_event, EVENT_ODO_SAVE, RT_EVENT_FLAG_OR | RT_EVENT_FLAG_CLEAR,
              RT_WAITING_FOREVER, &recved);
/* 执行文件写入... */
```

### 6. DTC故障码优先级管理

#### 6.1 故障码偏移映射
使用偏移量区分不同来源的故障码，确保优先级显示：

```c
/* 故障码定义：
 * - 电控故障码：1~50（来自MCU2报文）
 * - 电池故障码：101~132（原始值1~32 + 100偏移，来自BMS5报文）
 * - 优先级：电池故障 > 电控故障 > 0（无故障）
 */

/* BMS5解析：电池故障码+100偏移 */
if (l_bms5.battery_fault_code > 0) {
    g_meter_can_variable.state_code = l_bms5.battery_fault_code + 100;
}

/* MCU2解析：仅当无电池故障时才更新电控故障码 */
if (g_meter_can_variable.state_code <= 50) {
    g_meter_can_variable.state_code = l_mcu2.mcu_motor_fault_code;
}

/* BMS5解析：电池故障恢复时清除残留故障码 */
else if (g_meter_can_variable.state_code > 100) {
    g_meter_can_variable.state_code = 0;
}
```

#### 6.2 故障恢复逻辑
故障恢复需清除残留故障码，后续报文会重新更新：

```c
/* 电池故障已恢复 */
else if (g_meter_can_variable.state_code > 100) {
    g_meter_can_variable.state_code = 0;  /* 清除残留电池故障码 */
    /* 后续MCU2报文会更新为电控故障码或0 */
}
```

### 7. 硬件过滤器配置

#### 7.1 过滤器配置（RT-Thread）
使用硬件过滤器减少CPU占用，仅接收目标报文：

```c
#ifdef RT_CAN_USING_HDR
struct rt_can_filter_item items[] = {
    /* 扩展帧：覆盖MCU/BMS所有报文ID */
    RT_CAN_FILTER_ITEM_INIT(CAN_ID_MCU1, 1, 0, 0, 0xFFF0F8E4, RT_NULL, RT_NULL),
};
struct rt_can_filter_config cfg = {1, 1, items};
rt_device_control(can_dev, RT_CAN_CMD_SET_FILTER, &cfg);
#endif
```

#### 7.2 过滤器掩码设计
使用掩码覆盖一组报文ID，减少过滤器条目数量：

```c
/* 掩码0xFFF0F8E4可覆盖0x1801F4EF ~ 0x1809F3F4范围 */
RT_CAN_FILTER_ITEM_INIT(CAN_ID_MCU1, 1, 0, 0, 0xFFF0F8E4, RT_NULL, RT_NULL)
```

### 8. 初始化流程规范

#### 8.1 CAN设备初始化顺序
严格按照SDK规范初始化CAN设备：

```c
static int can_comm_init(void)
{
    /* 1. 查找设备 */
    can_dev = rt_device_find(CAN_DEV_NAME);
    if (!can_dev) return RT_ERROR;

    /* 2. 打开设备（中断模式） */
    ret = rt_device_open(can_dev, RT_DEVICE_FLAG_INT_TX | RT_DEVICE_FLAG_INT_RX);

    /* 3. 设置波特率 */
    rt_device_control(can_dev, RT_CAN_CMD_SET_BAUD, (void *)CAN500kBaud);

    /* 4. 使能中断 */
    rt_device_control(can_dev, RT_DEVICE_CTRL_SET_INT, NULL);

    /* 5. 禁用自动重传 */
    rt_device_control(can_dev, RT_CAN_CMD_DISABLE_RETRANS, (void *)1);

    /* 6. 注册接收回调 */
    rt_device_set_rx_indicate(can_dev, can_rx_callback);

    /* 7. 配置过滤器（可选） */
    rt_device_control(can_dev, RT_CAN_CMD_SET_FILTER, &cfg);

    /* 8. 初始化IPC对象（信号量/互斥锁） */
    rt_sem_init(&can_rx_sem, "can_rx_sem", 0, RT_IPC_FLAG_PRIO);
    rt_mutex_init(&meter_mutex, "meter_mutex", RT_IPC_FLAG_PRIO);

    /* 9. 创建收发线程 */
    rt_thread_create("can_com_rx", can_rx_thread_entry, ...);
    rt_thread_create("can_com_tx", can_tx_thread_entry, ...);

    return RT_EOK;
}
INIT_APP_EXPORT(can_comm_init);  /* 应用级自动初始化 */
```

## 输出要求
1. 报文解析代码必须附带信号对照表（含义、单位、偏移、分辨率、范围）
2. 故障处理必须说明优先级机制、偏移映射规则、恢复逻辑
3. 所有宏定义必须标注含义、单位、周期、帧类型
4. 里程计算必须说明缩放因子、丢帧估算策略、事件通知机制
5. 互斥锁必须说明保护对象、持锁范围、锁外操作

## 代码自检清单
- [ ] 所有CAN ID使用宏定义，无硬编码
- [ ] 字节序解析使用统一宏（GET_U16_LE等）
- [ ] 位域解析使用掩码操作，无直接位运算
- [ ] 接收中断回调仅释放信号量，无复杂操作
- [ ] 发送线程采用周期调度，无阻塞等待
- [ ] 多任务共享数据使用互斥锁保护
- [ ] 故障码有优先级机制和偏移映射
- [ ] 里程计算包含丢帧估算逻辑
- [ ] 初始化顺序符合SDK规范
