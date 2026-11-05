@echo off
setlocal enabledelayedexpansion
chcp 936 >nul
title Nine-Ball Roulette - 一键卸载

set "GAME=%~1"

rem 1) 优先读安装时记录的路径
if not defined GAME if exist "%~dp0已安装路径.txt" (
  for /f "usebackq delims=" %%L in ("%~dp0已安装路径.txt") do (
    if not defined GAME if not "%%L"=="" set "GAME=%%L"
  )
)

rem 2) 没有记录就扫一遍常见 Steam 库
if not defined GAME (
  for %%D in (C D E F G H I J) do (
    if not exist "!GAME!\Nine_Ball_Roulette.exe" (
      if exist "%%D:\steam\steamapps\common\Nine-Ball Roulette\Nine_Ball_Roulette.exe" set "GAME=%%D:\steam\steamapps\common\Nine-Ball Roulette"
      if not exist "!GAME!\Nine_Ball_Roulette.exe" if exist "%%D:\SteamLibrary\steamapps\common\Nine-Ball Roulette\Nine_Ball_Roulette.exe" set "GAME=%%D:\SteamLibrary\steamapps\common\Nine-Ball Roulette"
      if not exist "!GAME!\Nine_Ball_Roulette.exe" if exist "%%D:\Program Files (x86)\Steam\steamapps\common\Nine-Ball Roulette\Nine_Ball_Roulette.exe" set "GAME=%%D:\Program Files (x86)\Steam\steamapps\common\Nine-Ball Roulette"
      if not exist "!GAME!\Nine_Ball_Roulette.exe" if exist "%%D:\Program Files\Steam\steamapps\common\Nine-Ball Roulette\Nine_Ball_Roulette.exe" set "GAME=%%D:\Program Files\Steam\steamapps\common\Nine-Ball Roulette"
    )
  )
)

if not defined GAME (
  echo [X] 没找到游戏目录。
  echo     解决办法（任选一个）:
  echo       1. 把游戏根目录拖到本文件上
  echo       2. 手动删除这两个文件: override.cfg 和 nbr_cheat.gd
  echo.
  pause
  exit /b 1
)

echo [i] 目标目录: %GAME%
if not exist "%GAME%\Nine_Ball_Roulette.exe" (
  echo [!] 这个目录里没有游戏 exe，但仍然会尝试删除注入文件。
)

tasklist /fi "imagename eq Nine_Ball_Roulette.exe" 2>nul | find /i "Nine_Ball_Roulette.exe" >nul
if not errorlevel 1 (
  echo [!] 游戏还在运行，文件可能被占用。
  echo     按任意键继续（建议先退出游戏，否则可能删不掉）
  pause >nul
)

set /a N=0
set /a FAIL=0
call :delfile "%GAME%\override.cfg"
call :delfile "%GAME%\nbr_cheat.gd"
call :delfile "%GAME%\nbr_cheat.gd.bak"
call :delfile "%GAME%\override.cfg.bak"
call :delfile "%GAME%\nbr_dumper.gd"
call :delfile "%GAME%\nbr_driver.gd"
call :delfile "%GAME%\cheat_probe.gd"

echo.
if "!N!"=="0" if "!FAIL!"=="0" (
  echo [i] 这两个文件本来就不存在，已经是干净的了。
)
if "!FAIL!"=="0" if not "!N!"=="0" (
  echo [OK] 已删除 !N! 个文件，游戏恢复原样（游戏本体从未被修改）。
)
if not "!FAIL!"=="0" (
  echo [!] 有 !FAIL! 个文件没删掉。常见原因:
  echo     1. 游戏还在运行 —— 完全退出游戏再跑一次
  echo     2. 没有权限 —— 右键本文件选“以管理员身份运行”
  echo     3. 文件被占用 —— 重启电脑后再跑，或手动删除
  echo.
  echo     手动删除方法: 打开 %GAME% ，把 override.cfg 和 nbr_cheat.gd 删掉即可。
)
echo.
pause
exit /b 0

:delfile
if exist "%~1" (
  attrib -r -h -s "%~1" >nul 2>nul
  del /f /q "%~1" >nul 2>nul
  if not exist "%~1" (
    echo   已删除: %~1
    set /a N+=1
  ) else (
    echo   删不掉: %~1
    set /a FAIL+=1
  )
)
exit /b 0
