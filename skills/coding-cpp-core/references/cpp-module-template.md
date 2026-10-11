# C/C++ 模块文件模板

## 加载条件

仅在新建 `.h/.c`、`.hpp/.cpp` 文件，或一次修改涉及公共 API、资源生命周期和完整错误清理路径时加载。

以下代码是示例骨架，必须替换为目标工程的状态类型、日志接口、同步机制和错误码。不要直接复制未知平台 API。

## 头文件模板

```c
/**
 * @file module.h
 * @brief <MODULE> 的公共接口。
 */
#ifndef MODULE_H
#define MODULE_H

#include <stdbool.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    uint32_t option;        /* 配置项含义、单位、默认值和允许范围必须由目标工程定义。 */
    uint32_t timeout_ms;    /* 超时单位写入字段名；是否允许永久等待不能由模板推断。 */
} module_config_t;

typedef enum {
    MODULE_RESULT_OK = 0,             /* 操作完成。 */
    MODULE_RESULT_INVALID_ARGUMENT,   /* 指针、长度或配置内容不合法。 */
    MODULE_RESULT_NOT_READY,          /* 依赖尚未初始化或已进入释放阶段。 */
    MODULE_RESULT_IO_ERROR            /* 底层设备/存储操作失败。 */
} module_result_t;

module_result_t module_init(const module_config_t *config);
module_result_t module_deinit(void);
module_result_t module_get_value(uint32_t *value);

#ifdef __cplusplus
}
#endif

#endif /* MODULE_H */
```

## 源文件模板

```c
#include "module.h"

/* 文件级状态只由本模块管理；并发访问时需接入目标工程同步机制。 */
static bool s_module_ready;
/* 示例缓存值；单位、有效性和更新来源必须在接口契约中写明。 */
static uint32_t s_module_value;

static bool module_config_is_valid(const module_config_t *config)
{
    return (config != NULL);
}

module_result_t module_init(const module_config_t *config)
{
    if (!module_config_is_valid(config)) {
        return MODULE_RESULT_INVALID_ARGUMENT;
    }

    /* 按目标工程顺序创建资源；任一步失败都要释放已经取得的资源，
     * 并保持 s_module_ready 为 false，避免调用方误以为模块可用。 */
    s_module_value = 0U;
    s_module_ready = true;
    return MODULE_RESULT_OK;
}

module_result_t module_deinit(void)
{
    if (!s_module_ready) {
        return MODULE_RESULT_OK;
    }

    /* 释放句柄、注销回调并恢复不可用状态，具体 API 以项目为准；
     * 释放顺序通常与初始化顺序相反。 */
    s_module_ready = false;
    return MODULE_RESULT_OK;
}

module_result_t module_get_value(uint32_t *value)
{
    /* 输出指针由调用方提供，成功返回后值的生命周期属于调用方。 */
    if ((value == NULL) || !s_module_ready) {
        return (value == NULL) ? MODULE_RESULT_INVALID_ARGUMENT
                               : MODULE_RESULT_NOT_READY;
    }

    *value = s_module_value;
    return MODULE_RESULT_OK;
}
```

## 错误清理顺序

按“最后取得的资源先释放”的顺序组织失败路径。锁、文件、设备、定时器、回调和线程的所有权必须可追踪；不要在错误路径伪造成功，也不要返回指向局部变量的地址。
