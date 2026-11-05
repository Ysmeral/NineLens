@echo off
setlocal enabledelayedexpansion
chcp 936 >nul
title Nine-Ball Roulette - 一键注入

set "GAME=%~1"

if "%GAME%"=="" (
  for %%D in (C D E F G H I J) do (
    if not exist "!GAME!\Nine_Ball_Roulette.exe" (
      if exist "%%D:\steam\steamapps\common\Nine-Ball Roulette\Nine_Ball_Roulette.exe" set "GAME=%%D:\steam\steamapps\common\Nine-Ball Roulette"
      if not exist "!GAME!\Nine_Ball_Roulette.exe" if exist "%%D:\SteamLibrary\steamapps\common\Nine-Ball Roulette\Nine_Ball_Roulette.exe" set "GAME=%%D:\SteamLibrary\steamapps\common\Nine-Ball Roulette"
      if not exist "!GAME!\Nine_Ball_Roulette.exe" if exist "%%D:\Program Files (x86)\Steam\steamapps\common\Nine-Ball Roulette\Nine_Ball_Roulette.exe" set "GAME=%%D:\Program Files (x86)\Steam\steamapps\common\Nine-Ball Roulette"
      if not exist "!GAME!\Nine_Ball_Roulette.exe" if exist "%%D:\Program Files\Steam\steamapps\common\Nine-Ball Roulette\Nine_Ball_Roulette.exe" set "GAME=%%D:\Program Files\Steam\steamapps\common\Nine-Ball Roulette"
    )
  )
)

if not exist "%GAME%\Nine_Ball_Roulette.exe" (
  echo [X] 没找到游戏 exe。
  echo     把游戏根目录（含 Nine_Ball_Roulette.exe 的那个文件夹）拖到本文件上再试。
  echo.
  pause
  exit /b 1
)

echo [i] 目标目录: %GAME%

tasklist /fi "imagename eq Nine_Ball_Roulette.exe" 2>nul | find /i "Nine_Ball_Roulette.exe" >nul
if not errorlevel 1 (
  echo [!] 检测到游戏正在运行，建议先退出再装。
  echo     按任意键继续（装完记得重启游戏才会生效）
  pause >nul
)

if not exist "%~dp0nbr_cheat.gd" (
  echo [X] 同目录下缺少 nbr_cheat.gd，请把整个压缩包解压后再运行。
  echo.
  pause
  exit /b 1
)

if /i "%~dp0nbr_cheat.gd"=="%GAME%\nbr_cheat.gd" (
  echo [i] 本体已在游戏目录，跳过复制。
) else (
  copy /y "%~dp0nbr_cheat.gd" "%GAME%\nbr_cheat.gd" >nul
  if errorlevel 1 (
    echo [X] 复制失败，请右键本文件选择“以管理员身份运行”。
    echo.
    pause
    exit /b 1
  )
)

> "%GAME%\override.cfg" echo [autoload]
>>"%GAME%\override.cfg" echo.
>>"%GAME%\override.cfg" echo NbrCheat="*res://nbr_cheat.gd"

rem 记录安装路径，卸载时直接读，不用再满盘找
> "%~dp0已安装路径.txt" echo %GAME%

echo.
echo [OK] 注入完成
echo      %GAME%\nbr_cheat.gd
echo      %GAME%\override.cfg
echo      已记录路径到: %~dp0已安装路径.txt
echo.
echo 启动游戏后，左上角出现“NineLens V1.0 已加载”即生效。
echo.
echo 快捷键:
echo   F5 面板   F6 瞄准线   F7 对齐   F8 出杆
echo   T 换球    B 换袋     Z 自瞄   X 自动出杆   L 锁定
echo   A 全部线  P 强物理   O 鼠标推  R 复位杆位
echo   F11 诊断  F12 日志   F10 截图
echo.
pause
