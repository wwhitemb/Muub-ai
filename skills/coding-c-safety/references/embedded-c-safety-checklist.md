# 嵌入式 C 安全检查与代码骨架

## 加载条件

在生成或审查驱动、ISR、通信缓冲区、DMA、寄存器访问、RTOS 共享状态或资源错误路径时加载。普通 C/C++ 业务逻辑只使用 `coding-cpp-core`。

所有平台 API、错误码、临界区和内存策略必须从目标工程确认。

## 输入与缓冲区

```c
/**
 * @brief 检查缓冲区区间是否完全落在容量范围内。
 * @param[in] offset 区间起始偏移。
 * @param[in] width 区间长度。
 * @param[in] capacity 缓冲区总容量。
 * @return true 表示区间合法；false 表示越界或整数关系不满足。
 */
static bool buffer_range_valid(size_t offset, size_t width, size_t capacity)
{
    return (offset <= capacity) && (width <= (capacity - offset));
}

/**
 * @brief 从缓冲区读取小端无符号 16 位值。
 * @param[in] buffer 输入缓冲区；不能为空。
 * @param[in] buffer_length 输入缓冲区有效长度。
 * @param[in] offset 字段起始偏移；读取范围必须受 buffer_length 约束。
 * @param[out] value 输出值；失败时保持调用方原值。
 * @return true 表示读取成功；false 表示参数为空或范围校验失败。
 */
bool read_u16_le(const uint8_t *buffer,
                 size_t buffer_length,
                 size_t offset,
                 uint16_t *value)
{
    if ((buffer == NULL) || (value == NULL) ||
        !buffer_range_valid(offset, sizeof(uint16_t), buffer_length)) {
        return false;
    }

    *value = (uint16_t)buffer[offset] |
             ((uint16_t)buffer[offset + 1U] << 8U);
    return true;
}
```

检查对象有效、长度计算溢出、下标范围、整数转换、字符串终止和输出容量。协议布局优先显式解析，不因方便直接把字节缓冲区强转为结构体。

## ISR 与并发

```c
static volatile uint32_t s_pending_count; /* 待处理事件计数；volatile 不替代原子操作或临界区。 */

/**
 * @brief 外设中断服务函数，仅保存必要状态并通知工作线程。
 * @return 无；不得阻塞、打印或执行复杂解析。
 * @note 具体中断来源由 BSP 注册关系确认。
 */
/* ISR 只保存必要状态并发出快速通知；具体通知 API 由项目提供。 */
static void peripheral_isr(void)
{
    const uint32_t status = project_read_status(); /* 保存本次中断状态，供清中断接口使用。 */

    project_clear_interrupt(status);
    s_pending_count++; /* 记录待处理事件数量；并发安全性由项目同步机制保证。 */
    project_notify_worker_from_isr();
}
```

ISR 不阻塞、不打印、不执行复杂解析、不访问非 ISR-safe API。`volatile` 只表达可观察性，不能替代原子操作、锁、临界区或消息传递。

## 资源和错误路径

- 动态分配、设备查找、打开、配置、注册、发送、接收和关闭都检查返回值。
- 初始化失败时按已取得资源的逆序释放；重复初始化和部分初始化必须有明确语义。
- 大对象、DMA 缓冲区和线程栈的大小由工程配置或测量决定，不在模板中固定。
- 条件编译禁用时返回明确的“不支持/未启用”结果，不能静默伪造成功。
- 共享数据只在最短临界区内更新或复制；文件、网络、UI 和延时操作放到锁外。

## 交付自检

确认边界、所有权、生命周期、ISR 工作量、同步方式、返回值、超时、降级和日志可观察性；无法从工程确认的硬件行为标记“待项目确认”。
