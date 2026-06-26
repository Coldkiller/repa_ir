@echo off
title Diagnóstico Técnico con Reporte Automático
color 1E
setlocal enabledelayedexpansion

set errores_encontrados=0

:menu_principal
cls
echo.
echo  ====================================================================
echo  .:.:. R E P A I R .:.:.  HERRAMIENTA DE DIAGNOSTICO PARA TECNICOS
echo  ====================================================================
echo.
echo  Seleccione una opcion:
echo.
echo     1   DIAGNOSTICO DE MEMORIA RAM
echo     2   DIAGNOSTICO DE DISCO (HDD/SSD)
echo     3   DIAGNOSTICO DE RED
echo     4   DIAGNOSTICO DE IMPRESORA
echo     5   DIAGNOSTICO COMPLETO (solo pantalla)
echo     6   DIAGNOSTICO COMPLETO + GUARDAR REPORTE EN DISCO
echo     7   SALIR
echo.
choice /n /c 1234567 /m "  Opcion (1-7): "
if errorlevel 7 goto salir
if errorlevel 6 goto guardar_reporte
if errorlevel 5 goto diagnostico_completo
if errorlevel 4 goto diag_impresora
if errorlevel 3 goto diag_red
if errorlevel 2 goto diag_disco
if errorlevel 1 goto diag_ram
goto menu_principal

:: -------------------- DIAGNOSTICO RAM --------------------
:diag_ram
cls
call :cabecera ".:.:. R E P A I R .:.:. MEMORIA RAM"
for /f "tokens=1,2" %%a in ('powershell -command "& { $os = Get-CimInstance Win32_OperatingSystem; $libre = [math]::Round($os.FreePhysicalMemory/1MB,1); $total = [math]::Round($os.TotalVisibleMemorySize/1MB,1); Write-Host $libre $total }"') do (
    set "libre_gb=%%a"
    set "total_gb=%%b"
)
set /a "porcentaje_uso = ( (%total_gb% - %libre_gb%) * 100 ) / %total_gb%"
echo   Memoria total : %total_gb% GB
echo   Memoria libre : %libre_gb% GB
echo   Uso de RAM    : %porcentaje_uso%%%
echo.
echo [TOP 5 PROCESOS]
powershell -command "& { Get-Process | Sort-Object WorkingSet -Descending | Select-Object -First 5 | Format-Table -AutoSize Name, @{Name='RAM_MB';Expression={[math]::Round($_.WorkingSet/1MB,2)}} }"
echo.
if %porcentaje_uso% geq 90 (
    echo PROBLEMA: SATURACION EXTREMA
    set /a errores_encontrados+=1
) else if %porcentaje_uso% geq 75 (
    echo PROBLEMA: USO ALTO DE RAM
    set /a errores_encontrados+=1
) else (
    echo ESTADO: NORMAL
)
echo.
if "%1"=="completo" goto :eof
pause
goto menu_principal

:: -------------------- .:.:. R E P A I R .:.:.DIAGNOSTICAR DISCO --------------------
:diag_disco
cls
call :cabecera "DISCO DURO / SSD"
for /f "tokens=3" %%a in ('dir C:\ 2^>nul ^| find "bytes free"') do set "free=%%a"
for /f "tokens=3" %%b in ('dir C:\ 2^>nul ^| find "bytes" ^| find /v "free"') do set "total=%%b"
set "libre_gb=0"
if defined free set /a "libre_gb=%free:~0,-3%/1073741824" 2>nul
if defined total set /a "total_gb=%total:~0,-3%/1073741824" 2>nul
if %total_gb% equ 0 set total_gb=100
set /a "porcentaje_uso = ((%total_gb% - %libre_gb%) * 100) / %total_gb%"
echo   Capacidad total : %total_gb% GB
echo   Espacio libre   : %libre_gb% GB
echo   Uso del disco   : %porcentaje_uso%%%
echo.
echo [ESTADO SMART]
powershell -command "& { $disk = Get-PhysicalDisk | Select-Object -First 1; Write-Host 'Modelo:' $disk.FriendlyName; Write-Host 'Estado:' $disk.HealthStatus }"
echo.
if %porcentaje_uso% geq 90 (
    echo PROBLEMA: DISCO CASI LLENO
    set /a errores_encontrados+=1
) else if %porcentaje_uso% geq 80 (
    echo PROBLEMA: ESPACIO BAJO
    set /a errores_encontrados+=1
) else (
    echo ESTADO: ESPACIO SUFICIENTE
)
echo.
if "%1"=="completo" goto :eof
pause
goto menu_principal

:: ----- .:.:. R E P A I R .:.:. DIAGNOSTICO RED --------------------
:diag_red
cls
call :cabecera "RED"
ipconfig | findstr "IPv4 Adaptador de LAN inalambrica Adaptador de Ethernet"
echo.
ping -n 1 8.8.8.8 >nul && set "internet=OK" || set "internet=FALLO"
ping -n 1 localhost >nul && set "loopback=OK" || set "loopback=FALLO"
for /f "tokens=13" %%a in ('ipconfig ^| findstr "Puerta de enlace predeterminada"') do set "gateway=%%a"
if "%gateway%"=="" set "gateway=No detectado"
echo   Internet: %internet%
echo   Loopback: %loopback%
echo   Gateway: %gateway%
echo.
if "%internet%"=="FALLO" (
    echo PROBLEMA: SIN ACCESO A INTERNET
    set /a errores_encontrados+=1
) else (
    echo ESTADO: CONEXION FUNCIONAL
)
echo.
if "%1"=="completo" goto :eof
pause
goto menu_principal

:: .:.:. R E P A I R .:.:. DIAGNOSTICO IMPRESORA --------------------
:diag_impresora
cls
call :cabecera "IMPRESORA"
sc query spooler | find "RUNNING" >nul && set "spooler=ACTIVO" || set "spooler=DETENIDO"
echo   Servicio spooler: %spooler%
echo.
dir %systemroot%\system32\spool\printers\*.* 2>nul | find ".spl" >nul && echo   Hay trabajos en cola || echo   Cola vacia
echo.
wmic printer get name,workoffline | findstr /v /c:"Name" | findstr /r /v "^$"
echo.
if "%spooler%"=="DETENIDO" (
    echo PROBLEMA: SERVICIO DE IMPRESION DETENIDO
    set /a errores_encontrados+=1
) else (
    echo ESTADO: SERVICIO ACTIVO (revise fisicamente)
)
echo.
if "%1"=="completo" goto :eof
pause
goto menu_principal

:: .:.:. R E P A I R .:.:.DIAGNOSTICO COMPLETO (solo pantalla) --------------------
:diagnostico_completo
cls
echo.
echo ====================================================================
echo  .:.:. R E P A I R .:.:.   DIAGNOSTICO COMPLETO (MODO PANTALLA)
echo ====================================================================
call :diag_ram completo
call :diag_disco completo
call :diag_red completo
call :diag_impresora completo
echo.
echo ====================================================================
if %errores_encontrados% equ 0 ( echo    NO SE DETECTARON PROBLEMAS ) else ( echo    SE DETECTARON %errores_encontrados% PROBLEMAS )
echo ====================================================================
pause
goto menu_principal

:: -------------------- GUARDAR REPORTE --------------------
:guardar_reporte
set "reporte_file=%userprofile%\Desktop\Reporte_Diagnostico_%date:/=%%time::=%.txt"
(
    echo ====================================================================
    echo      .:.:. R E P A I R .:.:.    REPORTE DE DIAGNOSTICO TECNICO
    echo   Fecha: %date%   Hora: %time%
    echo ====================================================================
    echo.
    call :diag_ram completo
    call :diag_disco completo
    call :diag_red completo
    call :diag_impresora completo
    echo.
    echo ====================================================================
    if %errores_encontrados% equ 0 ( echo   RESULTADO: SIN PROBLEMAS DETECTADOS ) else ( echo   RESULTADO: %errores_encontrados% PROBLEMA(S) ENCONTRADOS )
    echo ====================================================================
) > "%reporte_file%"

cls
echo.
echo  ====================================================================
echo  .:.:. R E P A I R .:.:.   REPORTE GUARDADO EXITOSAMENTE
echo  ====================================================================
echo.
echo  Archivo creado en:
echo  %reporte_file%
echo.
echo  Puede abrirlo con Bloc de notas o imprimirlo.
echo.
pause
goto menu_principal

:: -------------------- CABECERA --------------------
:cabecera
echo.
echo ====================================================================
echo  .:.:. R E P A I R .:.:.   DIAGNOSTICO DE %~1
echo ====================================================================
echo.
goto :eof

:salir
cls
echo Gracias por usar la herramienta.
