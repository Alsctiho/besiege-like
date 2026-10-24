# 已验证记录

## 2026-10-24 成功基线

- 工作区：`E:/Projects/besiege-like`，Godot `4.7.2`，Forward+ / D3D12，RTX 5060。
- 成功证据目录：`recordings/self_verify/20261024-161746-883976/`。
- 23 项游戏与截图断言全部通过；本轮完整 `godot.log` 错误 0、警告 0。
- 标准突击车完整载入 17 个组件；物理装配报告 1 个底盘刚体、4 个 mover、6 个 behavior。
- 通过 `Input.parse_input_event` 发送真实 Up 按键，1.5 秒后水平位移 `5.2928900718689` 米；返回建造仍有 17 个组件。
- MP4：H.264、1152×648、30 FPS、252 帧、8.4 秒。
- 实际读取六张 PNG 与从编码后 MP4 均匀解码的十二帧联系表，菜单、材质、轮子、驾驶前后背景和返回场景均可辨认，未见黑屏或缺材质。
- 单独的 `error_probe.gd` 在 `push_error("SELFVERIFY_EXPECTED_ERROR_PROBE")` 后 `quit(0)`，返回码 0，但完整日志分类器仍检出真实错误，探针通过。
- 原生 MCP 落盘截图也已实测，保存在 `recordings/self_verify/native-mcp/main-menu.png`。

## 验收工具正反例

正例：

```json
{"scene_path":"main","steps":[{"type":"wait","node_path":"/root/MainMenu","timeout":5},{"type":"assert","text":"BLOCK SIEGE","partial":false},{"type":"assert","text":"开始建造","partial":false}]}
```

修复后摘要 `assertions_passed=2`、`errors=0`、`all_passed=true`；随后的 `get_test_report(clear=true)` 为 2 通过、0 失败、100%，不把成功 wait 算作失败。

反例：

```json
{"steps":[{"type":"input"},{"type":"wait","node_path":"/root/SELFVERIFY_NODE_MUST_NOT_EXIST","timeout":0.2}]}
```

修复后摘要 `errors=2`、`all_passed=false`；随后的汇总报告为 0 通过、2 失败。不得将“执行命令成功返回 JSON”解释为反例通过。

原生报错探针曾实测 `execute_game_script` 调用 `push_error("SELFVERIFY_EXPECTED_ERROR_20261024")`。`get_editor_errors` 返回 9 条匹配行，其中包含一个包装器警告、探针错误及其堆栈，并非 9 个独立错误。已删除包装器的无用 `_mcp_error` 字段；干净重启后不再产生该警告。

## 失败证据与业务修复

- `20261024-161525-536555`：原验收使用错误短模板名读取空字典而产生脚本错误，没有完成报告；包装脚本即使发现引擎退出码为 0，也返回非零。修正验收数据引用；同时定位并修复 UI 的错误模板名。
- `20261024-161628-446691`：真实载入仅 11 个组件而数据库定义 13 个，严格数量断言失败。定位到后轮在 z=3，而底盘只到 z=1，无六向邻接格导致反序列化跳过。补齐四个底盘块，保留后轮轮距，最终 17 个组件完整载入。没有放宽数量断言。
- 失败目录、报告和录像保留用于追溯，不覆盖为成功。

## 核心旅程重构验收（2026-10-24）

- 默认入口改为 `res://scenes/core_journey.tscn`，旧机器场景保留。
- 最终证据：`recordings/self_verify/20261024-181850-897204/`，63 项真实操作检查全通过，完整日志错误 0、警告 0，H.264 1152×648 / 30 FPS，896 帧，29.866667 秒。
- 实际查看六张关键截图与十二帧 MP4 抽样：宏伟高架／巨环、六面组装和方向箭头、点燃机关升桥、飞跃高台、出口与最终装配均可辨认。
- `tests/journey_data_test.gd`：六面乘六方向、所有权、无效恢复和替换回包全部通过。
- `tests/journey_input_test.gd`：145 项实际按键、输出方向与核心转向检查通过；压下／释放之间必须有事件帧，无头多物理步同帧可能把事件合并，原错误测试日志保留，不降低断言。
- `tests/journey_save_test.gd`：F5 写盘、F9 真实事件回读、回读后未暂停和检查服务仍处理，4 项通过；测试结束恢复原始存档字节。
- 旧 sandbox 回归：`recordings/self_verify/20261024-181414-091306/` 自动通过，无错误或警告；与新玩法报告分别保存。
- 编辑器窗口探针：从 0 个窗口创建一个非独占窗口，健康检查读到 1 个，关闭后恢复；同时真实检测并处理了一次 `Files have been modified outside Godot` 弹窗，仅 `project.godot`，选择 `Reload from disk`，未忽略外部变更或覆盖已修改配置。
- 无头导入曾清理 GUI 的运行 Autoload；已让项目 MCP 插件无头初始化／退出跳过 GUI 服务与清理，重新核对三个 Autoload 及运行信息。
- Blender 源工程保存在编辑模式导致导出运算符无效；正常切回对象模式导出，未覆盖用户源工程。源 `.blend` 与概念图目录加 `.gdignore`，正式运行只导入资产 GLB。
- 模型表情面原为导出后 +Z，已在运行资产外层适配到 Godot -Z 前面，预览中的组件安装坐标与实际道具轴不跟着重复旋转。
- 已避免 MCP 在超时时对不可见／禁用的 Continue 按钮直接触发；只有真实可恢复状态才尝试继续。
- 已知限制：在嵌入式游戏中，F9 注入后下一次游戏 IPC 查询曾反复超时，但没有新的 Godot 错误。独立真实事件测试验证了读档行为；不能据此宣称该 MCP 链路无故障。遇到此情况保存诊断，停止重开游戏，再核对状态，不用清空报错伪造通过。

## 不应误判的情况

- 单次 `click_button_by_text` 只保证按钮动作触发，不能证明数据改变。
- 跟随相机会让车始终接近画面中心，应结合背景与位置数据确认移动。
- 本流程未检查开炮、战斗胜负、飞行高度、水上浮力和存档；这些功能需另写真正会失败的专项断言。
- `RecordBot` 的若干 `[ASSERT]` 输出只是打印文本，没有断言失败退出逻辑，不能仅凭这些标记声明测试通过。
- 此次验收未声称修改了上游 `E:/Godot/godot-mcp-pro-v1.5.3/` 的共享源码；插件修复仅在本项目 `addons/godot_mcp/`。
