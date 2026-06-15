欢迎加入 Linux.do 
此工具在 Linux.do 首发

# FlowWin

FlowWin 是一个 macOS 菜单栏工具，用来把任意现有窗口固定在屏幕最上层，并以可调透明度显示。它适合把文档、视频、聊天、歌词、笔记、监控面板等窗口作为半透明参考层悬浮在当前工作内容上方。

由木子不是木子狸开发。软件完全免费。

如果对您有帮助可以支持我，感谢打赏

![打赏](1781537131891.png)

## 功能概览

- 从菜单栏选择一个窗口进行固定。
- 固定层保持源窗口原位置和原大小，显示源窗口实时画面。
- 默认鼠标穿透到下层应用，不阻挡你操作当前工作窗口。
- 按住 `Control` 时临时原生操作源窗口，松开后恢复穿透。
- 鼠标位于固定层内时轻按 `Command`，进入保持操作模式；鼠标移出固定层后自动恢复穿透。
- 按住 `Option` 拖动固定层，可以移动悬浮位置。
- 按住 `Option` 滚动鼠标滚轮或触控板，可以快速调整透明度。
- 所有固定窗口共用一个透明度滑块，范围 `1%` 到 `100%`，默认 `40%`。
- 支持自动取消固定、全局快捷键、命令行和 `flowwin://` 自动化入口。

## 操作方式

打开 FlowWin 菜单，选择“固定窗口”，再选择目标窗口。

固定后：

- **查看**：默认只显示半透明镜像，鼠标事件穿透到下层应用。
- **临时操作源窗口**：鼠标在固定层内时按住 `Control`。FlowWin 会把真实源窗口临时放回镜像背后，并用背景补丁保持透明观感。
- **保持操作源窗口**：鼠标在固定层内时轻按 `Command`。HUD 显示“保持”后，可以不用一直按键；鼠标移出固定层后自动退出。拖拽时如果移出，会等松开后再退出。
- **移动固定层**：按住 `Option` 拖动。
- **调整透明度**：按住 `Option` 滚动。
- **关闭固定层**：菜单中选择“关闭固定窗口”，或使用快捷键。

> 注意：`Control` 临时操作时，真实 App 会收到 `Control` 修饰键，所以 `Control` 点击可能触发 macOS 上下文菜单。需要较长时间操作时，建议用 `Command` 保持模式。

## 快捷键

- `Control-Option-Command-P`：固定或取消固定前台窗口。
- `Control-Option-Command-X`：关闭当前固定窗口。
- `Control`：按住后临时原生操作源窗口。
- `Command`：鼠标位于固定层内时轻按，保持原生操作模式直到鼠标移出。
- `Option` + 拖动：移动固定层。
- `Option` + 滚动：调整透明度。

## 权限

FlowWin 首次运行可能需要两个 macOS 权限：

- **屏幕录制**：用于捕获源窗口画面，并生成背景补丁。
- **辅助功能**：用于移动源窗口、临时恢复源窗口位置、执行输入回退，以及 `Option` 拖动固定层。

菜单顶部会显示当前权限状态。也可以运行：

```sh
.build/release/FlowWin --preflight
```

## 实现原理

macOS 没有稳定公开 API 可以直接修改其他 App 窗口的置顶层级和透明度。FlowWin 采用镜像层方案：

1. 使用 ScreenCaptureKit 捕获目标窗口画面。
2. 创建 FlowWin 自己拥有的透明置顶窗口来显示捕获内容。
3. 平时尽量把真实源窗口停到屏幕边缘或屏幕外。
4. 需要操作源窗口时，将真实源窗口临时放回镜像背后。
5. 用约 `20fps` 的背景补丁缓存遮住真实源窗口，让视觉上仍像透明层。
6. 背景补丁会套用源窗口 alpha mask，减少圆角和透明边缘处的矩形脏边。

如果原生操作准备失败，FlowWin 会自动回退到事件转发/辅助功能操作路径，尽量保证仍可操作。

## 源码结构

- `Sources/FlowWin/main.m`：启动入口和轻量 CLI 诊断。
- `Sources/FlowWin/FWAppDelegate.*`：菜单栏生命周期、菜单、快捷键、全局输入监听和自动化命令分发。
- `Sources/FlowWin/FWMirrorController.*`：固定镜像窗口、ScreenCaptureKit 捕获、透明度、穿透/原生操作模式、背景补丁和自动取消固定。
- `Sources/FlowWin/FWWindowInfo.*`：系统窗口枚举和窗口元数据。
- `Sources/FlowWin/FWAccessibility.*`：辅助功能权限、AX 窗口定位/移动和输入回退。
- `Sources/FlowWin/FWGeometry.*`：Quartz 与 Cocoa 坐标转换、屏幕边界计算。
- `Sources/FlowWin/FWAutomation.*`：命令行自动化客户端、Unix socket 路径和消息读写。
- `Sources/FlowWin/FWCommon.*`：共享常量和小型通用工具。

## 从源码运行

```sh
make run
```

快速诊断：

```sh
.build/release/FlowWin --list-windows
.build/release/FlowWin --preflight
```

基础回归检查：

```sh
make check
```

## 构建 App

```sh
./scripts/build-app.sh
open .build/FlowWin.app
```

App 是菜单栏应用，使用 `LSUIElement`，不会显示 Dock 图标。

## 自动化

FlowWin 运行时接受命令行自动化：

```sh
.build/release/FlowWin --pin-frontmost
.build/release/FlowWin --toggle-frontmost
.build/release/FlowWin --close-all
.build/release/FlowWin --quit
.build/release/FlowWin --pin-window 123
.build/release/FlowWin --unpin-window 123
.build/release/FlowWin --toggle-window 123
.build/release/FlowWin --automation-help
```

也可以使用 `flowwin://`：

```sh
open 'flowwin://toggle-frontmost'
open 'flowwin://close-all'
open 'flowwin://quit'
open 'flowwin://pin-window?windowID=123'
```

## 已知限制

- 同一时间优先保留一个固定窗口；固定新窗口会替换旧窗口。
- `Control` 临时操作会把 `Control` 修饰键传给真实 App，部分 App 可能触发上下文菜单或特殊行为。
- 背景补丁仍基于截图缓存，快速移动、动态背景或复杂透明窗口下可能出现短暂不同步。
- 不同 App 的窗口阴影、圆角、透明区域实现不同，边缘效果可能仍有细微差异。
- 需要 macOS 12.3 或更新版本。
