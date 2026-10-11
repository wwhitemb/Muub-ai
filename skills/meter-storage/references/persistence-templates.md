# 仪表持久化实现模板

## 加载条件

在修改参数、里程、故障记录的存储格式、CRC、版本迁移、掉电保护、加载恢复或异步保存时加载。

路径、文件 API、CRC 类型、事件值、线程配置和副本策略必须来自当前工程。模板不是可直接编译的项目实现。

## 记录格式

```c
typedef struct {
    uint16_t format_version; /* 选择解析/迁移逻辑，不等同于软件版本号。 */
    uint16_t payload_length; /* 实际载荷长度，必须不超过 PROJECT_PAYLOAD_CAPACITY。 */
    uint32_t sequence;       /* 比较副本新旧；溢出和回绕规则必须由工程定义。 */
    uint8_t payload[PROJECT_PAYLOAD_CAPACITY]; /* 载荷布局和序列化顺序由版本契约固定。 */
    uint32_t checksum;       /* 不参与自身计算，覆盖范围必须由存储格式明确。 */
} module_record_t;

static uint32_t record_checksum(const module_record_t *record)
{
    /* 只计算 checksum 字段之前的字节；不要默认结构体无填充。 */
    return project_crc32((const uint8_t *)record,
                         offsetof(module_record_t, checksum));
}
```

不要无条件使用 `packed`。只有存储格式明确要求固定字节布局且工程已验证对齐访问、编译器布局和序列化边界时才使用；否则逐字段编码到字节缓冲区。

## 读取、校验和恢复

```text
读取主记录
  -> 检查存在性、完整长度、版本、payload 长度和 checksum
  -> 合法：发布到数据池
  -> 旧版本：迁移到当前内存结构并记录版本变化
  -> 损坏/短读/范围错误：尝试备用副本或默认值
  -> 向上层报告真实恢复原因
```

读取失败不能伪造持久化成功；恢复默认值时保留可观察状态，不能覆盖内存中仍有效的运行数据。

## 异步保存

```c
static void request_persist(void)
{
    /* 高优先级/UI/通信上下文只发请求，不执行文件操作。 */
    (void)project_event_send(PROJECT_SAVE_EVENT);
}

static void persist_worker(void *parameter)
{
    /* record 只在线程栈中使用；异步写入接口若不立即复制数据，
     * 必须改为使用工程认可的持久化缓冲区。 */
    module_record_t record;
    (void)parameter;

    for (;;) {
        if (project_event_wait(PROJECT_SAVE_EVENT) != PROJECT_OK) {
            continue;
        }

        if (!project_datapool_snapshot(&record.payload,
                                       sizeof(record.payload))) {
            project_report_persist_error(PROJECT_SNAPSHOT_ERROR);
            continue;
        }
        record.payload_length = project_payload_length();
        record.sequence = project_next_sequence();
        record.checksum = record_checksum(&record);
        /* 写入失败必须进入可观察错误路径；不能把请求视为已保存。 */
        if (project_atomic_write_record(&record, sizeof(record)) != PROJECT_OK) {
            project_report_persist_error(PROJECT_WRITE_ERROR);
        }
    }
}
```

数据池快照必须在锁内复制，CRC、格式转换和文件写入在锁外执行。原子更新可使用工程已有的临时文件、双副本或序列号策略，不得凭经验新增固定路径。

## 验证清单

覆盖首次启动、正常读写、短文件、错误 CRC、版本迁移、范围越界、写入失败、重复保存和掉电中断；记录尚未验证的介质行为。
