# Guider 1.x 原始工程修改

## 适用范围和触发条件

仅在总 Skill 已确认目标是 LVGL + Guider 1.x 原始工程，并且用户明确要求修改 `.guiguider`、GUI Guider 设计源、页面、控件、样式、事件、动画或设计资源时使用。

只提到 LVGL、GUI Guider、`generated/` 或要求查看生成代码，不触发本参考文件。存在 `.guiguider` 但用户要求修改导出的 C/LVGL、`custom/`、平台适配或构建文件时，改用 `guider-1x-source-edit.md`。

## 工程识别和持久化边界

确认目标目录同级存在：

```text
<project>.guiguider
custom/
generated/
```

`.guiguider` 必须能解析为 JSON，并至少包含：

- `FrontJson`；
- `Application`；
- `Application.screen` 数组。

`.guiguider` 是页面、控件、样式、事件、动画、资源配置和设计代码的来源；`custom/` 保存不会被 GUI Guider 覆盖的业务逻辑、数据池、刷新函数、公共接口和用户资源。

在 `project-edit` 中，`generated/` 整棵目录只读，包括 C/H、`generated.mk`、图片、字体、资源清单和其他导出文件。它只用于确认句柄、对比重新生成结果和定位问题，禁止打补丁。如果问题只能通过修改 `generated/` 解决，停止并报告缺少有效设计源或适配源。

## 解析和编码

1. 使用 JSON 解析器读取完整文件，禁止按文本片段拼接 JSON。
2. 写回前确认 JSON 合法、文件为 UTF-8、无 BOM，并保持 LF 换行。
3. 记录目标页面、控件、事件和代码字段的 JSON 路径。
4. 文件可能超过 1 MB，允许 GUI Guider 重新格式化，但必须复核结构语义。

推荐使用 Node.js 进行解析和结构检查：

```powershell
node -e "const fs=require('fs'); const p='project.guiguider'; const o=JSON.parse(fs.readFileSync(p,'utf8')); if(o.FrontJson===undefined||!o.Application||!Array.isArray(o.Application.screen)) process.exit(1); console.log('GUIGUIDER_STRUCTURE=OK')"
```

## 控件和页面定位

按对象身份定位，优先级如下：

1. 页面名称和页面 ID；
2. 控件 ID；
3. 控件当前 `name`；
4. 控件 `type`；
5. `Application.screen[*]`、`widgets` 及子节点结构路径。

修改前统计命中数量。预期修改一个对象却命中零个或多个时停止并报告，不根据猜测选择对象。同名对象出现在 `FrontJson` 和 `Application` 时，必须区分两套结构的用途。

控件命名建议使用：

```text
<页面名>_<控件类型>_<功能>
```

例如 `Main_Screen_slider_volume`、`Main_Screen_label_volume_icon`、`Photo_Screen_img_main`。命名应表达页面、控件类型和业务功能，避免连续数字和默认名称。

## 安全修改规则

禁止对整个 `.guiguider` 执行全文 `Replace`、正则全局替换或未解析 JSON 的字段插入。相同文本可能出现在控件 `name`、`customer_code`、`custom_code`、事件条件、动画代码、页面切换代码、注释字符串、`FrontJson` 和 `Application` 中。

控件改名时只修改目标对象的 `name` 字段，再按明确引用清单同步代码字符串。除非用户明确要求，保持：

- `id`、`type`；
- 父子关系和数组顺序；
- 样式结构、事件类型和资源路径；
- 未请求修改的字段。

不得重新生成随机 ID、重排页面或复制未知字段。

## JSON 代码字符串

`customer_code`、`custom_code`、事件条件和动作中的 C 代码是 JSON 字符串，不是直接的 C 文件：

1. 先读取并解析字符串值；
2. 在字符串值层面修改 C 代码；
3. 由 JSON 序列化器重新处理引号、反斜杠和换行；
4. 写回后重新解析整个 `.guiguider`。

重点检查：

- `guider_ui.xxx`、`ui->xxx`；
- `lv_anim_set_var`、`lv_label_set_text`、`lv_slider_get_value`；
- `lv_obj_add_event_cb`、`lv_obj_remove_event_cb`；
- 页面切换函数、条件表达式和保存的控件名称。

禁止直接修改转义后的 JSON 文本或手工插入未转义字符。新增或修改的 C 注释默认使用中文。

## `FrontJson` 与 `Application`

不能假设两套结构完全相同：

- `Application.screen` 是实际控件树的主要来源；
- `FrontJson` 用于页面级兼容数据、代码引用和可能保留的事件信息；
- 不根据数组下标在两套结构间同步对象；
- 优先按页面名、页面 ID 和控件 ID 建立对应关系；
- 修改后在两套结构中搜索旧名称；
- 不为了“看起来一致”而复制或新增未知字段。

两套结构存在冲突时，报告具体 JSON 路径并停止自动修改。

## 完整执行流程

1. 建立修改清单：页面、控件 ID、旧名、新名、类型、目标 JSON 路径、受影响代码字段。
2. 解析并备份必要上下文，确认目标对象唯一。
3. 修改 `.guiguider` 的结构化字段和字符串值。
4. 在 `custom/` 中同步持久化接口、数据绑定、刷新函数或资源适配。
5. 写回并执行语法、引用和结构验证。
6. 用户重新生成后只读复核 `generated/` 的句柄、页面数量、事件、资源和头文件。

## 写回后的验证

语法验证：

- 再次执行 `JSON.parse`；
- 检查文件完整读取；
- 检查 `FrontJson`、`Application`、`Application.screen` 仍存在且类型正确。

语义验证：

- 新名称或新对象命中数量符合预期；
- 旧名称在 `.guiguider` 和 `custom/` 中没有有效引用；
- 事件、动画、条件和自定义代码不再引用旧句柄；
- 页面、控件、事件和资源数量没有非预期变化；
- 目标对象的 ID、类型和父子关系保持不变；
- `generated/` 未被写入。

用户重新导出后，扫描 `generated/gui_guider.h`、`generated/*.c` 和资源清单，确认生成输出反映设计源修改。生成结果异常时回到 `.guiguider` 或 `custom/` 修复，不在 `generated/` 打补丁。

## 常见错误

- 直接修改 `generated/`，导致下次导出丢失修改；
- 只改 `generated/gui_guider.h`，造成头源不一致；
- 对 `.guiguider` 做全文替换，误改其他页面或字符串；
- 只替换可见的 `guider_ui.xxx`，遗漏事件、动画和条件中的句柄；
- 按数组下标同步 `FrontJson` 和 `Application`；
- 只修改生成图片或字体目录，没有修改设计资源源配置。

## 交付格式

报告以下内容：

1. Skill 的明确触发依据、Guider 1.x 版本证据和目标 JSON 路径；
2. 修改的页面、控件、字段和对象命中数量；
3. 修改的 `custom/` 文件；
4. `generated/` 只读复核结果；
5. 修改前/后对比、JSON 和语义引用验证结果；
6. 用户编译结果或未执行 GUI Guider 编译的原因；
7. 尚未验证的运行时风险和新增/修改注释语言。
