# CAN/CAN FD 报文实现模板

## 加载条件

在新增或修改 CAN/CAN FD 帧定义、字节序/位域解析、收发、过滤器、周期发送、超时或总线故障处理时加载。

模板只展示结构。ID、帧类型、DLC、周期、缩放、校验和驱动 API 必须来自当前协议与工程证据。

## 显式字节序与位域

```c
static bool can_get_u16_le(const uint8_t *data,
                           size_t length,
                           size_t offset,
                           uint16_t *value)
{
    /* 先验证指针和范围，避免 offset + 2 发生溢出或越过实际 DLC。 */
    if ((data == NULL) || (value == NULL) ||
        (offset > length) || (length - offset < 2U)) {
        return false;
    }

    /* 小端格式将低地址字节放在低位；不要依赖目标 CPU 的对齐和字节序。 */
    *value = (uint16_t)data[offset] |
             ((uint16_t)data[offset + 1U] << 8U);
    return true;
}

static uint32_t can_get_bits(uint8_t value, uint8_t shift, uint8_t width)
{
    /* shift + width 必须落在一个字节内；跨字节位域应单独按协议解析。 */
    if ((width == 0U) || (width > 8U) || (shift >= 8U) ||
        ((uint16_t)shift + width > 8U)) {
        return 0U;
    }

    /* width == 8 时移位表达式仍需保持无未定义行为，必要时按工程编译器规则改写。 */
    return ((uint32_t)value >> shift) & ((1UL << width) - 1UL);
}
```

位域跨字节时按协议定义实现独立解析函数，不使用依赖编译器布局的 C 位域。`packed` 只有在协议/ABI 明确要求且工程验证过未对齐访问策略时才可考虑。

## 接收解析流程

```c
bool module_parse_frame(const can_frame_t *frame, module_signal_t *signal)
{
    if ((frame == NULL) || (signal == NULL)) {
        return false;
    }
    /* 先确认 ID、帧类型和 DLC，再访问数据区；失败时不覆盖上一份有效信号。 */
    if (!project_frame_identity_matches(frame) ||
        frame->length < PROJECT_MIN_DLC ||
        frame->length > sizeof(frame->data)) {
        return false;
    }
    /* 校验失败的帧不能进入数据池；校验覆盖范围必须来自协议定义。 */
    if (PROJECT_HAS_CHECKSUM && !project_checksum_valid(frame)) {
        return false;
    }

    /* 解码函数应在所有字段成功后再提交输出，避免半更新结构体。 */
    return project_decode_signals(frame->data, frame->length, signal);
}
```

接收路径区分未收到、短帧、帧类型不符、字段越界、校验失败和总线错误，并保留必要的计数或诊断入口。

## 发送、过滤和故障

- 发送由单一模块负责组帧和调度，检查队列满、超时、部分发送和 bus-off 返回值。
- ISR/驱动回调只完成硬件确认、数据转移和快速通知；解析、数据池写入和告警在线程上下文完成。
- 过滤器使用最小匹配范围，标准帧与扩展帧分开验证；用允许和拒绝样例测试掩码规则。
- 每个在线报文定义超时来源、失效转换、恢复条件和告警策略；具体时限不得由模板推断。
- 总线恢复遵循驱动状态机，不在回调中阻塞重启或重复初始化。

## 交付自检

确认协议证据、长度边界、大小端、符号扩展、校验条件、缓冲区所有权、过滤覆盖、发送失败、超时恢复和异常测试。
