# Guider 2.x 导出源修改

## 适用范围

仅在总 Skill 已确认 Guider 2.x 且任务属于 `source-edit` 时加载。`generated/` 和 `custom/` 可按任务读写。

## 修改前

- 从 `generated/gg_utils.*` 和头文件确认 `gg_ui_t`、页面/层/控件字段。
- 检查 `generated/screens/`、`events/`、`assets/` 和 `custom/` 的初始化、数据池、刷新与资源接口。
- 有 `.guiguider` 时，设计结构回到 `project-edit`，source-edit 对生成文件的修改可能被覆盖；无设计源时按普通 C/LVGL 源维护。

## 代码边界

- `generated/` 维护当前 2.x 导出的页面、层、事件、资源和构建源；`custom/` 放业务和平台适配。
- 事件回调、`gg_ui_t` 字段、页面生命周期和资源清单必须保持同步，不从旧版本句柄格式猜测新结构。
- 定时器和刷新回调随页面创建/卸载管理；UI 线程边界遵循项目实现。
- UI 只读取数据池快照；页面/层级结构需求不得用 C 文件补丁替代设计源修改。

## 最小实现模板

以下代码只展示 2.x 的句柄和生命周期形态，实际字段、初始化函数和 LVGL API 必须以当前生成文件为准。

```c
/* 定时器与当前 2.x screen 生命周期绑定，离开页面必须先删除。 */
static lv_timer_t *s_screen_timer;

/**
 * @brief 2.x screen 刷新定时器回调，复制数据快照后更新控件。
 * @param[in] timer 当前 screen 定时器；user_data 必须仍指向有效界面对象。
 * @return 无；控件刷新必须运行在项目规定的 LVGL 线程。
 */
static void screen_timer_cb(lv_timer_t *timer)
{
    /* user_data 必须是 screen_enter 传入且仍然有效的 gg_ui_t。 */
    gg_ui_t *ui = lv_timer_get_user_data(timer);
    project_data_t snapshot; /* 锁内复制的数据快照；离开锁后供控件刷新使用。 */

    if (ui == NULL) {
        return;
    }
    /* 锁只保护快照复制，控件刷新和渲染必须在锁外完成。 */
    project_data_lock();
    snapshot = project_data_snapshot();
    project_data_unlock();

    /* 不要把 2.x 句柄字段按 1.x 名称猜测，先以生成头文件核对。 */
    project_update_2x_widget(ui, &snapshot);
}

/**
 * @brief 进入 2.x screen 并创建刷新定时器。
 * @param[in] ui 当前 screen 句柄；不能为空，生命周期必须覆盖回调执行期。
 * @return 无；创建失败时必须进入项目定义的降级或错误上报流程。
 */
void screen_enter(gg_ui_t *ui)
{
    if (ui == NULL) {
        return;
    }
    s_screen_timer = lv_timer_create(screen_timer_cb,
                                     PROJECT_REFRESH_PERIOD_MS, ui);
    /* 创建失败时必须进入项目定义的降级或错误上报流程。 */
}

/**
 * @brief 离开 2.x screen 并注销刷新定时器。
 * @return 无；删除定时器后才允许释放 screen 和控件资源。
 */
void screen_leave(void)
{
    if (s_screen_timer != NULL) {
        /* 先注销定时器，避免回调与 screen/控件释放并发发生。 */
        lv_timer_del(s_screen_timer);
        s_screen_timer = NULL;
    }
}
```

2.x 页面、层和控件字段不能从 1.x 名称推导；先读取 `gg_ui_t` 和目标页面/层的生成头文件，再绑定控件。设计源存在时，结构变化回到 `project-edit`。

## 验证

检查 `gg_ui_t` 句柄、页面/层/事件/资源引用、初始化与释放、LVGL 版本 API、构建清单和编译结果。重新导出前后记录字段和资源清单，扫描 `custom/` 与平台代码中的旧引用。

交付列出实际修改的 `generated/`、`custom/`、平台/业务文件及导出覆盖风险。
