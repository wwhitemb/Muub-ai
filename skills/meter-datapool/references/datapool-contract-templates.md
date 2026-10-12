# 仪表数据池契约与快照模板

## 加载条件

在新增数据池字段、数据域、读写接口、有效性/超时逻辑、跨线程快照或通信/UI/业务/存储对接时加载。

字段名称、单位、范围、默认值、时间源和锁 API 必须来自当前工程；示例不代表项目事实。

## 字段契约

新增字段前记录：

| 项目 | 必须确认 |
| --- | --- |
| 来源 | 唯一写入方、原始报文或计算依据 |
| 类型 | 宽度、符号、浮点/定点和序列化方式 |
| 语义 | 单位、有效范围、默认值和异常保留策略 |
| 时效 | 更新时间、超时来源、恢复条件 |
| 访问 | 读取方、同步方式、是否允许覆盖 |
| 持久化 | 是否保存、格式版本和恢复策略 |

## 数据结构与快照

```c
typedef struct {
    uint32_t value;      /* 单位、编码、范围和默认值必须由字段契约确认。 */
    uint32_t updated_at; /* 时间单位和时间源必须由工程定义，不能默认理解为毫秒或系统节拍。 */
    bool valid;          /* 有效性独立于数值本身；无效值不得直接参与业务计算。 */
} datapool_value_t;

typedef struct {
    datapool_value_t field_a; /* 示例字段；替换为目标数据池中的实际字段。 */
    datapool_value_t field_b; /* 示例字段；替换为目标数据池中的实际字段。 */
} datapool_snapshot_t;

/**
 * @brief 在锁内复制数据池一致快照。
 * @param[out] snapshot 输出快照；不能为空，失败时不返回半更新数据。
 * @return true 表示加锁、复制和解锁均成功；false 表示任一步骤失败。
 */
bool datapool_snapshot_get(datapool_snapshot_t *snapshot)
{
    if (snapshot == NULL) {
        return false;
    }

    /* 只在锁内复制一致快照；不要把 UI、日志或文件操作放入锁内。 */
    if (!project_datapool_lock()) {
        /* 锁获取失败时不得返回一份看似有效的半更新数据。 */
        return false;
    }
    *snapshot = project_datapool_state();
    /* 解锁返回值和失败诊断按目标工程 API 替换，不能无条件吞掉错误。 */
    return project_datapool_unlock();
}
```

锁内只完成必要复制，计算、日志、UI 和文件操作放在锁外。若工程使用消息传递或原子结构，保持现有机制，不额外引入另一套锁。

## 写入与有效性

```c
/**
 * @brief 校验原始字段并提交到数据池。
 * @param[in] raw_value 待更新原始值；单位、范围和编码由字段契约确认。
 * @param[in] timestamp 数据时间戳或序号；具体单位由工程定义。
 * @return true 表示字段已提交；false 表示输入非法或更新未完成。
 */
bool datapool_update_field(uint32_t raw_value, uint32_t timestamp)
{
    /* 先在锁外完成无副作用的范围校验，减少临界区占用时间。 */
    if (!project_value_in_range(raw_value)) {
        return false;
    }

    /* 只有确认输入合法后才提交；解析失败或过期数据应保留旧有效值。 */
    project_datapool_lock();
    project_set_field(raw_value, timestamp, true);
    project_datapool_unlock();
    return true;
}
```

解析失败、过期或越界数据不得覆盖上一份有效值，除非需求明确要求清零。UI 和业务应分别定义无效值的显示与计算行为，不能把无效值默认为正常零值。

## 交付检查

确认唯一写入方、快照一致性、时间戳/序号、超时和恢复、锁生命周期、存储边界、初始化默认值以及异常验证。
