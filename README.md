---
AIGC:
    Label: "1"
    ContentProducer: 001191440300708461136T1XGW3
    ProduceID: 53f09690aee64fdb3387c5a4fef43cb3_08304d20a85511f1bf99525400e6dd8f
    ReservedCode1: ZK1EGPHh4Eb0b7rXw8NPgQToPFyUKAONzkSlrzptez9ak3PW+ouyIfc/qIGdHJ6WlsfwWpyOqhKk47ZAB+wys/QFHqZcQIUWqdTqwUaVPpAvhAypHDij+Oe3TK7iYuy4eC3xmtmYE8gYnL3755f1L2K1IvhARUzfc2Hmqxe+X2FMODE5yMVtRRrMFJ4=
    ContentPropagator: 001191440300708461136T1XGW3
    PropagateID: 53f09690aee64fdb3387c5a4fef43cb3_08304d20a85511f1bf99525400e6dd8f
    ReservedCode2: ZK1EGPHh4Eb0b7rXw8NPgQToPFyUKAONzkSlrzptez9ak3PW+ouyIfc/qIGdHJ6WlsfwWpyOqhKk47ZAB+wys/QFHqZcQIUWqdTqwUaVPpAvhAypHDij+Oe3TK7iYuy4eC3xmtmYE8gYnL3755f1L2K1IvhARUzfc2Hmqxe+X2FMODE5yMVtRRrMFJ4=
---

# 一键电脑体检工具

一款基于 **WinUI 3 + C# + PowerShell** 的 Windows 电脑健康体检工具。一键采集磁盘空间、垃圾文件、系统性能、电池健康与使用习惯等数据，生成综合评分、优化建议与可视化 HTML 报告，帮助普通用户快速了解电脑当前状态。

## 功能特性

- **五大维度体检**：
  - **磁盘**：全部分区空间使用率、剩余空间统计与可视化进度条；
  - **性能**：CPU 占用、内存占用、运行进程数、自启动项检测与建议；
  - **电池**：电池健康度、设计/满充容量、循环次数、电源计划、节电模式；
  - **清洁**：系统临时文件、浏览器缓存、回收站、更新备份、崩溃转储等垃圾与缓存扫描，估算可释放空间；
  - **使用习惯**：近 7 天开机次数、累计/平均开机时长、上次开机时间、本次连续运行时长。
- **综合评分**：按磁盘 / 性能 / 电池 / 清洁四个维度加权计算总分（满分 100），并给出整体状态星级与评价。
- **大文件扫描**：全盘扫描超过 500MB 且 60 天未修改的大文件，按体积排序列出 Top 10，方便定位可归档清理的目标。
- **实时进度条**：体检过程中在界面实时显示进度百分比与当前采集阶段。
- **HTML 报告**：体检完成后自动生成可视化 HTML 报告（`电脑体检报告.html`）并可在浏览器中打开。

## 技术栈

| 层次 | 技术 |
| --- | --- |
| 界面层 | WinUI 3（Windows App SDK） |
| 业务层 | C# / .NET 8 |
| 采集引擎 | PowerShell 脚本（`采集引擎JSON.ps1` 输出 JSON，`体检引擎.ps1` 输出 HTML 报告） |

## 环境要求

- 操作系统：Windows 10（版本 1809 及以上）/ Windows 11（推荐 Windows 11）
- 运行依赖：.NET 8、Windows App SDK（NuGet 自动还原）
- 开发环境：Visual Studio 2022（含"Windows 应用 SDK"与".NET 桌面开发"工作负载）或 .NET 8 SDK + 命令行构建
- 目标框架：`net8.0-windows10.0.19041.0`

## 使用方法

两种入口方式任选其一：

1. **直接运行可执行文件**：运行发布后的 `一键体检WinUI.exe`（图形界面版，实时进度条 + 界面展示结果）。
2. **双击批处理脚本**：双击 `一键体检.bat`（命令行版），脚本会自动调用 `体检引擎.ps1` 依次采集数据并生成 HTML 报告，结束后自动打开浏览器查看。

> 提示：全盘大文件扫描可能需要几分钟，请耐心等待；中途关闭窗口则本次体检中止。

## 从源码构建

```bash
# 还原依赖并发布（win-x64 运行时标识）
dotnet restore 一键体检WinUI.csproj

dotnet publish 一键体检WinUI.csproj -c Release -r win-x64 --self-contained false -o publish
```

发布产物位于 `publish\` 目录下，运行其中的 `一键体检WinUI.exe` 即可。

若使用 Visual Studio，直接打开 `一键体检WinUI.csproj`，选择 Release / x64 配置后点击"生成"即可。

## 目录结构

```
一键电脑体检工具_开源/
├── README.md                 # 项目说明
├── LICENSE                   # MIT 开源协议
├── .gitignore                # Git 忽略规则
├── 一键体检.bat              # 命令行入口脚本（生成 HTML 报告）
├── 一键体检WinUI.csproj      # 项目文件（WinUI 3 应用）
├── App.xaml / App.xaml.cs    # 应用启动入口
├── MainWindow.xaml           # 主窗口界面定义
├── MainWindow.xaml.cs        # 主窗口逻辑（采集、渲染、评分展示）
├── app.manifest              # 应用清单（权限声明）
├── 采集引擎JSON.ps1          # PowerShell 采集引擎（输出 JSON 数据）
├── 体检引擎.ps1              # PowerShell 体检引擎（生成 HTML 报告）
└── Assets/
    └── app.ico               # 应用图标
```

## License

本项目基于 **MIT License** 开源，详情见 [LICENSE](LICENSE) 文件。

## 免责声明

本工具仅用于**体检与信息展示**，不执行任何自动清理或删除操作。报告中涉及的垃圾文件、大文件、自启动项等清理建议，请用户自行确认后手动处理，本工具不对因此产生的数据丢失承担责任。
*（内容由AI生成，仅供参考）*
