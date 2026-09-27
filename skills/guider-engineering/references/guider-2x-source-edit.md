# Guider 2.x 导出源代码修改

## 适用范围和任务边界

仅在总 Skill 已确认目标为 LVGL + Guider 2.x 工程，并且用户要求修改 C/LVGL、`generated/`、`custom/`、平台适配、数据绑定、刷新、资源或构建配置时使用。

`source-edit` 下 `generated/` 和 `custom/` 都可读写：

- 有 `.guiguider` 的原始工程：允许修改导出的 C/LVGL、事件补充、资源适配和构建源；页面树、控件布局、样式和设计事件结构必须回到 2.x `project-edit`。再次从设计源导出可能覆盖 `generated/` 修改。
- 无 `.guiguider` 的导出工程：`generated/` 是当前 2.x 源代码，可直接维护屏幕、层、事件、工具文件、资源和构建清单，不要求寻找不存在的设计源。
- `custom/` 在两类工程中都用于业务逻辑、数据池、刷新、平台适配和持久资源。

## 2.x 输出识别和修改前检查

典型输出包括：

```text
generated/
├── gui_guider.h
├── gg_utils.c / gg_utils.h
├── screens/gg_screen_*.c
├── screens/gg_layer_*.c
├── events/gg_event_*.c
├── events/gg_event.h
└── assets/images/、assets/fonts/
custom/
├── custom.c / custom.h
├── custom_file.c / custom_file.h
└── lv_conf_ext.h
```

修改前读取：

1. `generated/gui_guider.h` 和 `gg_utils.*` 中的 `gg_ui_t`、`gg_screen_*_t`、`gg_layer_*_t` 定义；
2. 目标 `gg_screen_*`、`gg_layer_*` 和 `gg_event_*` 的初始化与调用关系；
3. `custom/` 的初始化入口、数据池、资源宏和公共接口；
4. 工程构建清单以及平台配置导出的 LVGL 版本；
5. 资源符号、图片尺寸、字体声明和文件系统路径。

必须以当前头文件和实际 API 为准，不能只根据 2.x 文件名猜测句柄结构。

## 页面、层和控件句柄

2.x 页面通常由屏幕和 `layer_sys`、`layer_top`、`layer_bottom` 等层组成。生成结构可能类似：

```c
typedef struct {
    lv_obj_t *screen;
    lv_obj_t *speed_value;
} gg_screen_main_t;

typedef struct {
    gg_screen_main_t screen_main;
} gg_ui_t;
```

实际访问可能是 `ui->screen_main.speed_value` 或项目封装形式，必须从当前头文件确认。页面和控件的设计命名建议保持 `<页面>_<类型>_<功能>`，source-edit 只维护句柄使用，不凭生成 C 文件反推设计树。

## 目录和职责

```text
guider_demo/
├── custom/                  # 数据池、刷新、资源适配、平台和业务接口
├── generated/               # source-edit 中可维护的当前 2.x C/H、资源和构建源
│   ├── screens/
│   ├── events/
│   ├── assets/
│   └── gg_utils.*
├── ui_init.c/h
└── CMakeLists.txt/SConscript
```

修改 `generated/` 前确认任务是 source-edit。设计结构变更应在 `.guiguider` 中完成并重新生成；生成后再用 source-edit 修复业务接口、平台差异和导出源代码。

## 数据池和线程模型

数据池是业务层、通信层和 UI 层之间的唯一接口。建议在 `custom.h` 中按实际项目定义通信、按键、状态和 UI 中间变量结构体；业务写入数据池，UI 线程读取数据池，不让业务线程持有 `lv_obj_t *`。

所有 LVGL 操作必须在 LVGL 所属线程或项目约定的统一串行上下文执行。跨线程读写使用工程已有的互斥锁、消息队列或事件机制。定时器回调中先锁内复制数据，再释放锁并调用刷新函数：

```c
guider_data_lock();
guider_meter_data_t local_data = g_guider_meter_data;
guider_data_unlock();

lv_user_speed_show(&guider_ui, local_data.speed);
```

禁止在锁内调用 LVGL、文件系统、日志或等待另一个锁。

## 初始化和页面生命周期

读取工程实际入口后确认 `custom_init`、`setup_ui`、页面加载函数和事件注册的顺序。常见流程为：

```c
void ui_init(void)
{
    custom_init(&guider_ui);
    setup_ui(&guider_ui);
    events_init(&guider_ui);
}
```

2.x 的 `custom_init(gg_ui_t *ui)` 只放持久化初始化和适配入口，不复制 `gg_screen_*` 的控件创建逻辑。屏幕加载时创建刷新定时器一次，屏幕卸载时删除，删除前验证句柄；不要让业务线程直接更新控件。页面切换和动画目标必须使用当前 `gg_ui_t` 句柄。

## 定时器和显示刷新

按页面实时性设置刷新周期，例如主页约 200 ms、设置页约 500 ms，最终以帧率和 CPU 占用验证。刷新函数放在 `custom.c` 或工程约定的适配目录，使用功能命名：

- 数字：先做单位转换、有效性检查和范围钳位，再更新文本、图片数字或当前项目的文本组件；
- 进度：把输入范围映射到有限档位，索引始终钳位；
- 图标状态：显示、隐藏或切换资源，覆盖未知状态；
- 闪烁和动画：由 LVGL 动画或页面定时器驱动，页面卸载时停止或删除，状态关闭时重置计数。

不要在刷新函数中解析 CAN/串口数据或直接读取未加锁的通信缓冲区。

## 资源、主题和路径

2.x 设计源通常使用 `resources/image`、`resources/font`；导出工程可能输出到 `generated/assets/`。source-edit 中应区分：

- 仍存在 `.guiguider` 时，设计资源配置回到 `project-edit`，`generated/assets/` 可作为导出源修改但可能被覆盖；
- 无 `.guiguider` 时，`generated/assets/` 是当前资源源，可维护图片、字体和资源清单；
- `custom/user_img` 或项目指定的外部资源用于持久化用户资源。

模拟器和板端路径必须从构建配置确认。主题切换应同步背景、图标、字体颜色和动画图片源，并在更换图片数组后按当前 LVGL API 重新启动动画。大图片优先文件系统按需加载，检查解码缓存和 RAM 占用。

主题切换的适配逻辑应集中在 `custom/` 或 source-edit 明确维护的导出文件中，示意：

```c
if (display_light_mode == DISPLAY_LIGHT_MODE_LIGHT) {
    lv_image_set_src(ui->screen_main.ready_icon, IMG_LIGHT_READY);
    lv_obj_set_style_bg_color(ui->screen_main.screen, lv_color_hex(0xffffff), LV_PART_MAIN);
    lv_animimg_set_src(ui->screen_main.run_anim,
                       (const void **)screen_animimg_light_run_imgs,
                       screen_animimg_light_run_count);
} else {
    lv_image_set_src(ui->screen_main.ready_icon, IMG_DARK_READY);
    lv_obj_set_style_bg_color(ui->screen_main.screen, lv_color_hex(0x000000), LV_PART_MAIN);
    lv_animimg_set_src(ui->screen_main.run_anim,
                       (const void **)screen_animimg_dark_run_imgs,
                       screen_animimg_dark_run_count);
}
lv_animimg_start(ui->screen_main.run_anim);
```

具体对象字段和 API 以当前 2.x 生成头文件及 LVGL 小版本为准。

## LVGL 9.x 适配

以当前工程 `lv_conf.h`、头文件和构建配置为准。2.x 常见 LVGL 9.x API 使用 `lv_image_*`、新的对象类型和事件接口，但不同小版本仍可能有差异。必要时用版本宏或项目封装隔离：

```c
#if LVGL_VERSION_MAJOR >= 9
/* 使用当前项目验证过的 LVGL 9.x 图片、事件和动画 API。 */
#endif
```

不要把 1.x 的 `lv_img_*` 调用或 2.x 示例中的未验证 API 直接复制到当前工程。

## 事件和生成源修改

`generated/events/gg_event_*.c` 中的事件回调必须保持与 `gg_event.h` 和当前 `gg_ui_t` 一致。source-edit 可以按任务修改事件适配、回调注册、页面动画和生成 C/H；修改后检查：

1. 回调签名和事件枚举存在；
2. `ui->screen_name.control_name` 句柄仍在头文件中；
3. 页面切换目标、动画对象和资源符号存在；
4. `gg_utils.*` 与 screens/events 的公共声明一致；
5. 构建清单包含新增或修改的源文件。

若需求是增加页面、修改控件层级或改变设计事件结构，停止直接修改生成 C，回到 `guider-2x-project-edit.md`。

## 导出、导入和迭代

导出时确认 GUI Guider 2.x、LVGL 版本、编译器和 SDK 配置匹配。重新生成前记录 `gg_ui_t` 页面/层/控件字段、事件符号和资源清单。重新生成后重新读取头文件并扫描 `custom/`、平台和业务代码中的旧 `ui->...` 引用。

旧版本所谓“用户代码区”不作为权限例外：source-edit 允许维护当前 `generated/`，但保留 `.guiguider` 时必须承认重新导出覆盖风险；无 `.guiguider` 时按普通源文件审查和维护。

## 性能、资源和并发

- 定时器回调避免复杂计算、文件扫描和阻塞操作；复杂计算提前放入业务数据池。
- 数值、资源索引和动画帧做范围校验，异常数据使用安全占位符。
- 按主题和页面按需加载图片，评估解码缓冲、字体和缓存占用。
- 数据池锁内只做快照，锁外调用 LVGL；不要嵌套不同类别的锁。
- 页面卸载时删除定时器、停止动画并清理只属于该页面的资源引用。

## 典型开发流程：新增状态显示

1. 设计源存在时，在 `.guiguider` 中添加控件和资源并重新生成；没有设计源时记录当前 `generated/` 结构并直接修改导出 C/H。
2. 读取 `gg_ui_t` 和页面结构，确认新控件句柄。
3. 在 `custom.h` 定义状态数据，在 `custom_file.h` 或项目资源配置中定义路径。
4. 在 `custom.c` 实现状态、进度和主题刷新函数，在页面定时器中调用。
5. 业务线程在锁保护下写入数据池，UI 线程复制快照后更新控件。
6. 验证事件回调、页面切换、动画、资源路径、范围钳位和卸载生命周期。

## 验证和交付

至少执行静态检查：`gg_ui_t` 声明与调用一致、事件签名一致、句柄存在、资源路径可追溯、构建源列表正确、LVGL 操作处于正确线程、数据锁不跨越 LVGL 调用。

编译结果只能来自实际执行或用户提供的日志。交付时说明：

- 工程是否仍有 `.guiguider`；
- 修改的 `generated/`、`custom/`、平台、业务和构建文件；
- LVGL 版本和 2.x 句柄依据；
- 事件、资源、线程和结构验证结果；
- 原始工程重新导出覆盖风险；
- 未验证的模拟器/板端运行风险；
- 新增或修改注释语言。没有注释变化时明确说明。
