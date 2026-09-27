# Guider 1.x 导出源代码修改

## 适用范围和任务边界

仅在总 Skill 已确认目标为 LVGL + Guider 1.x 工程，并且用户要求修改 C/LVGL、`generated/`、`custom/`、平台适配、数据绑定、刷新、资源或构建配置时使用。

`source-edit` 的写入边界与 `project-edit` 不同：

- 无论工程是否仍保留 `.guiguider`，`generated/` 和 `custom/` 都是本任务的可读写目标。
- 有 `.guiguider` 时，`generated/` 修改仅用于导出 C/LVGL、事件补充、资源适配和构建修复；页面布局、控件树、样式和设计事件结构仍回到 `.guiguider` 的 `project-edit`。
- 有 `.guiguider` 的工程再次由 GUI Guider 导出时可能覆盖 `generated/` 修改；交付必须报告该风险。
- 无 `.guiguider` 时，`generated/` 是当前导出工程的实际源代码，不要求寻找不存在的设计源；可直接维护 C/H、事件、屏幕初始化、资源和构建清单。
- `custom/` 保存业务逻辑和适配层，在两类工程中都可持久修改。

## 1.x 输出识别和修改前检查

典型 1.x 结构包括：

```text
generated/
├── gui_guider.c
├── gui_guider.h
├── events_init.c / events_init.h
├── setup_scr_*.c
├── widgets_init.c / widgets_init.h
├── images/
├── guider_fonts/
└── guider_customer_fonts/
custom/
├── custom.c / custom.h
├── custom_file.c / custom_file.h
└── lv_conf_ext.h
```

修改前必须读取：

1. `generated/gui_guider.h` 中的 `lv_ui` 结构和当前控件句柄；
2. 对应 `setup_scr_*.c`、`events_init.c/h` 和 `widgets_init.c/h` 的调用关系；
3. `custom/` 的公共接口、数据池、资源宏和初始化入口；
4. CMake、SCons、Makefile 或项目工程中的实际源文件列表；
5. `lv_conf.h`/`lv_conf_ext.h` 和实际 `LVGL_VERSION_*`。

不能只根据文件名假定 API 版本或句柄名称。

## 页面和控件设计规范

页面按主页、设置页、故障页、充电页等业务边界拆分。控件命名建议使用：

```text
<页面名>_<控件类型>_<功能>
```

例如 `screen_img_speed_ones`、`screen_label_error_code`、`settings_slider_brightness`。新增或改名时必须同步检查 `lv_ui`、事件代码和 `custom/` 引用。样式、颜色、字号和图标优先使用统一主题或公共样式；动画和页面切换优先使用 GUI Guider 已导出的机制，避免重复实现设计源逻辑。

## 目录和职责

```text
guider_demo/
├── custom/                  # 业务、数据池、刷新、资源适配和公共接口
├── generated/               # source-edit 中可维护的当前 1.x C/H、资源和构建源
├── ui_init.c/h              # UI 初始化入口
├── lv_conf_custom.h         # 项目 LVGL 配置
└── SConscript/CMakeLists.txt
```

修改 `generated/` 前必须先确认它确实属于 source-edit 任务。`project-edit` 阶段不得把补丁写入该目录。导出工程中对生成文件的修改应作为普通源代码审查，保持头文件、源文件、资源和构建清单一致。

## 数据池设计

在 `custom.h` 中定义 UI 与业务之间的稳定数据接口。按实际项目将数据分为通信、按键、MCU 状态和 UI 中间状态等域；示意：

```c
typedef struct {
    uint16_t speed;
    uint8_t battery_level;
    uint32_t odometer;
    uint8_t gear;
    uint8_t warning_state;
} guider_meter_data_t;

extern guider_meter_data_t g_guider_meter_data;
```

数据池是唯一数据源：业务或通信层写入，UI 适配层读取。不要让刷新函数直接访问通信缓冲区，也不要把 LVGL 对象句柄暴露给通信线程。结构体是否使用紧凑布局必须以对齐、协议和项目 ABI 要求为依据，不能无证据添加 `packed`。

## 数据绑定和定时器刷新

页面数据通常由 LVGL 定时器刷新。定时器周期按页面复杂度和实时性选择，例如主页约 200 ms、设置页约 500 ms，必须以实际性能需求校准。

推荐生命周期：

```c
static lv_timer_t *s_screen_timer;

static void screen_timer_cb(lv_timer_t *timer)
{
    lv_ui *ui = lv_timer_get_user_data(timer);
    guider_meter_data_t local_data;

    guider_data_lock();
    local_data = g_guider_meter_data;
    guider_data_unlock();

    lv_user_speed_show(ui, local_data.speed);
    lv_user_battery_show(ui, local_data.battery_level);
}
```

屏幕加载时只创建一次定时器，屏幕卸载或销毁时删除，并在删除前检查句柄有效性。所有 LVGL 操作必须运行在 LVGL 所属线程或统一串行上下文，业务线程和 ISR 不得直接操作控件。

## 初始化流程

先读取工程真实入口，再决定顺序。常见流程为：

```c
void ui_init(void)
{
    custom_init(&guider_ui);
    setup_ui(&guider_ui);
    events_init(&guider_ui);
}
```

`custom_init` 负责持久化数据和适配初始化，`setup_ui` 负责生成控件创建与初始状态，`events_init` 负责事件注册。不要在 `custom/` 复制生成控件创建逻辑，也不要在入口重复注册事件。初始显示可以在控件创建完成后读取一次数据池，但应复用与定时刷新相同的刷新函数。

## 显示刷新函数

在 `custom.c` 中封装显示逻辑，接口命名应表达功能，例如 `lv_user_speed_show`、`lv_user_battery_show`、`lv_user_warning_state_show`。刷新函数只接收已验证的数据和当前句柄，不承担通信解析。

常见模式：

- 数字显示：先做单位转换和范围钳位，再按位更新图片或文本；无效数据使用项目约定的占位显示。
- 进度显示：把 0 到最大值映射到有限图片档位，计算后钳位到合法索引。
- 状态图标：使用 `LV_OBJ_FLAG_HIDDEN` 或当前 LVGL 版本对应 API 显示/隐藏，覆盖未知状态。
- 闪烁：使用定时器计数或 LVGL 动画，状态关闭时重置计数，避免卸载页面后继续访问句柄。

示例：

```c
static uint8_t guider_level_to_icon(uint8_t level)
{
    if (level > 100U) {
        level = 100U;
    }
    return (uint8_t)((level + 9U) / 10U);
}
```

## 主题和资源

资源路径必须从当前平台构建配置确认，不能凭示例写死绝对路径。可在 `custom_file.h` 中集中定义宏，并区分模拟器和板端文件系统：

```c
#define GUIDER_SIM_IMAGE_ROOT "./assets/images/"
#define GUIDER_BOARD_IMAGE_ROOT "L:/rodata/"
#define IMG_LIGHT_READY GUIDER_SIM_IMAGE_ROOT "light/ready.png"
```

实际使用哪一个根目录由项目配置选择。资源按主题、公共图标和动画序列组织；大图片优先文件系统按需加载，避免把完整图片数组长期放在 RAM。主题切换时应同步切换图标、背景、字体颜色和动画图片源，并在切换后按当前 API 重新启动动画。

主题切换至少要覆盖背景、状态图标和动画源，示意：

```c
if (display_light_mode == DISPLAY_LIGHT_MODE_LIGHT) {
    lv_img_set_src(ui->screen_img_ready, IMG_LIGHT_READY);
    lv_obj_set_style_bg_color(ui->screen, lv_color_hex(0xffffff), LV_PART_MAIN);
    lv_animimg_set_src(ui->screen_anim_run,
                       (const void **)screen_animimg_light_run_imgs,
                       screen_animimg_light_run_count);
} else {
    lv_img_set_src(ui->screen_img_ready, IMG_DARK_READY);
    lv_obj_set_style_bg_color(ui->screen, lv_color_hex(0x000000), LV_PART_MAIN);
    lv_animimg_set_src(ui->screen_anim_run,
                       (const void **)screen_animimg_dark_run_imgs,
                       screen_animimg_dark_run_count);
}
lv_animimg_start(ui->screen_anim_run);
```

动画图片数组和数量应在持久化适配文件中集中声明，避免在多个生成源文件中复制路径：

```c
extern const void *screen_animimg_light_run_imgs[];
extern const void *screen_animimg_dark_run_imgs[];
extern uint16_t screen_animimg_light_run_count;
extern uint16_t screen_animimg_dark_run_count;
```

## LVGL 版本适配

以实际 `lv_conf.h`、头文件和编译配置为准。LVGL 8.x 常见 API 包括 `lv_img_set_src`、`lv_obj_add_flag` 和 `lv_animimg_set_src`；如果项目使用兼容封装，优先调用项目封装。不同小版本的动画范围、图片对象和事件枚举可能不同，必要时通过版本宏隔离：

```c
#if LVGL_VERSION_MAJOR == 8
/* 按当前项目的 LVGL 8.x API 设置动画参数。 */
#endif
```

不要把 LVGL 9.x 的 `lv_image_*` API 直接复制到 1.x 工程。

## 导出、导入和迭代

GUI Guider 导出格式、LVGL 版本和 SDK 版本必须匹配。导出或复制文件前记录 `lv_ui` 句柄、页面函数、事件函数和资源清单。无 `.guiguider` 的导出工程可以直接维护 `generated/`；有 `.guiguider` 的工程重新导出时应先备份 source-edit 修改并在导出后重新合并或复核。

每次页面或控件变更后检查：

1. `lv_ui` 是否新增、删除或重命名字段；
2. `setup_scr_*.c` 的创建顺序和父子关系是否变化；
3. `custom.c/h`、事件回调、页面切换和动画目标是否仍引用存在的句柄；
4. 构建脚本是否收集了新的 C/H 和资源；
5. 资源路径、字体和图片数量是否与目标平台一致。

旧版本中所谓“用户代码区”不再作为权限例外。source-edit 对 `generated/` 的修改范围由任务授权决定；有 `.guiguider` 的工程需报告可覆盖风险，无 `.guiguider` 的工程按普通源文件维护。

## 性能、资源和并发

- 定时器回调中避免复杂计算和文件扫描，预处理值放入数据池。
- 数值、索引和动画帧必须范围钳位；异常值显示安全占位符。
- 图片按主题拆分并按需加载，检查解码缓冲和缓存占用。
- 数据池使用项目实际的互斥锁、临界区或消息机制；不同数据域不要无依据共享一把大锁。
- 锁内只复制数据，释放锁后再执行 LVGL、文件和资源操作。

正确模式：

```c
guider_data_lock();
guider_meter_data_t local_data = g_guider_meter_data;
guider_data_unlock();
lv_user_speed_show(&guider_ui, local_data.speed);
```

错误模式是在持锁期间调用 LVGL 或等待另一个锁，可能造成长时间阻塞或死锁。

## 典型开发流程：新增速度显示

1. 在设计源中添加控件和资源；存在 `.guiguider` 时使用 `project-edit` 修改并重新导出。
2. 读取 `generated/gui_guider.h`，确认新的 `lv_ui` 句柄。
3. 在 `custom.h` 增加速度数据接口，在 `custom_file.h` 增加资源路径。
4. 在 `custom.c` 实现 `lv_user_speed_show`，在页面定时器中调用。
5. 业务通信模块在锁保护下写入数据池，UI 定时器复制后在 LVGL 线程刷新。
6. 验证范围钳位、单位切换、主题资源、页面加载/卸载和异常数据显示。

## 验证和交付

至少执行静态检查：头文件声明和调用一致、句柄存在、事件回调签名一致、资源路径可追溯、构建源列表正确、LVGL 操作处于正确线程、数据锁不跨越 LVGL 调用。

编译只在用户明确要求并实际执行后报告。交付时列出：

- 工程是否仍有 `.guiguider`；
- 修改的 `generated/`、`custom/`、平台、业务和构建文件；
- 句柄、事件、资源和线程验证结果；
- 原始工程重新导出覆盖风险；
- 未验证的模拟器/板端运行风险；
- 新增或修改注释语言。没有注释变化时明确说明。
