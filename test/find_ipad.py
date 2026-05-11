r"""
my pc:
PS C:\Users\VincentZyu> fastfetch.exe
///////////////  /////////////////    VincentZyu@DESKTOP-28AGCCU
///////////////  /////////////////    --------------------------
///////////////  /////////////////    OS: Windows 11 IoT 企业版 LTSC (24H2) x86_64
///////////////  /////////////////    Host: BATTLE-AX B660M-D
///////////////  /////////////////    Kernel: WIN32_NT 10.0.26100.7171
///////////////  /////////////////    Uptime: 9 hours, 17 mins
///////////////  /////////////////    Packages: 10 (scoop), 1 (choco)
///////////////  /////////////////    Shell: Windows PowerShell 5.1.26100.7019
                                        Display (U34G2G4R3): 3440x1440 in 34", 144 Hz [External]
///////////////  /////////////////    WM: Desktop Window Manager 10.0.26100.7019
///////////////  /////////////////    WM Theme: Custom - #680081 (System: Dark, Apps: Dark)
///////////////  /////////////////    Theme: Fluent
///////////////  /////////////////    Icons: Recycle Bin
///////////////  /////////////////    Font: Microsoft YaHei UI (12pt) [Caption / Menu / Message / Status]
///////////////  /////////////////    Cursor: Windows 默认 (32px)
///////////////  /////////////////    Terminal: Windows Terminal 1.24.10921.0
///////////////  /////////////////    Terminal Font: Cascadia Mono (12pt)
                                        CPU: 12th Gen Intel(R) Core(TM) i5-12400F (12) @ 4.40 GHz
                                        GPU 1: OrayIddDriver Device
                                        GPU 2: Parsec Virtual Display Adapter
                                        GPU 3: Todesk Virtual Display Adapter
                                        GPU 4: NVIDIA GeForce RTX 3060 @ 2.12 GHz (11.83 GiB) [Discrete]
                                        GPU 5: GameViewer Virtual Display Adapter
                                        Memory: 24.05 GiB / 31.84 GiB (76%)
                                        Swap: 531.46 MiB / 32.00 GiB (2%)
                                        Disk (C:\): 164.32 GiB / 236.44 GiB (69%) - NTFS
                                        .....
                                        Local IP (Ethernet): 192.168.31.241/24
                                        Locale: zh-CN



PS C:\Users\VincentZyu>
PS C:\Users\VincentZyu>
"""

import subprocess
import json


# ── ANSI color codes ─────────────────────────────────────────
class C:
    CYAN = "\033[36m"
    GREEN = "\033[32m"
    YELLOW = "\033[33m"
    RED = "\033[31m"
    WHITE = "\033[37m"
    GRAY = "\033[90m"
    BOLD = "\033[1m"
    RESET = "\033[0m"


def print_step(n, total, msg):
    print(f"\n{C.CYAN}[{n}/{total}]{C.RESET} {C.YELLOW}{msg}{C.RESET}")


def print_ok(msg):
    print(f"  {C.GREEN}✅{C.RESET} {msg}")


def print_err(msg):
    print(f"  {C.RED}❌{C.RESET} {msg}")


def print_info(msg):
    print(f"  {C.GRAY}💡{C.RESET} {msg}")


def print_table(devices):
    print(
        f"\n  {C.CYAN}┌─────────────────────────────────────────────────────────────────────────────┐{C.RESET}"
    )
    print(
        f"  {C.CYAN}│{C.RESET}  {C.BOLD}{'设备名称':<40} {'状态':<10} {'ID':<20}{C.RESET}  {C.CYAN}│{C.RESET}"
    )
    print(
        f"  {C.CYAN}├─────────────────────────────────────────────────────────────────────────────┤{C.RESET}"
    )
    for dev in devices:
        name = dev.get("FriendlyName", "未知") or "未知"
        status = dev.get("Status", "未知") or "未知"
        inst = dev.get("InstanceId", "")
        short = (
            (inst.split("\\")[-1][:18] + "…")
            if len(inst.split("\\")[-1]) > 18
            else inst.split("\\")[-1]
            if inst
            else "—"
        )
        sc = C.GREEN if status == "OK" else C.RED
        print(
            f"  {C.CYAN}│{C.RESET}  {name:<40} {sc}{status:<10}{C.RESET} {C.GRAY}{short:<20}{C.RESET}  {C.CYAN}│{C.RESET}"
        )
    print(
        f"  {C.CYAN}└─────────────────────────────────────────────────────────────────────────────┘{C.RESET}"
    )


def find_apple_devices():
    print(f"\n  {C.CYAN}╔══════════════════════════════════════════╗{C.RESET}")
    print(
        f"  {C.CYAN}║{C.RESET}       Apple iPad 设备检测工具 (Python)   {C.CYAN}║{C.RESET}"
    )
    print(f"  {C.CYAN}╚══════════════════════════════════════════╝{C.RESET}")

    print_step(1, 3, "正在扫描 USB 设备...")

    ps_command = (
        "Get-PnpDevice -PresentOnly | "
        'Where-Object { $_.FriendlyName -match "Apple" -or $_.FriendlyName -match "iPad" } | '
        "Select-Object FriendlyName, Status, Class, InstanceId | "
        "ConvertTo-Json"
    )

    process = None
    try:
        process = subprocess.run(
            ["powershell", "-Command", ps_command],
            capture_output=True,
            text=True,
            encoding="gbk",
        )

        if not process.stdout.strip():
            print_err("未发现已连接的 iPad。")
            print_info("请检查 USB 线或在 iPad 上点击「信任」。")
            print(f"\n  {C.YELLOW}💡 常见排查：{C.RESET}")
            print(f"    {C.GRAY}• 换一根 USB 数据线（有些线只支持充电）{C.RESET}")
            print(f"    {C.GRAY}• 在 iPad 上点击「信任这台电脑」{C.RESET}")
            print(f"    {C.GRAY}• 重新插拔 USB 线{C.RESET}")
            print(f"    {C.GRAY}• 重启 Apple Mobile Device Service 服务{C.RESET}")
            return

        devices = json.loads(process.stdout)
        if isinstance(devices, dict):
            devices = [devices]

        print_step(2, 3, f"找到 {len(devices)} 个 Apple 设备")
        print_table(devices)

        print_step(3, 3, "硬件摘要")
        print(f"  {C.GRAY}──────────────────────────────────────────{C.RESET}")
        for dev in devices:
            name = dev.get("FriendlyName", "未知") or "未知"
            icon = "📱" if "iPad" in name or "iPhone" in name else "🔌"
            inst_id = dev.get("InstanceId", "").split("\\")[-1] or "—"
            print(f"  {icon}  {C.WHITE}{name}{C.RESET}")
            print(f"      {C.GRAY}└ InstanceId: {inst_id}{C.RESET}")

        print(f"\n  {C.GREEN}✅ Apple 设备检测完成。{C.RESET}")
        print(
            f"  {C.YELLOW}💡 提示：iPad 不会自动映射为盘符。如需传输文件，建议安装：{C.RESET}"
        )

    except FileNotFoundError:
        print_err("找不到 PowerShell，请确认系统环境。")
    except json.JSONDecodeError:
        print_err("解析设备信息时出错。")
        if process:
            print_info(f"原始输出:\n{C.GRAY}{process.stdout}{C.RESET}")
    except Exception as e:
        print_err(f"脚本运行出错: {e}")


if __name__ == "__main__":
    find_apple_devices()
