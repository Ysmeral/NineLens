"""打包发布：从 src 读取版本，更新 installer/说明.txt，输出 dist/NineLens_<ver>.zip

用法:
    python tools/build_release.py
"""

import hashlib
import os
import re
import sys
import time
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GD = os.path.join(ROOT, "src", "nbr_cheat.gd")
INST = os.path.join(ROOT, "installer")
DIST = os.path.join(ROOT, "dist")

README_TPL = """NineLens {VER}  —  《九球轮盘赌》(Nine-Ball Roulette) 外挂
by.Ysmeral
构建时间: {DATE}
本体校验: {HASH}

【声明】本项目已停止维护，不再更新；仅用于 AI 破甲测试与技术研究；
若侵犯游戏权益将全部下架。与游戏开发/发行方无任何关联。
使用风险自负，联机使用可能导致账号被处罚。

一、功能
  F5  面板开关
  F6  瞄准线开关
  F7  选中推荐目标并显示信息（打哪颗 / 进哪个袋 / 切角多少）
  F8  出杆：自动算能进的球、自动定力度、出杆后校正方向
      -- 杆头没对准也能打进去
  G   推荐线开关（关掉只剩你自己的瞄准链）
  T   切换目标球
  B   切换袋口
  [ ] 调固定力度（默认自动）    \\  力度回自动

  屏幕上只有：黄线（白球→撞点）、绿线（被撞球去向）、
  撞点红圈、可进球的小圈、HUD 里一行判定。

二、怎么装
  1. 解压整个压缩包
  2. 退出游戏
  3. 双击 安装.bat（自动找 Steam 库；找不到就把游戏目录拖上去）
  4. 进游戏，左上角显示「NineLens {VER} 已加载」即生效

三、怎么卸
  双击 卸载.bat，或手动删掉游戏目录里的：
     override.cfg
     nbr_cheat.gd
  游戏本体从未被修改。

  如果卸载.bat 跑不起来（权限不足 / 文件被占用 / 找不到游戏目录），
  把游戏目录交给 AI Agent（Claude Code / Codex / DeepSeek Harness / Cursor 等），
  让它代你删掉上面这两个文件即可，不需要懂命令行。

四、确认版本
  HUD 第一行 = NineLens {VER}
  或看 %APPDATA%\\Godot\\app_userdata\\Nine-Ball Roulette\\logs\\godot.log
  搜索 NINELENS，应为  NINELENS {VER} ready

五、线路含义
  黄线   白球 -> 第一撞点
  绿线   被撞球沿连心线飞向库边/袋口
  琥珀线 参考线路（能进但可能被挡）
  小圈   有袋可进的球（绿色=推荐那颗）

六、日志
  nbr_status.txt  每秒刷新：母球坐标、瞄准方向、全部球坐标、命中球、判定
  aim_trace.log   瞄准源与库边实测值

七、注意
  - 仅适配游戏 1.1.5（Godot 4.6.1）
  - 联机时线只画在本地，不会同步给对面

by.Ysmeral
"""


def main() -> int:
    if not os.path.exists(GD):
        print("找不到 src/nbr_cheat.gd")
        return 1

    src = open(GD, encoding="utf-8").read()
    m = re.search(r"NineLens (V[\d.]+) 已加载", src)
    if not m:
        print('脚本里没找到版本号（应为 "NineLens V1.0 已加载"）')
        return 1
    ver = m.group(1)
    digest = hashlib.sha256(src.encode("utf-8")).hexdigest()[:12]
    date = time.strftime("%Y-%m-%d %H:%M")

    txt = README_TPL.replace("{VER}", ver).replace("{HASH}", digest).replace("{DATE}", date)
    with open(os.path.join(INST, "说明.txt"), "wb") as f:
        f.write(txt.replace("\r\n", "\n").replace("\n", "\r\n").encode("utf-8-sig"))

    for bat in ("安装.bat", "卸载.bat"):
        p = os.path.join(INST, bat)
        if not os.path.exists(p):
            print("缺少", bat)
            return 1
        raw = open(p, "rb").read().decode("gbk", errors="replace")
        new = re.sub(r"NineLens V[\d.]+ 已加载", f"NineLens {ver} 已加载", raw)
        if new != raw:
            open(p, "wb").write(new.replace("\r\n", "\n").replace("\n", "\r\n").encode("gbk", errors="replace"))

    os.makedirs(DIST, exist_ok=True)
    zip_path = os.path.join(DIST, f"NineLens_{ver}.zip")
    with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as z:
        for name in ("安装.bat", "卸载.bat", "说明.txt"):
            z.write(os.path.join(INST, name), arcname="NineLens/" + name)
        z.write(GD, arcname="NineLens/nbr_cheat.gd")

    print(f"版本 {ver}   校验 {digest}")
    print(f"输出 {zip_path}  ({os.path.getsize(zip_path)} 字节)")
    return 0


if __name__ == "__main__":
    sys.exit(main())