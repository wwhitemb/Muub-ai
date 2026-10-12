# Figma 到 LVGL 动画轨迹参考

## 加载条件

在把新的 Motion JSON 转换为 LVGL 动画、修改弧段方向/透明度/easing，或需要解释动画与代码对应关系时加载。

所有角度、时长、节点序号和物理参数必须来自当前 JSON 和代码。以下内容只是记录模板。

## 分析记录

```text
【动画轨迹】
模式：<模式名称>
物理映射：右侧=<arc[index]>；左侧=<arc[index]>
节点规则：固定端=<...>；运动端=<...>；方向=<正/负>
区间：
  <起始毫秒>-<结束毫秒>：<属性起值> -> <属性终值>
  easing=<实际曲线或物理参数>；hold=<是/否>
透明度：整体=<...>；渐变头尾=<...>
循环：总时长=<...>；repeat delay=<...>；结束画面=<...>
依据：<JSON 路径、关键帧或代码位置>
未知项：<未知值和采用的项目假设>
```

不要把“内层/外层”直接等同于“左侧/右侧”。先根据节点初始角度和画面确认物理映射，再固定 `arc[index]`。

## LVGL 回调骨架

```c
/**
 * @brief 动画执行回调，将量化值同步映射到几何和透明度属性。
 * @param[in] object 动画创建时传入的上下文；生命周期必须覆盖回调执行期。
 * @param[in] value LVGL 动画当前值；单位和合法范围由动画配置确认。
 * @return 无；必须运行在项目允许的 LVGL 线程上下文。
 */
static void animation_exec(void *object, int32_t value)
{
    /* object 的真实类型和生命周期必须从动画创建点确认；
     * 回调执行期间页面对象必须仍然有效。 */
    animation_context_t *context = object;

    if (context == NULL) {
        return;
    }

    /* value 的单位、量化范围和来源由 LVGL 动画配置决定；
     * 先限制范围，避免异常回调值破坏几何或透明度计算。 */
    const int32_t bounded = project_clamp_animation_value(value);
    project_update_geometry(context, bounded);
    project_update_opacity(context, bounded);
    /* 渲染调用必须运行在项目允许的 LVGL 线程上下文。 */
    project_render_if_changed(context);
}
```

共享时间轴的几何和透明度在同一回调中更新；hold 段直接写入关键帧值，不能让 playback 继续插值。删除页面时先注销动画，再释放 Canvas、draw buffer 和上下文，避免回调访问已释放对象。

## 验证顺序

先验证静态首帧、对象层级、尺寸、裁剪和纯色可见性，再恢复渐变、透明度、动态端点和 easing。记录回调值、量化值、绘制返回值、关键时间点和实际内存/CPU 测量。
