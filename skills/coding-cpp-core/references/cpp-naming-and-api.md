# C/C++ 命名与公共 API 参考

## 加载条件

仅在新建公共接口、类型、回调、配置宏或模块文件时加载。局部修复且已有命名约定时不需要加载本文件。

本文件是泛化模板，不代表目标工程的真实前缀、单位、范围或返回值。先搜索同目录和调用方，再替换所有占位符。

## 命名决策

1. 优先复用目标模块已有的前缀、大小写、后缀和文件命名。
2. 没有现有约定时，公共符号使用稳定的模块前缀，私有文件级符号使用 `static` 和项目认可的私有标记。
3. 类型使用领域名加 `_t`、枚举使用项目既有后缀；不要用未经项目约定的匈牙利式类型编码。
4. 宏只用于编译配置、常量、位掩码和条件编译；运行时值优先使用 `static const` 或枚举。
5. 缩写必须来自项目或行业通用词汇；同一概念在接口、字段和日志中保持同名。

## 公共与私有 API

```c
/* 公共 API：模块前缀 + 动词 + 领域对象；返回值语义必须来自项目约定。 */
int32_t module_init(const module_config_t *config);
int32_t module_get_state(module_state_t *state);
int32_t module_set_mode(module_mode_t mode);

/* 私有函数：仅本文件使用，说明输入有效前提和失败影响。 */
static bool module_validate_config(const module_config_t *config);
static void module_apply_state(module_state_t state);

/* 回调名称应体现来源和执行上下文，不能用 callback1 这类无语义名称。 */
typedef void (*module_event_cb_t)(module_event_t event, void *user_data);
```

### 参数命名

- 指针参数使用项目现有风格；没有约定时用 `p_`、`pc_` 或清晰的 `data`/`length` 名称，不混用多套前缀。
- 输入、输出和输入输出参数在接口文档中明确标记；输出缓冲区必须同时提供容量。
- 长度、计数、索引和时间使用能表达语义的名称，例如 `length`、`count`、`index`、`timeout_ms`。
- 单位写入字段或参数名，不能只依赖调用方猜测。

## 类型、枚举和宏

```c
typedef struct {
    uint16_t value;     /* 示例业务值；单位、编码和有效范围必须由目标工程确认。 */
    bool valid;         /* false 表示当前值不可用于业务计算，不等同于 value == 0。 */
} module_value_t;

typedef enum {
    MODULE_STATE_IDLE = 0, /* 已初始化但当前没有活动任务。 */
    MODULE_STATE_ACTIVE,   /* 正在处理任务或提供服务。 */
    MODULE_STATE_ERROR,    /* 发生错误，具体恢复策略由工程定义。 */
    MODULE_STATE_COUNT     /* 枚举项数量，不作为运行时状态使用。 */
} module_state_t;

/* 以下值只是占位符，必须以需求、协议或现有配置中的证据替换。 */
#define MODULE_VALUE_MIN   <PROJECT_MIN_VALUE>
#define MODULE_VALUE_MAX   <PROJECT_MAX_VALUE>
#define MODULE_FLAG_READY  (1U << <PROJECT_BIT_INDEX>)
```

`<PROJECT_...>` 只是替换标记。没有协议、硬件或需求证据时，不要把示例值直接写进实现。

## 公共 API 文档模板

```c
/**
 * @brief 读取模块状态快照。
 * @param[out] state 输出状态，不能为空；调用方负责提供有效存储空间。
 * @return 项目约定的成功或错误码。
 * @note 调用线程、锁约束、数据有效性和生命周期必须从定义及调用方确认。
 *       若输出是快照，函数返回后调用方不应继续依赖模块内部存储。
 */
int32_t module_get_state(module_state_t *state);
```

交付前确认公共声明、定义、调用方、所有权、单位、范围、线程约束和错误语义一致。
