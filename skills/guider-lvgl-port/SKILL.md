---
name: "guider-lvgl-port"
description: "GUI Guider 导出工程的 LVGL 界面设计、代码导出、SDK 导入、generated/custom 目录隔离、数据绑定、刷新、资源和版本兼容规范。Use only when the task explicitly mentions GUI Guider or the target project contains both sibling custom/ and generated/ directories with Guider-generated files. Do not use for a standalone LVGL project, LVGL PC/SDL/Windows simulator, display/input driver, generic lv_ui or screen-widget work, or hand-written LVGL UI."
---

# LVGL 与 GUI Guider 设计、移植规范

## 适用范围
本 Skill 只处理确实属于 GUI Guider 导出工程的任务，不因出现 LVGL API、`lv_ui`、屏幕控件或模拟器配置而单独启用。优先使用目录证据判断，避免把普通 LVGL 模拟器误判为 Guider 工程。

## 触发判定（先执行）
按以下顺序判断，命中排除条件时不要套用本 Skill 的 Guider 导出目录规则：

1. **强证据：**目标工程中存在同级的 `custom/` 和 `generated/` 目录，并且 `generated/` 至少包含 `gui_guider.c/h`、`events_init.c/h`、`setup_scr_*.c` 或 `widgets_init.c/h` 等 Guider 生成文件。若工程根目录还存在与这两个目录同级的 `.guiguider` 文件，则同时启用“编译验证豁免规则”。
2. **明确指令：**用户明确说“GUI Guider”或“Guider 导出/重新导出”，但目录尚未生成时，可以启用本 Skill，并按新建导出工程处理。
3. **弱证据：**只有 `lvgl.h`、`lv_` API、`lv_ui`、屏幕/控件代码、`lv_conf.h`、`simulator`、`SDL`、`Windows`、`CMake` 或显示/输入驱动时，不足以触发本 Skill。
4. **排除项：**纯 LVGL 手写工程、LVGL PC/SDL/Windows 模拟器、LVGL demo、显示/触摸/输入驱动、通用 UI 刷新任务，不得使用本 Skill 的 Guider 目录覆盖、`generated/` 只读和导出流程规则。此时只遵循通用 C/C++、LVGL 或对应平台规则。
5. **不确定时：**暂不假定是 Guider 工程；先检查目录和文件名，再决定是否启用。不要仅凭 `custom` 或 `generated` 单个目录触发，两个目录缺一不可，除非用户明确指明 GUI Guider。

> 通用RT-Thread模式（LVGL任务协同、定时器刷新频率、互斥锁模式）见 `coding-rtthread-style` Skill。

## 触发场景
- 新建/修改GUI Guider UI工程
- 导出C代码导入RT-Thread SDK
- UI数据绑定、事件回调、页面切换开发
- 迭代修改UI布局、样式、控件
- UI性能、内存优化

## 核心执行规范

### 0. 编译验证豁免规则
当触发判定确认目标工程目录内存在 `.guiguider` 文件，并且该文件与 `custom/`、`generated/` 目录同级时，本 Skill 默认不对该工程的修改执行编译、构建或链接验证；除非用户明确要求编译验证。仍应完成与修改范围匹配的静态检查（例如控件句柄、函数声明和接口引用的一致性），并在交付说明中明确未执行编译验证及其适用边界。

### 1. Guider工程设计规范
1. 按页面拆分设计：主页、设置页、故障页、充电页等，每个页面对应独立UI文件
2. 控件命名必须见名知意，统一格式：`screen_控件类型_功能`，如 `screen_img_beam_left`、`screen_label_error_code`
3. 样式、颜色、字号、图标统一使用全局样式或主题，禁止逐个控件硬编码
4. 动画、页面切换效果优先使用Guider原生功能，减少自定义代码量

### 2. 目录结构规范（核心）
导出代码采用两层架构，严格区分「生成代码」与「适配代码」：

```
guider_xxx_demo/
├── custom/                  # 适配层（用户可修改）
│   ├── custom.c/h          # 【核心】数据池定义、定时器刷新、显示更新函数
│   ├── custom_file.c/h     # 图片路径宏定义、动画图片数组声明
│   └── lv_conf_ext.h       # LVGL配置扩展（board/simulator差异化）
│
├── generated/               # Guider生成层（默认只读；仅修改明确预留的用户代码区）
│   ├── gui_guider.c/h      # UI结构体定义、屏幕/动画辅助函数
│   ├── events_init.c/h     # 事件初始化（屏幕加载/卸载事件）
│   ├── setup_scr_screen.c  # 屏幕控件创建、样式设置、初始数据绑定
│   ├── widgets_init.c/h    # 控件初始化
│   ├── guider_fonts/       # 字体资源
│   ├── guider_customer_fonts/ # 自定义字体
│   └── images/             # 图片资源（按主题分类：dark/light/other/run）
│
├── ui_init.c/h             # UI初始化入口（调用custom_init/setup_ui/events_init）
├── lv_conf_custom.h        # LVGL自定义配置
└── SConscript              # 构建脚本
```

### 2.1 generated目录中的允许扩展区

`generated/` 默认由 GUI Guider 管理，不应把任意业务代码散落到生成文件中。以下范围是例外；以导出文件中的函数边界和生成语句位置判断，不以是否存在 `/* test */`、`USER CODE` 等注释标记作为前提。

1. **`generated/setup_scr_screen*.c`**：仅允许在 `setup_scr_screen...()` 函数所在文件中的下列位置添加自定义函数或辅助代码：
   - 最后一个项目自定义头文件（通常为 `#include "custom.h"`）之后、首个 `setup_scr_screen...()` 函数定义之前，用于声明或定义仅由该屏幕使用的静态辅助函数、回调和兼容函数；
   - `setup_scr_screen...()` 函数中，最后一个 Guider 生成的控件创建、属性设置或动画启动语句之后，`lv_obj_update_layout(ui->screen...)` 之前，用于设置生成控件的初始状态、注册补充回调或启动页面专属逻辑。
2. **`generated/events_init.c`**：可在下列稳定位置添加自定义函数、回调或调用：
   - 最后一个 `#include` 之后、第一个 Guider 生成的 `static void screen_..._event_handler(...)` 之前，用于文件私有辅助函数；
   - 各 `screen_..._event_handler()` 中 **Guider 已生成** 的事件 `case` 花括号内、`break` 之前，用于处理该页面事件；不得自行增加未由 Guider 生成的 `case`。当前导出模板可用事件为：
     - 点击与按压：`LV_EVENT_CLICKED`、`LV_EVENT_SHORT_CLICKED`、`LV_EVENT_PRESSED`、`LV_EVENT_PRESSING`、`LV_EVENT_PRESS_LOST`、`LV_EVENT_RELEASED`、`LV_EVENT_LONG_PRESSED`、`LV_EVENT_LONG_PRESSED_REPEAT`；
     - 值、滚动与焦点：`LV_EVENT_VALUE_CHANGED`、`LV_EVENT_SCROLL`、`LV_EVENT_SCROLL_BEGIN`、`LV_EVENT_SCROLL_END`、`LV_EVENT_FOCUSED`、`LV_EVENT_DEFOCUSED`、`LV_EVENT_LEAVE`、`LV_EVENT_HIT_TEST`、`LV_EVENT_KEY`；
     - 页面生命周期：`LV_EVENT_SCREEN_LOADED`、`LV_EVENT_SCREEN_UNLOADED`、`LV_EVENT_SCREEN_UNLOAD_START`、`LV_EVENT_SCREEN_LOAD_START`；
     - 手势：`LV_EVENT_GESTURE` 中 Guider 已生成的 `LV_DIR_LEFT`、`LV_DIR_RIGHT`、`LV_DIR_TOP`、`LV_DIR_BOTTOM` 分支，并保持 `lv_indev_wait_release()` 的生成调用。
   - 各 `events_init_screen...()` 函数体中，在 Guider 生成的 `lv_obj_add_event_cb()` 调用之后，用于补充该页面的事件初始化；
   - 总入口 `events_init()` 函数体中，用于全局事件初始化。
3. 允许扩展区只能承载与该生成文件直接相关的适配逻辑；跨页面复用的业务逻辑、数据池定义、资源宏和公共接口仍应放在 `custom/`。
4. 不得修改、删除或重排 Guider 生成的控件创建、样式属性、动画配置、事件注册和函数主体语句；只可在上述边界内新增代码。重新导出前必须备份这些扩展代码，导出后恢复并进行静态一致性检查；含同级 `.guiguider`、`custom/`、`generated/` 的工程是否编译按“编译验证豁免规则”处理。

### 3. 数据池设计规范（核心）
在`custom.h`中定义全局数据结构体，作为UI与业务层的唯一数据接口：

**示例结构体定义：**
```c
typedef struct __attribute__ (( packed )){
    uint8_t speed;                  // 仪表速度 0-150km/h
    uint8_t bat_level;              // 电量 0-100%
    uint32_t odo;                   // 总里程
    uint16_t trip;                  // 当前里程
    uint8_t gear;                   // 档位0-5
    uint8_t state_undervoltage;     // 欠压状态
    uint8_t state_ready;            // 就绪指示
    uint8_t state_tcs;              // TCS牵引力系统
    uint8_t state_steering_handle;  // 转向把手故障
    uint8_t state_brake;            // 刹车制动
    uint8_t state_motor;            // 电机故障
    uint8_t state_code;             // 故障代码
} meter_can_struct;

extern meter_can_struct g_meter_can_variable; // CAN通信数据池
extern meter_btn_struct g_meter_btn_variable; // 按钮状态数据池
extern meter_mcu_struct g_meter_mcu_variable; // MCU状态数据池
extern meter_temp_struct g_meter_temp_variable; // 中间变量（闪烁计数器）
```

**设计原则：**
- 数据池为唯一数据源，UI仅从数据池读取，业务层仅写入数据池
- 使用`__attribute__ (( packed ))`确保结构体紧凑，减少内存占用
- 按数据来源分类：CAN通信、按钮输入、MCU状态、中间变量

### 4. 数据绑定机制规范（核心）
采用定时器驱动模式，在`events_init.c`中注册屏幕加载事件：

**events_init.c标准模板：**
```c
static void screen_event_handler(lv_event_t *e)
{
    lv_event_code_t code = lv_event_get_code(e);
    switch (code) {
    case LV_EVENT_SCREEN_LOADED:
        screen_timer = lv_timer_create(screen_timer_cb, 200, &guider_ui); // 创建刷新定时器
        break;
    case LV_EVENT_SCREEN_UNLOADED:
        lv_timer_del(screen_timer); // 删除刷新定时器
        break;
    }
}

void events_init_screen(lv_ui *ui)
{
    lv_obj_add_event_cb(ui->screen, screen_event_handler, LV_EVENT_ALL, ui);
}
```

**custom.c定时器回调模板：**
```c
void screen_timer_cb(lv_timer_t *timer)
{
    lv_ui *ui = lv_timer_get_user_data(timer);

    // 1. 从数据池拷贝数据（使用互斥锁保护）
    can_meter_mutex_take();
    meter_can_struct meter_can_variable = g_meter_can_variable;
    can_meter_mutex_release();
    
    user_io_mutex_take();
    meter_btn_struct meter_btn_variable = g_meter_btn_variable;
    user_io_mutex_release();

    // 2. 根据显示模式选择图片资源（主题切换）
    if(meter_btn_variable.display_light_mode == DISPLAY_LIGHT_MODE_LIGHT) {
        lv_image_set_src(ui->screen_img_ready, IMG_PATH_LIGHT_READY);
        lv_obj_set_style_bg_color(ui->screen, lv_color_hex(0xffffff), LV_PART_MAIN);
    } else {
        lv_image_set_src(ui->screen_img_ready, IMG_PATH_DARK_READY);
        lv_obj_set_style_bg_color(ui->screen, lv_color_hex(0x000000), LV_PART_MAIN);
    }

    // 3. 调用显示刷新函数更新UI
    lv_user_img_speed_show(meter_can_variable.speed, meter_btn_variable.display_light_mode, meter_btn_variable.display_km_mile_mode);
    lv_user_bat_bar_show(meter_can_variable.bat_level, meter_btn_variable.display_light_mode);
    lv_user_gear_decide(meter_can_variable.gear, meter_btn_variable.display_light_mode);
}
```

**设计原则：**
- 定时器周期按页面特性设置：主页200ms高频刷新，设置页500ms低频刷新
- 使用局部变量拷贝数据池数据，避免在定时器中长时间持有互斥锁
- 所有 LVGL 控件操作必须在 LVGL 所属 UI 线程或统一串行执行上下文中完成；定时器回调只是可选入口，禁止从任意业务线程直接操作控件

### 5. 初始化流程规范
在`ui_init.c`中实现三步初始化：

**ui_init.c标准模板：**
```c
lv_ui guider_ui; // UI结构体定义

void ui_init(void)
{
    custom_init(&guider_ui);  // 1. 初始化数据池变量
    setup_ui(&guider_ui);     // 2. 创建控件、设置样式、初始数据绑定
    events_init(&guider_ui);  // 3. 注册事件回调
}
```

**setup_scr_screen.c特殊设计：**
- 控件创建后立即从数据池读取数据并设置初始显示
- 使用互斥锁保护数据池访问
- 主题切换逻辑必须在初始化时执行一次

**示例：**
```c
void setup_scr_screen(lv_ui *ui)
{
    // 1. 创建所有控件
    ui->screen = lv_obj_create(NULL);
    ui->screen_img_beam_left = lv_image_create(ui->screen);
    // ... 其他控件创建

    // 2. 从数据池读取数据（使用互斥锁）
    can_meter_mutex_take();
    meter_can_struct meter_can_variable = g_meter_can_variable;
    can_meter_mutex_release();

    // 3. 设置初始显示
    lv_user_img_speed_show(meter_can_variable.speed, meter_btn_variable.display_light_mode, meter_btn_variable.display_km_mile_mode);
    
    // 4. 注册事件
    events_init_screen(ui);
}
```

### 6. 显示刷新函数设计规范
在`custom.c`中封装显示刷新函数，命名格式：`lv_user_功能_show()`

**常见刷新函数模式：**

**数字显示（使用图片数字）：**
```c
void lv_user_img_speed_show(uint16_t speed, uint8_t display_light_mode, uint8_t display_km_mile_mode)
{
    lv_ui *ui = &guider_ui;
    uint8_t digit;
    const char **table = (display_light_mode == DISPLAY_LIGHT_MODE_LIGHT) ? num_light : num_dark;

    // 单位转换（km/mile）
    uint16_t speed_km_mile = (display_km_mile_mode == DISPLAY_KM_MILE_MODE_KM) ? speed : (uint64_t)speed * 62137 / 100000;

    // 根据位数动态显示
    if (speed_km_mile < 100) {
        lv_obj_add_flag(ui->screen_img_speed3, LV_OBJ_FLAG_HIDDEN); // 隐藏百位
        digit = speed_km_mile % 10;
        lv_image_set_src(ui->screen_img_speed1, table[digit]);
    } else {
        lv_obj_clear_flag(ui->screen_img_speed3, LV_OBJ_FLAG_HIDDEN);
        digit = speed_km_mile % 10;
        lv_image_set_src(ui->screen_img_speed1, table[digit]);
    }
}
```

**进度条显示（使用图片数组）：**
```c
void lv_user_bat_bar_show(uint8_t bat_level, uint8_t display_light_mode)
{
    lv_ui *ui = &guider_ui;
    uint8_t icon_idx = (bat_level - 1) / 10 + 1; // 0-100转换为1-10档位

    if(icon_idx > 10) icon_idx = 10; // 范围钳位
    if(icon_idx < 1) icon_idx = 1;

    // 根据档位和主题选择图片
    switch(icon_idx) {
        case 1:
            lv_image_set_src(ui->screen_img_bat_level_left, IMG_PATH_LIGHT_POWER_LEFT1);
            break;
        // ... 其他档位
    }
}
```

**图标状态显示（显示/隐藏）：**
```c
void lv_user_icon_state_decide(lv_obj_t *obj, uint8_t state)
{
    switch(state) {
        case LV_METER_STATE_ON:
            lv_obj_clear_flag(obj, LV_OBJ_FLAG_HIDDEN); // 显示图标
            break;
        case LV_METER_STATE_OFF:
            lv_obj_add_flag(obj, LV_OBJ_FLAG_HIDDEN); // 隐藏图标
            break;
    }
}
```

**闪烁动画（定时器驱动）：**
```c
void lv_user_beam_blink_state_decide(lv_obj_t *obj, uint8_t state, uint8_t *blink_count)
{
    switch(state) {
        case LV_METER_STATE_ON:
            if(*blink_count < BEAM_BLINK_PHASE_COUNT) // 前半周期显示
                lv_obj_clear_flag(obj, LV_OBJ_FLAG_HIDDEN);
            else // 后半周期隐藏
                lv_obj_add_flag(obj, LV_OBJ_FLAG_HIDDEN);
            
            (*blink_count)++;
            if(*blink_count >= BEAM_BLINK_TOTAL_COUNT) // 循环计数
                *blink_count = 0;
            break;
        case LV_METER_STATE_OFF:
            lv_obj_add_flag(obj, LV_OBJ_FLAG_HIDDEN);
            *blink_count = 0; // 重置计数
            break;
    }
}
```

### 7. 资源管理规范
在`custom_file.h`中定义图片路径宏，按主题分类：

**Simulator模式（本地Windows路径）：**
```c
#define LV_USE_GUIDER_SIMULATOR_IMG_PATH  "./assets/images/"
#define IMG_PATH_LIGHT_READY      LV_USE_GUIDER_SIMULATOR_IMG_PATH"light_ready.png"
#define IMG_PATH_DARK_READY       LV_USE_GUIDER_SIMULATOR_IMG_PATH"dark_ready.png"
```

**Board模式（文件系统分区路径）：**
```c
#define LV_USE_GUIDER_IMG_PATH "L:/rodata/"
#define IMG_PATH_LIGHT_READY    LV_USE_GUIDER_IMG_PATH"light/light_ready.png"
#define IMG_PATH_DARK_READY     LV_USE_GUIDER_IMG_PATH"dark/dark_ready.png"
```

**主题分类目录结构：**
```
images/
├── dark/         # 黑夜主题（黑色背景）
│   ├── dark_km_odo_bg.png
│   ├── dark_num0.png ~ dark_num9.png
│   └── dark_power_left1.png ~ dark_power_left10.png
├── light/        # 白天主题（白色背景）
│   ├── light_km_odo_bg.png
│   ├── light_num0.png ~ light_num9.png
│   └── light_power_left1.png ~ light_power_left10.png
├── other/        # 共用资源（不依赖主题）
│   ├── brake.png
│   ├── tcs.png
│   └── motor.png
└── run/          # 运行动画（按主题分类）
    ├── light_run_left1.png ~ light_run_left25.png
    └── dark_run_left1.png ~ dark_run_left25.png
```

**动画图片数组声明：**
```c
extern const char * screen_animimg_light_run_down_imgs[3];
extern const char * screen_animimg_light_run_left_imgs[26];
extern const char * screen_animimg_light_run_right_imgs[26];
```

### 8. 主题切换机制
通过`display_light_mode`判断当前主题，动态选择图片资源：

**切换逻辑：**
```c
if(meter_btn_variable.display_light_mode == DISPLAY_LIGHT_MODE_LIGHT) {
    // 1. 切换图标资源
    lv_image_set_src(ui->screen_img_ready, IMG_PATH_LIGHT_READY);
    lv_image_set_src(ui->screen_img_ble, IMG_PATH_LIGHT_BLE);
    
    // 2. 切换背景色
    lv_obj_set_style_bg_color(ui->screen, lv_color_hex(0xffffff), LV_PART_MAIN);
    
    // 3. 切换背景图
    lv_obj_set_style_bg_image_src(ui->screen, IMG_PATH_LIGHT_KM_ODO_BG, LV_PART_MAIN);
    
    // 4. 切换动画图片源（需要重启动画）
    lv_animimg_set_src(ui->screen_animimg_run_left, (const void **) screen_animimg_light_run_left_imgs, 26);
    lv_animimg_start(ui->screen_animimg_run_left);
}
```

**切换时机：**
- 定时器刷新时检查`display_light_mode`变化
- 如果主题变更，重新设置所有图片源并重启动画

### 9. LVGL版本适配
针对LVGL版本差异进行适配：

**LVGL 9.1.0 vs 9.3.0动画差异：**
```c
#if LVGL_VERSION_MAJOR < 9 || (LVGL_VERSION_MAJOR == 9 && LVGL_VERSION_MINOR < 3)
    // LVGL 9.1.0需要手动设置动画值范围
    lv_animimg_t *ai;
    ai = (lv_animimg_t *)ui->screen_animimg_run_down;
    lv_anim_set_values(&ai->anim, 0, ai->pic_count);
#endif
```

### 10. 导出与导入流程
1. 导出选择「Pure C」代码格式，LVGL版本必须与SDK中版本完全一致
2. 导出代码完整拷贝到工程 `packages/artinchip/lvgl-ui/aic_demo/guider_xxx_demo/` 目录，直接覆盖generated/目录
3. custom/目录保留不覆盖，适配层代码手动同步
4. 首次导入必须适配LVGL显示驱动、输入设备驱动，验证屏幕刷新、触控/按键输入正常

### 11. 迭代修改规则
1. UI布局、样式、控件增删必须在GUI Guider中修改，重新导出覆盖generated/目录
2. 业务逻辑、数据绑定、自定义动画原则上在custom/目录修改；只有需要紧邻生成函数的适配代码，才可按“2.1 generated目录中的允许扩展区”写入对应的`setup_scr_screen*.c`或`events_init.c`用户代码区
3. `generated/setup_scr_screen*.c`允许扩展区仅限：最后一个项目自定义头文件与首个`setup_scr_screen...()`定义之间，以及函数内最后一条Guider生成的控件/动画配置语句与`lv_obj_update_layout()`之间；无需依赖注释标记判断
4. `generated/events_init.c`允许扩展区仅限：最后一个`#include`后、首个页面事件处理函数前；Guider已生成的事件`case`体内且位于`break`前；`events_init_screen...()`中Guider事件注册调用后；以及`events_init()`函数体内。未生成对应`case`的事件暂不自行添加；事件初始化主体和 Guider 生成语句不得改写
5. 修改后必须进行静态一致性检查：
   - `lv_ui`结构体中控件句柄是否变更（如`screen_img_beam_left`是否新增/删除）
   - `setup_scr_screen()`函数中控件创建顺序是否变更
   - 同步更新custom.c中控件访问代码
   - 允许扩展区中的函数声明、定义和`custom.h`接口是否仍然匹配
   - 依据“编译验证豁免规则”，含同级 `.guiguider`、`custom/`、`generated/` 的工程默认不执行编译、构建或链接验证；用户明确要求时再执行
6. 重大UI改版前，备份custom/目录及generated用户代码区，防止导出后控件句柄或用户扩展丢失

### 12. 性能与资源规范
1. 图片资源推荐使用文件系统加载（PNG格式），避免C数组占用RAM
2. 大尺寸图片按主题拆分目录，按需加载当前主题资源
3. UI刷新频率按需设置：主页200ms，设置页500ms，降低CPU占用
4. 所有数值显示必须做范围钳位，异常数据显示占位符，禁止出现乱码、越界数值
5. 定时器回调中避免复杂计算，提前在数据池中预处理数据

### 13. 互斥锁使用规范
数据池访问必须使用互斥锁保护：

**正确用法：**
```c
can_meter_mutex_take();
meter_can_struct meter_can_variable = g_meter_can_variable; // 拷贝数据
can_meter_mutex_release();

// 使用局部变量meter_can_variable进行显示操作
lv_user_img_speed_show(meter_can_variable.speed, ...);
```

**错误用法：**
```c
can_meter_mutex_take();
lv_user_img_speed_show(g_meter_can_variable.speed, ...); // 在锁内调用LVGL接口
can_meter_mutex_release(); // 可能导致死锁或长时间阻塞
```

## 输出要求
1. 新增/修改UI必须说明：Guider操作点、导出后适配层修改点、数据来源
2. 必须明确区分「自动生成代码（generated/）」、`generated/`中的Guider用户代码区与「自定义适配代码（custom/）」
3. 涉及资源修改必须说明内存占用变化与优化建议
4. 迭代修改必须说明控件句柄变更、接口兼容性注意事项
5. 数据绑定必须说明数据池结构体、定时器刷新频率、互斥锁保护机制

## 典型开发流程示例

**场景：新增速度显示功能**

1. **Guider设计阶段**：
   - 在screen页面添加3个Image控件，命名为`screen_img_speed1`、`screen_img_speed2`、`screen_img_speed3`
   - 导入数字图片资源（light_speed_num0.png ~ light_speed_num9.png）

2. **导出导入阶段**：
   - 导出Pure C代码，覆盖generated/目录
   - 检查lv_ui结构体新增3个控件句柄

3. **适配层开发阶段**：
   - 在custom.h中添加`uint8_t speed`字段到meter_can_struct
   - 在custom_file.h中添加图片路径宏定义
   - 在custom.c中编写`lv_user_img_speed_show()`函数
   - 在screen_timer_cb()中调用刷新函数

4. **业务层对接阶段**：
   - CAN通信模块解析速度数据，写入`g_meter_can_variable.speed`
   - 使用互斥锁保护写入操作

5. **测试验证阶段**：
   - 验证速度显示范围0-150
   - 验证主题切换（dark/light图片切换）
   - 验证单位切换（km/mile转换）
