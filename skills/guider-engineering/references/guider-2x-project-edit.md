# Guider 2.x 设计源修改

## 适用范围

仅在总 Skill 已确认 Guider 2.x 且任务属于 `project-edit` 时加载。设计源以 `.guiguider` 的版本字段和 `UI.screen_list` 为准，`generated/` 只读复核。

## 修改前

确认页面/层/控件树、事件、动画、资源和自定义代码入口；记录现有名称并搜索跨文件引用。多个设计源无法确定目标时停止。

## 修改边界

- 页面、层级、控件、样式、设计事件、动画和设计资源改 `.guiguider`。
- 业务、数据池、刷新和平台适配放 `custom/` 或项目适配层。
- 2.x `generated/`（如 `screens/`、`events/`、`assets/`）只读复核，不直接打补丁。
- 保持 `UI.screen_list`、资源引用、事件目标和命名的一致性。

## 结构定位模板

使用 `.guiguider` 的 `UI.screen_list` 和实际字段定位目标节点；不要把 1.x 的 `Application.screen` 路径套用到 2.x。

```javascript
const fs = require("fs");

/* 参数来自已确认的 2.x 设计源和目标节点，不得写死项目路径或控件名。 */
const filePath = process.argv[2];
const screenName = process.argv[3];
const targetId = process.argv[4];
/* 使用 UTF-8 解析；编码不一致时先处理编码问题，不要直接破坏原文件。 */
const document = JSON.parse(fs.readFileSync(filePath, "utf8"));
const screens = document.UI && document.UI.screen_list;

/* 2.x 必须从 UI.screen_list 定位，不能沿用 1.x 的 Application.screen。 */
if (!Array.isArray(screens)) {
    throw new Error("unexpected Guider 2.x structure");
}

const screen = screens.find((item) => item.name === screenName);
if (!screen) {
    throw new Error("screen not found: " + screenName);
}

/**
 * 递归遍历 2.x 设计源节点并收集匹配的控件 ID。
 * @param {unknown} node 当前待遍历节点。
 * @param {string} path 当前节点的可追踪路径。
 * @param {Array<object>} hits 匹配结果输出数组。
 */
function walk(node, path, hits) {
    if (!node || typeof node !== "object") {
        return;
    }
    /* 只检查结构节点的 id，避免全局文本替换误伤资源和事件字段。 */
    if (node.id === targetId) {
        hits.push({path, name: node.name, type: node.type});
    }
    for (const [key, value] of Object.entries(node)) {
        if (Array.isArray(value)) {
            value.forEach((item, index) => walk(item, `${path}.${key}[${index}]`, hits));
        } else if (value && typeof value === "object") {
            walk(value, `${path}.${key}`, hits);
        }
    }
}

const hits = [];
walk(screen, `UI.screen_list[name=${screenName}]`, hits);
/* 目标必须唯一；定位不确定时停止，不能猜测写回路径。 */
if (hits.length !== 1) {
    throw new Error(`expected one widget, got ${hits.length}`);
}
console.log(JSON.stringify(hits[0], null, 2));
```

局部写回后再次校验页面/层/控件唯一性、事件目标、动画引用和资源路径；保留未涉及字段，避免格式化整个设计源。结构变化较大时优先回到设计源编辑并重新导出。

## 验证

修改后检查设计源结构、唯一名称、资源存在性和事件引用；重新导出后定向比较 `generated/` 的页面、事件和资源清单。确认生成目录未被人工写入，异常时回到设计源修复。

交付说明设计源、`custom/`、生成输出复核、导出覆盖风险和未执行步骤。
