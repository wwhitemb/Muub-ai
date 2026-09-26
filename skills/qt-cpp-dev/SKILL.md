---
name: "qt-cpp-dev"
description: "Qt/C++ Widgets、Qt Quick/QML、信号槽、QObject 生命周期、线程、Model/View、资源、构建和错误处理规范。Use when Codex develops, reviews, or debugs Qt Widgets, QML, QObject, signals and slots, QThread, Model/View, QSettings, qmake, or CMake Qt projects."
---

# Qt/C++ 应用开发规范

## 适用范围

仅在检测到 Qt/C++ 工程或用户明确要求 Qt Widgets、Qt Quick、QML、信号槽、模型视图、Qt 线程或 Qt 构建配置时启用。Qt 项目不自动启用 RT-Thread、LVGL、GUI Guider、仪表数据池或嵌入式匈牙利命名约束。

## 触发场景

- Qt Widgets 界面、Qt Quick/QML 界面开发
- `QObject`、signals/slots、事件过滤器和自定义事件
- `QThread`、线程亲和性、异步任务和跨线程通信
- Model/View、`QAbstractItemModel`、数据绑定
- `QSettings`、Qt Resource、文件/网络/串口模块
- qmake/CMake Qt 工程配置、moc/uic/rcc 相关问题
- Qt 应用代码审查、崩溃、对象生命周期或 UI 卡顿排查

## 核心执行规范

### 1. 工程与环境

1. 先确认 Qt 主版本、编译器、构建系统、目标平台和模块依赖，优先使用项目已有版本和写法。
2. 修改 `.ui`、`.qml`、`.qrc`、CMake 或 `.pro` 前读取其调用关系，避免破坏自动生成步骤。
3. 不把嵌入式 RT-Thread API、LVGL API 或仪表项目专用数据池直接引入 Qt 模块，跨平台场景通过明确的适配接口隔离。

### 2. QObject 生命周期

1. 优先使用 QObject 父子对象树管理生命周期；明确说明跨线程对象的创建、移动和销毁关系。
2. 连接可能失效的对象时优先使用默认的上下文连接，避免悬挂回调。
3. 非 QObject 资源使用 RAII；优先 `std::unique_ptr`、`QScopedPointer` 或项目已有智能指针。
4. 不在析构函数中执行不可控的长时间阻塞操作；线程对象销毁前必须明确停止、等待和释放顺序。
5. 禁止跨线程直接操作 QWidget；所有 QWidget 操作必须发生在 GUI 线程。

### 3. 信号槽与事件循环

1. 跨线程通信使用 queued connection、信号槽或项目已有异步接口，不直接读写对方线程状态。
2. 需要上下文生命周期管理的连接使用带 context 的 `connect`；只有在确有必要时才保存连接句柄。
3. 槽函数保持短小，耗时计算、文件、网络和设备操作放入工作线程，结果通过信号回传。
4. 不在槽函数中递归触发无界的同步信号链；必要时使用 queued connection 或状态变化判断。
5. 事件过滤器、重载事件函数和自定义事件必须说明事件来源、线程约束和未处理事件的默认行为。

### 4. 线程与异步任务

1. `QThread` 是线程控制对象，不等同于工作对象；优先采用 worker QObject + `moveToThread` 模式。
2. 工作对象在目标线程创建或移动后再启动任务，禁止从其他线程直接调用其非线程安全方法。
3. 线程退出必须可控：停止任务、退出事件循环、`wait()`，并确保资源释放顺序明确。
4. 不在 GUI 线程执行可能阻塞界面的 I/O、数据库、网络或大量计算。
5. 共享数据优先通过消息和信号槽传递；必须共享时使用 Qt 或标准库同步原语，并缩小锁范围。

### 5. Widgets 与 Qt Quick/QML

1. QWidget 只在 GUI 线程创建、访问和销毁；更新界面前检查对象生命周期和页面状态。
2. QML 暴露给 C++ 的属性、信号、方法必须保持命名和类型稳定，修改后检查注册方式及调用方。
3. QML 中避免在高频绑定中执行复杂计算；将数据预处理放到 C++ 或专用模型层。
4. Model/View 使用正确的 `beginInsertRows`、`endInsertRows` 等变更通知，禁止直接修改模型容器而不通知视图。
5. UI 文件和 QML 资源的修改要同步检查资源路径、对象名称和运行时加载错误。

### 6. 资源、错误与数据

1. 文件、网络、串口、数据库和进程操作必须检查返回值及错误对象，错误应可观察并提供合理恢复路径。
2. 用户输入和外部数据在边界处校验；数值范围、编码、协议长度和文件格式不得依赖隐含约定。
3. 使用 `QString`、`QByteArray` 等 Qt 类型时明确编码和所有权；与 C/C++ API 交互时注意生命周期和临时对象。
4. 配置优先使用项目既有的 `QSettings`、资源系统或配置模块，不重复发明格式。
5. 不为 Qt 应用强制加入嵌入式的 `packed` 结构体、裸 CRC、RT-Thread 事件组或静态内存规则，除非存在明确的外部协议或兼容格式要求。

### 7. 构建与验证

1. 修改 CMake/qmake 后验证目标、Qt 模块、自动生成文件和安装/部署配置。
2. 修改 QObject、signals/slots、QML 类型或 `.ui` 后执行项目实际的 moc/uic/rcc 和构建流程。
3. UI 变更至少验证启动、页面加载、核心交互、异常路径和关闭流程；线程变更验证退出和重复启动。
4. 不声称未实际运行的构建、测试或工具检查已通过。

## 输出要求

交付 Qt 代码时说明：

1. 检测到的 Qt 技术栈和实际启用范围；
2. QObject/线程/信号槽和资源生命周期变化；
3. 构建或运行验证结果；
4. 尚未验证的 Qt 版本、平台插件或部署前置条件。
