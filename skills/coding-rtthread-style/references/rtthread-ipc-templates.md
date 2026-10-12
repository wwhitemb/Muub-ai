# RT-Thread 任务与 IPC 模板

## 加载条件

在创建或修改 RT-Thread 线程、信号量、互斥锁、事件集、设备回调、启动入口或资源释放流程时加载。

优先复用目标工程已有的封装和命名。线程优先级、栈大小、时间片、超时和初始化宏必须来自项目配置或测量。

## 线程入口骨架

```c
/* 线程句柄由创建流程拥有；停止或卸载前必须确认线程已退出。 */
static rt_thread_t s_worker_thread;       /* 工作线程句柄；释放前必须确认线程已停止。 */
/* 信号量只用于唤醒工作线程；计数是否允许合并必须由工程确认。 */
static struct rt_semaphore s_worker_sem;  /* 唤醒信号量；是否合并通知由工程确认。 */
/* 仅表示线程及其依赖已完成初始化，不代表业务数据有效。 */
static bool s_worker_ready;               /* 依赖初始化完成标志，不代表业务数据有效。 */

/**
 * @brief 工作线程入口，在任务上下文处理待办业务。
 * @param[in] parameter 线程创建时传入的上下文；当前模板不使用。
 * @return 无；线程退出策略和永久运行语义由目标工程确认。
 */
static void worker_entry(void *parameter)
{
    RT_UNUSED(parameter);

    for (;;) {
        const rt_err_t wait_result = /* 记录等待结果，失败时不得继续假设事件已到达。 */
            rt_sem_take(&s_worker_sem, RT_WAITING_FOREVER);
        if (wait_result != RT_EOK) {
            /* 永久等待失败通常意味着对象被删除或系统异常；
             * 记录错误并按项目策略退出、重试或降级，不能静默继续处理。 */
            continue;
        }

        /* 在线程上下文处理复杂解析、数据池更新或文件请求；
         * 不把这些可阻塞工作放入中断或设备回调。 */
        project_process_pending_work();
    }
}
```

创建线程时使用目标工程的栈、优先级和时间片配置，并检查创建、启动和资源初始化返回值。不要把示例数值复制到项目。

## ISR 通知任务

```c
/**
 * @brief 设备接收回调，仅向工作线程发送快速通知。
 * @param[in] device 触发回调的设备句柄；具体使用方式由工程确认。
 * @param[in] size 本次接收数据量；当前模板仅作通知，不在回调中解析。
 * @return RT-Thread 错误码；通知失败必须进入项目诊断路径。
 */
static rt_err_t device_rx_indicate(rt_device_t device, rt_size_t size)
{
    RT_UNUSED(device);
    RT_UNUSED(size);
    /* 回调必须保持短小且非阻塞；信号量释放失败时的诊断策略由工程决定。 */
    return rt_sem_release(&s_worker_sem);
}
```

回调只做快速通知或数据转移；实际读取、校验和业务处理在线程上下文完成。若信号量可能合并通知，要额外维护丢失/溢出计数或使用消息队列。

## 共享快照与事件

```c
static struct rt_mutex s_data_mutex;
static struct rt_event s_save_event;

/**
 * @brief 在互斥锁保护下复制共享值快照。
 * @param[out] value 输出快照；不能为空，失败时不伪造成功数据。
 * @return true 表示复制和解锁均成功；false 表示参数、加锁或解锁失败。
 */
static bool copy_shared_value(uint32_t *value)
{
    if (value == RT_NULL) {
        return false;
    }
    if (rt_mutex_take(&s_data_mutex, RT_WAITING_FOREVER) != RT_EOK) {
        /* 未取得锁时不能读取可能正在更新的数据，也不能伪造成功。 */
        return false;
    }

    *value = project_shared_value();
    /* 解锁失败也应进入工程既有诊断路径；此处不隐藏返回值。 */
    return (rt_mutex_release(&s_data_mutex) == RT_EOK);
}

/**
 * @brief 向持久化工作线程发送保存请求。
 * @return 无；发送失败必须由工程既有诊断机制记录。
 * @note 具体事件位和合并语义由项目配置确认。
 */
static void request_save(void)
{
    /* 只发送事件；文件操作放在可阻塞的工作线程。
     * 事件位是否合并、是否可能丢失以及发送失败如何补偿，必须确认。 */
    (void)rt_event_send(&s_save_event, PROJECT_SAVE_EVENT);
}
```

锁内只复制必要数据，复制后在锁外执行 UI、文件、日志和耗时计算。事件位的清除、合并和丢失语义必须在项目中明确。

## 设备初始化与释放

按“设备可用 -> IPC -> 线程/回调 -> 业务服务”的依赖顺序执行。每一步失败都回滚已取得资源；系统不支持卸载时，在文档中明确永久生命周期。设备读写、控制和关闭返回值不能丢弃。
