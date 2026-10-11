# Guider 1.x 导出源修改

## 适用范围

仅在总 Skill 已确认 Guider 1.x 且任务属于 `source-edit` 时加载。`generated/` 和 `custom/` 可按任务读写。

## 修改前

- 从 `generated/gui_guider.h` 确认 `lv_ui`、页面函数和控件句柄。
- 从 `setup_scr_*.c`、`events_init.*`、`widgets_init.*` 或构建清单确认实际生成结构。
- 检查 `custom/` 的初始化、数据池、刷新、资源和平台接口。
- 有 `.guiguider` 时，页面布局、控件树和设计事件结构仍回到 `project-edit`；source-edit 修改 `generated/` 可能被重新导出覆盖。

## 代码边界

- `generated/` 维护当前 1.x 导出的 C/H、事件、资源和构建源；`custom/` 放业务、数据绑定和适配。
- 不在 `custom/` 复制控件创建逻辑或重复注册事件。
- 定时器、事件和页面资源绑定到页面生命周期；离开页面时释放或取消回调。
- UI 刷新从数据池读取快照，控件访问遵循项目的 LVGL 线程/锁模型；业务计算不放在控件回调中。
- 新增或改名控件时同步检查 `lv_ui`、事件、页面初始化和 `custom/` 引用。

## 最小实现模板

以下代码是 1.x 结构示例，`guider_data_lock`、刷新函数和控件字段必须替换为目标工程已存在的接口。

```c
typedef struct {
    uint32_t value; /* 示例显示值；单位、范围和转换方式必须由目标工程确认。 */
    bool valid;     /* false 时界面应按项目策略显示无效状态，不应默认显示为零。 */
} guider_data_t;

/* 定时器属于当前页面；页面离开或销毁前必须删除，避免回调访问旧 UI。 */
static lv_timer_t *s_page_timer;

static void page_timer_cb(lv_timer_t *timer)
{
    /* user_data 必须来自 page_enter 时传入的页面句柄，不能从全局猜测。 */
    lv_ui *ui = lv_timer_get_user_data(timer);
    guider_data_t snapshot;

    if (ui == NULL) {
        return;
    }
    /* 锁只覆盖快照复制；控件更新放在锁外，减少阻塞数据生产者的时间。 */
    guider_data_lock();
    snapshot = project_guider_data_snapshot();
    guider_data_unlock();

    /* 该函数通常必须运行在项目规定的 LVGL 线程，不能从任意业务线程调用。 */
    project_update_1x_widget(ui, &snapshot);
}

void page_enter(lv_ui *ui)
{
    if (ui == NULL) {
        return;
    }
    s_page_timer = lv_timer_create(page_timer_cb,
                                   PROJECT_REFRESH_PERIOD_MS, ui);
    /* 创建失败不能伪造页面已启动；按项目错误路径记录并降级。 */
}

void page_leave(void)
{
    if (s_page_timer != NULL) {
        /* 先停止回调，再释放页面对象和自定义资源。 */
        lv_timer_del(s_page_timer);
        s_page_timer = NULL;
    }
}
```

初始化顺序通常是业务适配初始化、`setup_ui`、事件注册，再创建属于页面的定时器；具体顺序以当前生成源和调用方为准。页面销毁前先删除定时器和事件引用，再释放自定义资源。

## 验证

检查头文件/源文件/资源/构建清单一致性、句柄和事件引用、初始化与销毁配对、LVGL 版本 API 和编译结果。无 `.guiguider` 时不要要求寻找不存在的设计源。

交付列出实际修改的 `generated/`、`custom/`、平台/业务文件及导出覆盖风险。
