---
name: besiege-self-verify
description: 对 besiege-like 项目执行 Godot 自我验证、自动验收、报错检查、真实渲染录制、MP4 转码和截图视觉复核。当用户要求跑通游戏、测试改动、录视频、截图查看、检查 Godot 报错或交付验收证据时使用；同时验证验收工具本身不会假通过或假失败。
---

# BesiegeLike 自我验证与录制

## 执行原则

- 本项目用户已授权直接修复发现的问题；保持针对性修改、保护现有改动，修复后重新验收。该授权不代替破坏性操作或外部权限的审批。
- 先实测，再报告。不要将 MCP 返回成功、进程存活、文件存在、退出码为零或单张截图当作游戏已正常工作的证明。
- 同时要求：功能断言通过、完整本轮日志无错误和警告、视频可解码且规格正确、实际查看截图与视频抽帧。
- 保留失败目录、日志、报告；不要修改期望值、放宽断言、清空错误面板或忽略错误来制造通过。
- 不删除 `.codebuddy`；不提交 Git，除非用户要求。

## 环境

以工作区根目录包含 `project.godot` 为准。当前已验证环境：

| 用途 | 本机路径 |
|---|---|
| Godot 4.7.2 | `E:/Godot/Godot_v4.7.2-stable_win64.exe` |
| Python 3.13 | `C:/Users/alanmllai/AppData/Local/Programs/Python/Python313/python.exe` |
| FFmpeg / FFprobe | `E:/Tools/ffmpeg-9.0.1-essentials_build/bin/` |
| Godot MCP | `godot-mcp-pro`，本机端口 6505 |

脚本只依赖 Python 标准库。先在 Godot 中打开并导入项目，确保 `.godot/global_script_class_cache.cfg` 存在。路径不同可传 `--godot`、`--ffmpeg`、`--ffprobe`；不要重新安装已有软件。

## 1. 原生 MCP 快验收

先获取所需 MCP 工具的真实 schema，再调用。所有游戏工具顺序执行：不同命令共用 `user://mcp_game_request` / `mcp_game_response`，不能并发。

1. 用 `get_project_info` 确认连接当前项目，默认主场景为 `res://scenes/core_journey.tscn`。
2. 通过 `execute_editor_script` 调用 `load("res://scripts/adventure/editor_health.gd").snapshot(get_tree())`；保存时间、PID、项目、可见弹窗标题和文字。可见窗口或资源扫描期间不能声明可运行；无头导入不替代 GUI 检查。
3. 用 `play_scene(mode="main")` 启动 `/root/CoreJourney`，读取玩家、六槽、库存与机关状态；需要看图时用 `execute_game_script` 将 viewport PNG 保存到本轮目录，避免大 Base64。
4. 按 F 拾取、Tab 组装；Q/← 左、E/→ 右、↑ 上、↓ 下、Z 前、X 后；键位决定安装面，工作朝向独立。验证别名同时按住不双发、松开一个不停止持续道具，取消预览不改变实机装配。
5. 本轮完整流程由 `tests/journey_acceptance.tscn` 覆盖：真实走到拾取点、装配、钻岩、火球升桥、水平旋翼加速、同一旋翼改到朝上飞过高差，到达出口。另运行 `tests/journey_data_test.gd` 与 `tests/journey_input_test.gd` 验证六面乘六向和全部按键。
6. 用 `get_editor_errors(max_lines=1500)` 与 `get_output_log(max_lines=1500)` 交叉检查，保留编辑器故障和脚本错误；当前 GUI 报错不能用独立测试日志的零错误掩盖。旧车辆流程仍可打开 `res://scenes/main_menu.tscn`，录像回归用 `--suite sandbox`。

需要验证工具自身时，参考 `references/verified-run.md` 的正反例。测试摘要和汇总报告都必须拒绝无效输入与节点等待超时。反例结果是预期失败，不能混入最终正例报告后声称全部通过。先保存结果，再开启干净的新运行。

## 2. 截图落盘而非输出 Base64

- `get_game_screenshot` / `capture_frames` 可能返回巨大的 Base64；优先用 `record_frames(count=1, frame_interval=1, half_resolution=false)` 得到落盘 PNG。
- `record_frames` 每次清空 `user://mcp_recorded_frames/`。先备份已有帧；调用后立即复制需要的图片到本轮证据目录。
- `user://` 不等于项目目录。用 `execute_game_script` 输出 `OS.get_user_data_dir()`，解析为真实路径，再用本地图片读取工具查看。
- `record_frames` 是采样截图，不是视频，且新游戏请求会打断采样。不要同时进行点击、查询或其它游戏 IPC 调用。
- `start_recording` 是输入记录，也不是视频。正式视频使用下一节的 Movie Maker。

## 3. 一键真实渲染验收与视频

先调用 `stop_scene` 停止当前项目游戏。保留编辑器；不要同时运行两个游戏，它们共用 IPC 目录。

在 PowerShell 中运行以下命令，替换项目根路径即可：

```powershell
& 'C:/Users/alanmllai/AppData/Local/Programs/Python/Python313/python.exe' 'E:/Projects/besiege-like/.codebuddy/skills/automate/besiege-self-verify/scripts/verify_capture.py'
```

脚本自动创建新的 `recordings/self_verify/<时间戳>/`，拒绝覆盖现有输出目录，完成：

1. 在独立进程运行 `assets/error_probe.gd`。故意 `push_error` 后 `quit(0)`，证明真实错误能被完整日志检出，即使 Godot 返回零退出码。探针日志单独保存。
2. 默认 `--suite adventure` 使用 `tests/journey_acceptance.tscn`，以 `--journey-verify` 隔离玩家存档；按真实输入和按钮回调完成六面装配、拾取、钻岩、机关、飞行和到达出口。`--suite sandbox` 保留旧 `assets/self_verify.tscn` 的车辆回归。
3. 严格检查库存守恒、真实装配提交、取消恢复、别名键去重、实际推力方向、机关状态与玩家自行通过路线，保存 `game-report.json` 及六张全分辨率 PNG。失败保留新目录；若组装被墙体净空校验拒绝，应移动到安全平台，而不是禁用碰撞检查。
4. 使用 Godot `--write-movie`、固定 30 FPS、1152×648 真渲染录制 AVI。不要使用 `--headless` 录正式画面；无头模式仅用于隔离错误探针。
5. 使用 FFmpeg 编码 H.264 MP4，并用 FFprobe 检查视频流、时长和尺寸。由编码后的 MP4 均匀抽取十二帧生成 `video-contact-sheet.png`。
6. 扫描独立完整 `godot.log`，分别统计错误和警告。缺日志、缺报告、超时、异常退出、断言失败、缺截图或转码失败均返回非零退出码。

主要产物：`acceptance.mp4`、`acceptance.avi`、六张 PNG、`video-contact-sheet.png`、`godot.log`、`game-report.json`、`report.json`、`video-metadata.json`、探针与 FFmpeg 日志。

## 4. 正确判断 Godot 报错

`get_editor_errors` 的 `count` 是收集到的匹配行数，包含警告、分析器信息、调试器堆栈和重复来源，不是独立错误数。

其实现读取 Output、打开脚本的分析器面板、Debugger，再尝试日志回退；回退有条件且仅截取尾部，因此 `count=0` 不能独立证明无报错，也不能代表所有未打开脚本都检查过。

### 编辑器弹窗与路径配置

- 不是持续后台监听。每次导入、重启、运行前后主动读取 `editor_health.gd` 的窗口快照、`get_editor_errors`、Output 与资源扫描状态。
- `Window` 树快照能读取 Godot 自身可见窗口的标题、独占状态和 Label／Button／LineEdit 文字；原生 OS 文件选择器和 CodeBuddy 扩展弹窗不保证出现在此树中，需要截图／系统窗口观察。不得承诺能检测所有弹窗。
- 弹窗探针已实测：0 个可见子窗口 → 创建非独占测试窗口 → 检出 1 个 → 关闭并恢复。探针只能在当前无阻塞窗口时执行，不制造第二个独占弹窗。
- `Attempting to make child window exclusive...` 是编辑器窗口冲突，也应保存并处理，不当作游戏脚本错误或直接忽略。
- 用户已设置的 `.vscode/settings.json` Godot 路径和 EditorSettings 的 Blender 路径应检查存在性，不覆盖用户配置。
- 正式资产使用 `assets/adventure/models/*.glb`；`generated-assets`、`generated-images`、`docs`、`logs` 和 `recordings` 使用 `.gdignore`，保留源文件但不让 Godot 导入源 Blender 或概念图。
- 项目 MCP 插件无头启动／退出均跳过 GUI 初始化和清理；避免 `--editor --import` 临时进程移除当前 GUI 的运行 Autoload。导入后仍核对 `MCPInputService`、`MCPGameInspector`、`MCPScreenshot` 存在，零退出码不证明接口可用。

正式验收使用本轮专属完整文件：

- `ERROR:`、`SCRIPT ERROR:`、`COMPILE ERROR:`、`Parse Error:`、`Parser Error:`、`Shader Error:` 判为错误。
- `WARNING:` 单独判为警告；默认也阻止验收通过，不全局忽略。
- 普通打印 `errors=0` / `no errors` 不判为错误。
- 保存上下文与源行；不靠重复匹配行数判断严重性。
- 缺日志不能当零错误；缺 `game-report.json` 不能当完成。
- 用 `scripts/test_verify_capture.py` 验证分类器，覆盖正反例、ANSI、大于 50 行的旧错误。

修改 `commands/*.gd` 后，`reload_plugin` 不保证刷新 `preload()` 缓存。保存当前工作并停止游戏，使用 `execute_editor_script` 安排 `EditorInterface.call_deferred("restart_editor", true)`，待重连后复测。

## 5. 实际查看与最终交付

1. 读取六张本轮 PNG 和由 MP4 解码得到的联系表。核对菜单标题与按钮、完整机器和轮子、背景相对位移、返回状态、字体、裁切、缺材质、黑屏等问题。
2. 结合位置数据判断运动；跟随相机会把车固定在画面中间，不能据此误判没动。
3. `report.json.all_passed` 只表示自动检查通过。脚本默认 `visual_review="pending"`；只有实际查看后才写 `visual-review.json`，并将该字段更新为 `passed` 或 `failed`。视觉失败时不交付“通过”。
4. 报告视频与截图路径、断言数、真实位移、错误/警告数、已修复问题及覆盖边界。该流程不证明战斗、武器、飞行、浮力或存档全部正常；需求涉及这些功能时补专项断言和录像。

## 资源

- `scripts/verify_capture.py`：完整验收、录制、日志判定、转码和抽帧。
- `scripts/test_verify_capture.py`：日志判定回归。
- `assets/self_verify.gd` / `.tscn`：真实游戏流程控制与状态断言。
- `assets/error_probe.gd`：零退出码错误探针。
- `references/verified-run.md`：已实测结果与修复记录。
