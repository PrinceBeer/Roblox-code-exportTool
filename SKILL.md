---
name: rbxl-code-export
description: 用 Lune 从 Roblox .rbxl/.rbxmx 文件中导出代码(Script/LocalScript/ModuleScript),按层级整理成文件夹并生成同步安全的 Rojo 项目。用户要求"导出 .rbxl 代码/把 Roblox 场景代码弄出来/处理 rbxl 文件/转成 Rojo 项目"时使用。
whenToUse: 用户想从 Roblox 场景/模型文件(.rbxl/.rbxmx)里导出脚本代码、分文件夹整理、或转成 Rojo 项目在 VS Code 编辑时。关键事实:remodel 已停维护(0.11.0 是终版,读不了新版格式和 LZ4),Rojo 只能读 XML(.rbxlx/.rbxmx),正确工具是 Lune(官方继任者)。
---

# Roblox .rbxl 代码导出(Lune)

把 Roblox 二进制场景文件 `.rbxl` 里的代码导出成 `.lua` 文件 + Rojo 项目。本技能包含完整可用的导出脚本与全部踩坑结论。

## 一、核心结论(先读,避免走弯路)

1. **remodel 已废弃**:官方最后提交(2023-07-22)是 *"Deprecate remodel in favor of Lune"*,v0.11.0 是最终版,永远不会有新版。任何"下载新版 remodel / 去 gitee 克隆源码"的建议都不可行。
2. **gitee.com/mirrors/remodel 是误导**:它镜像的是 Python 的 RethinkDB 库(linkyndy/remodel),不是 Roblox 工具(克隆下来全是 .py)。
3. **新版 Studio 的 .rbxl 格式**:含新属性类型(Capabilities=0x21/33、SharedStringBuffer=0x1f/31、Tags)和 LZ4 压缩 → remodel 0.11 报 `Type mismatch: Property Animation.Tags should be SharedString...` 或 `Decompression failed`。
4. **Rojo 只读 XML**(.rbxlx/.rbxmx),读不了二进制 .rbxl(`could not be turned into a Roblox Instance by Rojo`)。
5. **正确工具:Lune**(roblox-ts/lune,Rust,活跃维护)。内置 `@lune/roblox` 库:`roblox.deserializePlace(fs.readFile(path))` 直接得到 DataModel 实例,支持新版属性类型 + LZ4。官方文档有 Remodel Migration 章节。

## 二、工具与环境

- 本机:Lune 已装到 `E:\Tool\lune.exe`(`E:\Tool` 在 PATH,cmd 直接 `lune`)。
- 安装(其他机器):GitHub Releases 下载 `lune-<ver>-windows-x86_64.zip`;国内用镜像前缀 `https://ghproxy.net/` 加速;或 aftman 安装(`lune = "lune-org/lune@0.10.5"`)。
- 导出脚本:`C:\Users\18708\Documents\Roblox\MonsterRush\export_scenes.lua`(通用,任何项目可用)。
- 运行方式:在 .rbxl 所在目录执行 `lune run export_scenes.lua`。

## 三、导出脚本用法

顶部配置区:

```lua
-- 方式一:手动指定
local PLACES = {
	{ file = "MyPlace.rbxl", name = "MyPlace", label = "备注" },
}
-- 方式二:自动扫描(把 PLACES 清空成 {}),导出当前目录所有 .rbxl;SKIP_FILES 排除
```

**命令行参数(外部控制)**:`lune run export_scenes.lua -- <文件1> [文件2 ...]` 只导出指定文件(支持绝对路径,输出目录名取文件名)。无参数时按 参数 → PLACES → 自动扫描 的优先级。

**傻瓜分发版**:仓库 `dist/` 目录是自包含成品(内置 lune.exe + `导出.bat` 双击/拖拽 + 中文使用说明 + 作者控制的自动更新机制——用户在 `更新源.txt` 指向的地址自动拉取最新 `export_scenes.lua`)。给别人用时直接打包 dist 即可。

脚本行为:

- `Script` → `.server.lua`、`LocalScript` → `.client.lua`、`ModuleScript` → `.lua`,镜像实例层级;
- 脚本带子脚本 → `文件夹/init.<ext>`(Rojo 惯例);
- 轻量容器(ScreenGui/Frame/TextButton/RemoteEvent/Model 等)→ `<name>.model.json` 保留类名+关键属性;
- 重量级内容(Part/MeshPart/Humanoid/人形模型)→ 只导出脚本作参考,不映射;
- 自动生成 `default.project.json`(只映射可完整回同步的容器)+ `导出清单.txt`;
- 重导出前自动清空该场景旧 `src/`。

## 四、Lune API 踩坑(必须遵守)

1. **`GetChildren()`/`GetDescendants()` 返回的表可能有空洞**——实测 42 个脚本的文件夹用 `ipairs` 只导出 1 个。**一律用 `pairs()` 遍历**。
2. `fs` 库:`readFile/writeFile/writeDir/readDir/removeDir` 存在;**`fs.remove`、`fs.exists` 不存在**(Lune 0.10.x,调用会 "attempt to call a nil value")。
3. 实例 API 与 Roblox 一致:`GetService/GetChildren/GetDescendants/FindFirstChild/ClassName/Name/Source`、直接属性访问(如 `gui.Position`)。
4. 枚举属性是 userdata:`tostring()` → `Enum.TextXAlignment.Center`,取最后一段(`:match("([^%.]+)$")`)即 Rojo 要的枚举名。
5. `GetProperties()` 不存在;`Font` 属性读取报 "malformed property info" → 跳过(用默认字体)。
6. 数值类 userdata:`tostring()` 是逗号分隔数字,如 UDim2 `"0, 100, 0, 200"`(xScale,xOffset,yScale,yOffset)、Color3 `"0.03, 0.9, 1"`、Vector2 `"0, 0"`。

## 五、Rojo model.json 限制(Rojo 7.7 源码 resolution.rs 确认)

- `AmbiguousValue` 只支持:`bool / number / string / [x,y] / [x,y,z] / [x,y,z,w] / 12数CFrame / Font / MaterialColors / 枚举名`。
- **不支持 UDim2/UDim 对象**(`{"scale":..., "offset":...}`)→ 解析报错 `data did not match any variant of untagged enum UnresolvedValue`。所以 `Position/Size/CornerRadius` 等一律跳过。
- 结论:含 UI 布局的容器(StarterGui)**不要映射进 project.json**(同步会产生布局全错的 UI);只导出作参考。

## 六、同步安全规则(必须遵守)

- Rojo 同步会**删除已映射容器里项目中没有的内容**,不可恢复 → 同步前备份 .rbxl。
- 只映射能完整表示的容器(纯代码服务:ReplicatedStorage/ServerScriptService/StarterPlayer 等)。
- 含零件/模型/UI 布局的容器(ServerStorage 有人形模型、StarterGui)→ 不映射,脚本改完手动复制回 Studio。
- 生成项目后必须验证:`rojo build default.project.json -o out.rbxlx`,构建通过才交付。

## 七、本机环境速查

- Lune:`E:\Tool\lune.exe`
- 项目:`C:\Users\18708\Documents\Roblox\MonsterRush\`(两个场景:MonsterRush.rbxl 主场景 5 脚本、RushMap.rbxl 子场景 67 脚本)
- 导出脚本:`<项目>\export_scenes.lua`;输出到 `<项目>\export\<场景名>\`
- 导出文档:`<项目>\export\README.md`
- Rojo:aftman 管理,`rojo` 7.7.0(需在含 aftman.toml 的目录下运行)

## 八、常见报错对照

| 报错 | 原因 | 处理 |
|---|---|---|
| `Type mismatch: Property Animation.Tags...` / `Decompression failed` | remodel 太老 | 用 Lune |
| `could not be turned into a Roblox Instance by Rojo` | Rojo 不读二进制 .rbxl | 用本技能导出,或 Studio 另存 .rbxlx |
| `data did not match any variant of untagged enum UnresolvedValue` | model.json 含不支持的值(UDim2) | 跳过该属性(脚本已自动处理) |
| 脚本导出数量偏少 | `ipairs` 遇空洞提前停止 | 改用 `pairs()` |
| 中文乱码 | PowerShell 5.1 Get-Content 按 GBK 解码 | 用 VS Code/edit 工具改文件;PowerShell 读 UTF-8 用 `[System.IO.File]::ReadAllText(path, [Text.Encoding]::UTF8)` |
