---
name: "meter-storage"
description: "车辆仪表参数持久化、里程和配置存储、CRC 校验、掉电保护、事件驱动写入、文件系统和线程安全规范。Use when Codex adds or changes RT-Thread filesystem persistence, stored parameters, mileage records, fault history, CRC validation, or asynchronous save workflows."
---

# 仪表参数持久化存储规范

## 适用范围
仅在任务涉及本项目仪表的里程、配置、故障记录、掉电保存或 RT-Thread 文件系统持久化时启用。Qt 应用的 `QSettings`、数据库或普通文件保存不使用本 Skill 的 RT-Thread/packed/CRC 固定方案，除非用户明确要求兼容该格式。

> 通用RT-Thread模式（线程模板、事件驱动模式、命名约定）见 `coding-rtthread-style` Skill。

## 触发场景
- 新增/修改需要掉电保存的参数
- 文件系统存储分区设计
- 参数读写、校验、恢复默认值
- 故障记录、历史数据存储
- 事件驱动写入、磨损均衡设计

## 核心执行规范

### 1. 存储架构设计
1. 使用 RT-Thread 文件系统（dfs_posix）进行持久化存储，路径统一定义为 `/data/file.bin`
2. 存储结构体必须使用 `__attribute__((packed))` 对齐，禁止结构体填充导致大小不一致
3. 所有存储数据必须附加 CRC32 校验值，校验范围为结构体中除 crc32 字段外的所有数据
4. 存储结构体成员必须标注有效范围，写入前进行边界截断，读取后进行范围校验

### 2. 存储数据结构规范
1. 里程数据采用 `km_int`（公里整数部分）+ `m_int`（米小数部分）组合存储
2. 配置参数与里程数据合并存储在同一结构体中，统一读写
3. CRC32 字段必须放在结构体末尾，计算时使用 `offsetof` 定位校验边界
4. 结构体命名：`模块_语义_struct`，如 `file_storage_t`

### 3. 事件驱动写入机制
1. 使用 RT-Thread 事件组（`rt_event_t`）作为跨任务通知机制
2. 定义独立事件位：里程保存事件、单位切换事件、显示模式切换事件等
3. 事件触发方式：`RT_EVENT_FLAG_OR | RT_EVENT_FLAG_CLEAR`，任意事件触发自动清除
4. 高优先级任务（UI/CAN）仅设置事件位，不执行实际写操作

### 4. 专用存储线程规范
1. 创建独立低优先级线程执行写操作，优先级推荐 18
2. 线程栈大小最小 4096 字节（文件系统操作栈开销大）
3. 线程入口函数：阻塞等待事件 → 收集数据 → 写入文件
4. 线程命名：`模块_thread`，如 `file_thread`
5. 使用 `INIT_APP_EXPORT` 实现自动初始化

### 5. 读写时序与保护
1. 读取操作：打开文件 → 读取完整结构体 → 关闭文件 → CRC 校验 → 范围校验
2. 写入操作：数据收集 → 边界截断 → 计算 CRC → 打开文件 → 写入完整结构体 → 关闭文件
3. 读取失败处理：文件不存在返回 `RT_ENOMEM`，CRC 错误/大小不匹配返回 `RT_ERROR`
4. 降级策略：校验失败时清空数据为默认值并写入，禁止系统死机
5. 启动加载：线程初始化时一次性加载所有参数到内存变量

### 6. 线程安全规范
1. 读取共享数据（数据池/UI变量）前必须获取对应互斥锁
2. 使用局部变量临时存储读取的数据，避免持锁期间执行耗时操作
3. 禁止嵌套互斥锁，防止死锁
4. 互斥锁使用模式：`mutex_take → 读取数据 → mutex_release`

### 7. 业务对接规则
1. 运行中仅操作内存数据，文件写入通过事件触发异步执行
2. 关键参数（里程）定时 + 变更时触发写入事件
3. 配置修改后触发写入事件，取消修改不触发
4. 提供参数恢复默认值功能，校验全失败时自动恢复默认值

## 输出要求
1. 新增存储参数必须说明：字段名、类型、有效范围、校验方式、写入时机
2. 读写逻辑必须说明异常处理与降级方案
3. 涉及文件操作必须说明线程配置与事件定义
4. 必须标注线程安全与调用层级限制

## 代码示例

### 存储结构体定义
```c
typedef struct __attribute__((packed)) {
    uint32_t km_int;    /* 公里整数部分：0 ~ 999999 */
    uint16_t m_int;     /* 小数部分：0 ~ 999 精确到1m */
    uint8_t display_km_mile_mode;  /* 显示里程单位：公里/英里 */
    uint8_t display_odo_trip_mode; /* 显示Odo/Trip模式 */
    uint32_t crc32;     /* 校验 CRC32 */
} file_storage_t;
```

### CRC 计算方法
```c
static uint32_t calc_storage_crc(const file_storage_t *s)
{
    return crc32(0, (const uint8_t *)s, offsetof(file_storage_t, crc32));
}
```

### 事件定义示例
```c
#define EVENT_ODO_SAVE      (1 << 0)  /* ODO里程存储事件 */
#define EVENT_KM_MILE       (1 << 1)  /* km/mile切换显示事件 */
#define EVENT_TRIP_ODO      (1 << 2)  /* trip/odo显示切换事件 */
#define EVENT_ALL           (EVENT_ODO_SAVE | EVENT_KM_MILE | EVENT_TRIP_ODO)
```

### 线程配置示例
```c
#define FILE_THREAD_PRIORITY     18       /* 文件保存线程优先级 */
#define FILE_THREAD_STACK_SIZE   4096     /* 线程栈大小 */
#define FILE_THREAD_TIMESLICE    10       /* 线程时间片 */
```
