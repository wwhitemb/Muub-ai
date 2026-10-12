# Guider 1.x 设计源修改

## 适用范围

仅在总 Skill 已确认 LVGL + Guider 1.x、任务属于 `project-edit` 时加载。设计源以 `.guiguider` 为准，`generated/` 只读复核。

## 修改前

1. 确认 `.guiguider` 的 `FrontJson`、`Application` 和当前版本字段。
2. 记录页面、控件、事件、动画、资源和自定义代码入口；搜索旧名称的跨文件引用。
3. 区分设计源、`custom/` 持久代码和生成输出，不从生成 C 反推未确认的设计结构。

## 修改边界

- 页面、控件树、样式、设计事件、动画目标和设计资源改 `.guiguider`。
- 业务接口、数据绑定、刷新函数和平台适配放 `custom/` 或项目适配层。
- `generated/` 只用于导出结果复核，不直接打补丁。
- JSON 字符串、资源路径、控件名称和事件引用必须保持语法与命名一致。

## 结构定位与局部写回模板

先复制原始 `.guiguider` 文件作为外部备份，再使用结构化解析定位唯一页面或控件。不要用全局字符串替换猜测嵌套路径。

```javascript
const fs = require("fs");

/* 参数必须来自已确认的设计源路径、页面名称和控件 ID；
 * 不要把工程路径或业务名称硬编码到通用脚本。 */
const filePath = process.argv[2];
const screenName = process.argv[3];
const targetId = process.argv[4];
/* 按 UTF-8 读取；若工程使用其他编码，必须先确认工具链支持。 */
const document = JSON.parse(fs.readFileSync(filePath, "utf8"));

/* 先验证版本/顶层结构，避免把 2.x 文件按 1.x 路径误修改。 */
if (!document.FrontJson || !document.Application ||
    !Array.isArray(document.Application.screen)) {
    throw new Error("unexpected Guider 1.x structure");
}

const screen = document.Application.screen.find(
    (item) => item.name === screenName
);
if (!screen) {
    throw new Error("screen not found: " + screenName);
}

/**
 * 递归遍历 1.x 设计源节点，并把每个结构节点交给调用方检查。
 * @param {unknown} node 当前待遍历节点。
 * @param {string} path 当前节点的可追踪路径。
 * @param {(node: object, path: string) => void} callback 节点检查回调。
 */
function walk(node, path, callback) {
    if (!node || typeof node !== "object") {
        return;
    }
    /* 递归仅遍历对象和数组，不把字符串内容当作结构节点替换。 */
    callback(node, path);
    for (const [key, value] of Object.entries(node)) {
        if (Array.isArray(value)) {
            value.forEach((item, index) => walk(item, `${path}.${key}[${index}]`, callback));
        } else if (value && typeof value === "object") {
            walk(value, `${path}.${key}`, callback);
        }
    }
}

const hits = [];
walk(screen, `Application.screen[name=${screenName}]`, (node, path) => {
    if (node.id === targetId) {
        hits.push({path, name: node.name, type: node.type});
    }
});
/* 0 个表示定位证据不足，多个表示 ID 非唯一；两者都禁止写回。 */
if (hits.length !== 1) {
    throw new Error(`expected one widget, got ${hits.length}`);
}
console.log(JSON.stringify(hits[0], null, 2));
```

局部修改后重新解析同一节点，检查唯一性、父子关系、资源引用和事件目标；只有验证通过后才写回原文件。写回脚本必须保留未涉及字段和编码格式，不能将整个 JSON 重排作为副作用。

## 验证

- 重新导出前检查 JSON 结构、页面/控件唯一性、资源存在性和事件引用。
- 重新导出后只定向检查 `generated/gui_guider.h`、相关页面/事件文件和资源清单。
- 确认 `generated/` 未被人工写入；旧句柄和旧资源引用已清理。
- 若生成结果与预期不符，回到 `.guiguider` 或 `custom/` 修复。

交付说明修改的设计源、`custom/` 文件和生成输出复核结果；报告重新导出覆盖风险和未执行的导出/编译步骤。
