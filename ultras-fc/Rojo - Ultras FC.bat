@echo off
title Rojo - Ultras FC
cd /d C:\ufc\ultras-fc
echo Rojo a servir o Ultras FC. Deixa esta janela aberta enquanto trabalhas.
echo No Studio: Plugins - Rojo - Connect.
echo.
rojo.exe serve default.project.json
echo.
echo O Rojo parou. Carrega numa tecla para fechar.
pause >nul
