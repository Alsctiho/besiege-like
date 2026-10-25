## 技能文档

### 基本信息
- 技能名: `besiege-self-verify`
- 创建人: @alanmllai (alanmllai@tencent.com)
- 版本: v1.1.0
- 更新时间: 2026-10-24

### 适用场景
用于项目自我验证、Godot 报错与弹窗检查、验收录屏和截图复核。默认覆盖核心旅程：六面装配、自由朝向、别名键、拾取、钻岩、火球机关、旋翼水平推进和飞跃高台。当前仅验收核心旅程，旧车辆沙盒已移除。不把此流程当作怪物掉落、全面战斗或存档异常恢复已通过的证明。

### 前置条件
- 已在 Godot 4.7.2 导入当前项目；使用标准 Forward+ / D3D12 真渲染环境。
- Godot MCP Pro 已连接当前项目，原生操作时保持编辑器与游戏打开。
- Python 3.13、FFmpeg 与 FFprobe 可用；脚本使用 Python 标准库，不需要额外 pip 依赖。
- 启动独立验收前停止当前游戏，避免共享 IPC 文件冲突。
- 本机默认路径见 `SKILL.md`，可通过脚本参数覆盖。

### 使用示例
触发语句：

- “验证这次改动，录视频并截图检查 Godot 报错。”
- “跑一轮自我验收，给我视频、截图和测试结果。”

PowerShell：

```powershell
& 'C:/Users/alanmllai/AppData/Local/Programs/Python/Python313/python.exe' 'E:/Projects/besiege-like/.codebuddy/skills/automate/besiege-self-verify/scripts/verify_capture.py'
```

分类器回归：

```powershell
python -B -m unittest discover -s .codebuddy/skills/automate/besiege-self-verify/scripts -p test_verify_capture.py -v
```

### 注意事项
- 输出位于 `recordings/self_verify/<时间戳>/`，已在项目 `.gitignore` 忽略，不覆盖玩家存档或 Blender 源文件。
- 必须保留非零退出码与失败证据；Godot 零退出码不能代替完整日志检查。
- `report.json.all_passed` 仅表示自动部分通过；实际看图后再完成 `visual_review`。
- `record_frames` 会清理固定帧目录，而且采样期间新 IPC 请求会打断录制；先备份，再串行调用。
- 修改编辑器 command 文件后重启 Godot 刷新 preload 缓存；仅重载插件不充分。
- 当前旅程录像约 44 秒，保留真实音乐和音效；实际耗时受机器性能影响，需检查音轨非静音且无削波。
- 导入、重启和运行前后检查 `scripts/adventure/editor_health.gd`；日志零错误不代表没有路径弹窗，原生系统或 IDE 扩展弹窗不保证能从 Godot Window 树读取。
- 在 CMD 中使用 PowerShell 执行上面的命令，或直接使用 Python 解释器路径。

### 已知问题
- [x] 无效输入、等待超时被 `run_test_scenario` 假报通过（v1.0.0 修复）。
- [x] 成功等待步骤被 `get_test_report` 误算失败（v1.0.0 修复）。
- [x] 临时脚本包装器制造未使用字段警告（v1.0.0 修复）。
- [x] 突击车按钮使用非标准模板名导致未载入（v1.0.0 修复）。
- [x] 突击车缺后部底盘，两个后轮载入时被跳过（v1.0.0 修复）。
- [x] 点击后切场景再读取按钮路径报错（已在前一轮修复，纳入验收注意点）。
- [x] 无头导入退出误清理 GUI 运行 Autoload（v1.1.0）。
- [x] 编辑器内置子控件未扫描导致漏读 Reload 按钮（v1.1.0）。
- [x] 超时自动 Continue 未校验可见／禁用状态（v1.1.0）。
- [ ] 嵌入式游戏注入 F9 后，下一次 MCP 游戏查询可能超时；独立真实事件读档测试通过，但该工具链路不视为已修复。
- [ ] `get_editor_errors` 本身不是结构化、完整且去重的诊断 API；本 Skill 以本轮完整日志补足，不更改其 MCP schema。

### 相关技能
- `skill-creator`: 技能目录初始化与格式验证。
- `vision-delegate`: 当前模型不支持看图时委托视觉理解，不能仅检查文件存在。
- `ocr-extract`: 仅在中文小字难以辨认时补充 OCR。
