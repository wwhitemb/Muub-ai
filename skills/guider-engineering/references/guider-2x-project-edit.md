# Guider 2.x 原始工程修改

## 适用范围

仅在总 Skill 已确认目标是 Guider 2.x 原始工程，并且用户要求修改 `.guiguider`、页面、控件、样式、事件、动画、变量或设计资源时使用。

Guider 2.x 不使用 Guider 1.x 的 `FrontJson`/`Application` 双结构，禁止套用 1.x 规则。

## 解析和版本检查

解析 `.guiguider` 后确认：

- `version`、`createVersion` 为 2.x；
- 存在 `projectSettings` 和 `lvConf`；
- 存在 `UI`；
- `UI.screen_list` 为页面和层级树；
- `UI.event_list`、`UI.variable_setting` 类型正确。

写回保持 UTF-8、无 BOM 和 LF。缩进可因 GUI Guider 序列化变化，但结构和语义必须保持。

## 页面和控件树

`UI.screen_list` 是树形数组。节点可能是：

- `layer_sys`；
- `layer_top`；
- `layer_bottom`；
- `screen`。

控件通过 `children` 嵌套。定位优先使用页面/层级名称、节点 `id`、控件 `name`、控件 `type` 和完整父子路径。不要根据数组下标或名称全文替换对象。

修改前记录命中数量。修改控件名称时只改目标 `name`，保留 `id`、`type`、父节点、数组顺序、布局、样式和未请求字段。

## 事件、变量和动画

`UI.event_list` 按目标对象 ID 或页面键，再按 `LV_EVENT_*` 事件键定位。事件动作可能包含：

- `custom_code`，包括 `type`、`name`、`id`、`include`、`code`；
- 控件动作，如添加/移除 flag、页面切换和动画动作；
- 多层嵌套动作对象。

修改 `custom_code` 时先取出 JSON 字符串值，再修改 C 代码，由 JSON 序列化器重新处理转义。同步检查 `include`、控件 ID、页面名称、动画目标和条件表达式。

`UI.variable_setting` 中的条件和 `lv_anim_t` 配置必须按字段路径修改，不得复制未知字段或按数组位置同步。

## 资源和持久化边界

- `.guiguider`：页面树、控件、样式、事件、变量、动画和工程配置；
- `resources/image`、`resources/font`：设计源资源，修改前确认 JSON 引用；
- `custom/`：用户持久代码和 `user_img` 等不应被生成器覆盖的资源；
- `generated/`：整棵只读，包括 `screens`、`events`、`assets`、字体和图片头文件。

如果只能修改 `generated/` 才能解决问题，停止并报告缺少有效源文件。

## 写回和复核

写回后检查：

- JSON 可重新解析，顶层字段和类型未破坏；
- `UI.screen_list` 页面、层级、控件数量符合预期；
- 新旧控件 ID、名称和父子关系符合预期；
- `UI.event_list` 仍能按目标 ID 和事件键定位；
- `custom_code`、`include`、条件和动画不再引用旧句柄；
- `projectSettings`、`lvConf`、资源路径无非预期变化；
- `generated/` 没有被写入。

重新生成后只读取 `generated/screens`、`generated/events`、`generated/assets` 对比输出，不在其中打补丁。

## 交付内容

说明版本字段、页面/控件路径、事件目标和动作路径、资源源目录、JSON 和语义验证结果，以及用户尚未执行的 GUI Guider 生成或编译步骤。
