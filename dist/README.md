# dist —— 傻瓜式分发版(给不会配环境的人用)

这个文件夹是**打包好的成品**,把它整个压缩发给别人即可,对方**不需要安装任何东西**:

## 对方怎么用

1. 解压后,把 `.rbxl` 文件复制进这个文件夹(或直接拖到「导出.bat」图标上);
2. 双击「导出.bat」;
3. 导出完成后自动打开 `export` 文件夹,里面有按场景整理的代码 + Rojo 项目。

## 你能控制什么(作者端)

| 文件 | 作用 |
|---|---|
| `更新源.txt` | 填上你的仓库地址后,别人每次运行都会**自动检查并下载最新版** `export_scenes.lua`(即你更新仓库 = 别人自动升级)。留空 = 不更新 |
| `VERSION.txt` | 当前版本号(如 `v1.0`),用于更新对比。发布新版时改这里 |
| `export_scenes.lua` | 核心工具,版本由你远程控制 |
| `导出.bat` | 入口脚本(纯 ASCII,无编码问题;`chcp 65001` 保证 lune 中文输出正常) |

更新源的三种写法(填进 `更新源.txt` 去掉 `#`):

```
https://raw.githubusercontent.com/你的用户名/rbxl-code-export/main
https://ghproxy.net/https://raw.githubusercontent.com/你的用户名/rbxl-code-export/main
https://gitee.com/你的用户名/rbxl-code-export/raw/main
```

要求你的仓库根目录有 `VERSION.txt` 和 `export_scenes.lua` 两个文件(本仓库根目录已具备,直接发布即可)。

## 注意

- `导出.bat` 的界面文字是英文(避免 cmd 中文编码问题),使用说明请看 `使用说明.txt`(中文,双击即可打开)。
- 对方电脑需要能联网才支持自动更新(国内直连 GitHub 慢,建议更新源用 gitee 或 ghproxy 前缀)。
- 本目录的 `export_scenes.lua` 与仓库根目录保持同步;发布新版时两个文件一起提交。
