<#
.SYNOPSIS
    Asistente de diagnóstico y reparación para Windows.
.DESCRIPTION
    Analiza red, impresoras, RAM y disco. Genera un reporte doble (usuario + técnico).
    Permite aplicar reparaciones seguras de forma automática o manual.
    Diseñado con criterios de accesibilidad visual y cognitiva.
.NOTES
    Versión: 3.0 (Unificada)
    Requiere: PowerShell 5.1 o superior
#>

#Requires -Version 5.1

# =============================================================================
# CONFIGURACIÓN GLOBAL
# =============================================================================
$Host.UI.RawUI.BackgroundColor = "Black"
Clear-Host

$FechaHoy       = Get-Date -Format "yyyy-MM-dd_HH-mm"
$RutaEscritorio = [Environment]::GetFolderPath("Desktop")
$NombreReporte  = "Diagnostico_$FechaHoy.txt"
$RutaReporte    = Join-Path $RutaEscritorio $NombreReporte

$ReporteUsuario = [System.Collections.Generic.List[string]]::new()
$ReporteTecnico = [System.Collections.Generic.List[string]]::new()
$ResumenProblemas = [System.Collections.Generic.List[string]]::new()
$TotalProblemas = 0
$TotalAlertas   = 0
$TotalOK        = 0

$esAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

# =============================================================================
# FUNCIONES DE PRESENTACIÓN ACCESIBLE
# =============================================================================
function Write-Separador { Write-Host ("─" * 70) -ForegroundColor DarkCyan }
function Write-Titulo {
    param([string]$Texto)
    Write-Host "`n  $Texto" -ForegroundColor Cyan
    Write-Separador
}
function Write-OK     { Write-Host "  Ok $($args[0])" -ForegroundColor Green }
function Write-Alerta { Write-Host "  Alerta $($args[0])" -ForegroundColor Yellow }
function Write-Error  { Write-Host "  Error $($args[0])" -ForegroundColor Red }
function Write-Info   { Write-Host "  Informe $($args[0])" -ForegroundColor White }
function Write-Tecnico{ Write-Host "  Tecnico $($args[0])" -ForegroundColor DarkGray }

function Esperar-Tecla {
    param([string]$Mensaje = "Presiona ENTER para continuar...")
    Write-Host "`n  ⏎ $Mensaje" -ForegroundColor DarkYellow
    Read-Host | Out-Null
}

function Agregar-AlReporte {
    param([string]$Linea, [string]$Destino = "Usuario")
    if ($Destino -eq "Usuario") { $script:ReporteUsuario.Add($Linea) }
    else { $script:ReporteTecnico.Add($Linea) }
}

function Registrar-Problema {
    param([string]$Descripcion)
    $script:TotalProblemas++
    $script:ResumenProblemas.Add("[PROBLEMA] $Descripcion")
    Agregar-AlReporte "  Error $Descripcion" "Usuario"
}
function Registrar-Alerta {
    param([string]$Descripcion)
    $script:TotalAlertas++
    $script:ResumenProblemas.Add("[ATENCIÓN] $Descripcion")
    Agregar-AlReporte "  Alerta $Descripcion" "Usuario"
}
function Registrar-OK {
    param([string]$Descripcion)
    $script:TotalOK++
    Agregar-AlReporte "  OK $Descripcion" "Usuario"
}

# =============================================================================
# MÓDULO 1: DIAGNÓSTICO DE RED
# =============================================================================
function Diagnostico-Red {
    Write-Titulo " DIAGNÓSTICO DE RED"
    Write-Info "Comprobando conectividad, adaptadores y configuración IP..."

    # 1. Ping a internet
    $internetOK = $false
    foreach ($destino in @("8.8.8.8", "1.1.1.1", "google.com")) {
        if (Test-Connection $destino -Count 1 -Quiet -ErrorAction SilentlyContinue) {
            $internetOK = $true; break
        }
    }
    if ($internetOK) { 
        Write-OK "Conexión a internet: OK"
        Registrar-OK "Acceso a internet verificado"
    } else {
        Write-Error "Sin conexión a internet"
        Registrar-Problema "Sin acceso a internet (ping fallido)"
    }

    # 2. Adaptadores activos
    $adaptadores = Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object Status -eq "Up"
    if ($adaptadores) {
        Write-OK "Adaptadores activos: $($adaptadores.Name -join ', ')"
        foreach ($ad in $adaptadores) {
            Agregar-AlReporte "  Adaptador: $($ad.Name) | MAC: $($ad.MacAddress)" "Tecnico"
        }
    } else {
        Write-Alerta "No hay ningún adaptador de red activo"
        Registrar-Alerta "Ningún adaptador de red activo"
    }

    # 3. IP, Gateway, DNS
    $ipconfig = Get-NetIPConfiguration | Where-Object { $_.IPv4Address -and $_.NetAdapter.Status -eq "Up" }
    if ($ipconfig) {
        foreach ($conf in $ipconfig) {
            $ip = $conf.IPv4Address.IPAddress
            $gw = if ($conf.IPv4DefaultGateway) { $conf.IPv4DefaultGateway.NextHop } else { Write-Info "No definido" }
            $dns = ($conf.DNSServer.ServerAddresses -join ", ")
            Write-Info "IP local: $ip"
            Write-Info "Puerta de enlace: $gw"
            Write-Info "Servidores DNS: $dns"
            Agregar-AlReporte "IP: $ip | Gateway: $gw | DNS: $dns" "Usuario"
            if ($ip -like "169.254.*") {
                Write-Alerta "IP APIPA (169.254.x.x) → posible problema con el DHCP"
                Registrar-Alerta "IP APIPA detectada ($ip)"
            }
        }
    } else {
        Write-Alerta "No se pudo obtener configuración IP detallada"
        Registrar-Problema "Sin configuración IP válida"
    }
    Esperar-Tecla "Red analizada. Continuar..."
}

# =============================================================================
# MÓDULO 2: DIAGNÓSTICO DE IMPRESORAS
# =============================================================================
function Diagnostico-Impresora {
    Write-Titulo "DIAGNÓSTICO DE IMPRESORAS"
    Write-Info "Revisando servicio de impresión, impresoras instaladas y cola..."

    $spooler = Get-Service -Name Spooler -ErrorAction SilentlyContinue
    if ($spooler.Status -eq "Running") {
        Write-OK "Servicio de impresión (Spooler) activo"
        Registrar-OK "Servicio Spooler en ejecución"
    } else {
        Write-Error "Servicio de impresión DETENIDO"
        Registrar-Problema "Servicio Spooler detenido (estado: $($spooler.Status))"
    }

    $impresoras = Get-Printer -ErrorAction SilentlyContinue
    if ($impresoras) {
        Write-OK "Impresoras instaladas: $($impresoras.Count)"
        foreach ($imp in $impresoras) {
            Write-Info "  - $($imp.Name) : $($imp.PrinterStatus)"
            Agregar-AlReporte "Impresora: $($imp.Name) | Estado: $($imp.PrinterStatus) | Puerto: $($imp.PortName)" "Tecnico"
            if ($imp.PrinterStatus -ne "Normal") {
                Registrar-Alerta "Impresora '$($imp.Name)' con estado anormal: $($imp.PrinterStatus)"
            }
        }
    } else {
        Write-Alerta "No se encontraron impresoras instaladas"
    }

    $trabajos = Get-PrintJob -ErrorAction SilentlyContinue
    if ($trabajos) {
        Write-Alerta "Hay $($trabajos.Count) trabajo(s) pendientes en la cola"
        foreach ($job in $trabajos) {
            Agregar-AlReporte "Trabajo atascado: $($job.DocumentName) | Estado: $($job.JobStatus)" "Usuario"
            if ($job.JobStatus -match "Error") {
                Registrar-Problema "Trabajo de impresión con error: $($job.DocumentName)"
            }
        }
    } else {
        Write-OK "Cola de impresión vacía"
        Registrar-OK "Cola de impresión vacía"
    }
    Esperar-Tecla "Impresoras analizadas. Continuar..."
}

# =============================================================================
# MÓDULO 3: DIAGNÓSTICO DE MEMORIA RAM
# =============================================================================
function Diagnostico-RAM {
    Write-Titulo " DIAGNÓSTICO DE MEMORIA RAM"
    Write-Info "Calculando uso de RAM y procesos más pesados..."

    $os = Get-CimInstance Win32_OperatingSystem
    $ramTotal = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
    $ramLibre = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
    $ramUsada = [math]::Round($ramTotal - $ramLibre, 2)
    $porcUso = [math]::Round(($ramUsada / $ramTotal) * 100, 1)

    Write-Info "RAM total: $ramTotal GB"
    Write-Info "RAM usada: $ramUsada GB ($porcUso%)"
    Write-Info "RAM libre: $ramLibre GB"
    Agregar-AlReporte "RAM total: $ramTotal GB | Usada: $ramUsada GB ($porcUso%) | Libre: $ramLibre GB" "Usuario"

    if ($porcUso -ge 90) {
        Write-Error "Uso de RAM CRÍTICO ($porcUso%) → el equipo puede estar muy lento"
        Registrar-Problema "RAM al $porcUso% de uso - sistema saturado"
    } elseif ($porcUso -ge 75) {
        Write-Alerta "Uso de RAM elevado ($porcUso%) → cierra aplicaciones si notas lentitud"
        Registrar-Alerta "RAM al $porcUso% de uso - nivel elevado"
    } else {
        Write-OK "Uso de RAM normal ($porcUso%)"
        Registrar-OK "RAM en nivel óptimo"
    }

    $topProcesos = Get-Process | Sort-Object WorkingSet64 -Descending | Select-Object -First 10
    Write-Info "Procesos que más memoria consumen:"
    foreach ($proc in $topProcesos) {
        $memMB = [math]::Round($proc.WorkingSet64 / 1MB, 1)
        Write-Host "     $($proc.ProcessName) : $memMB MB" -ForegroundColor Gray
        Agregar-AlReporte "Proceso: $($proc.ProcessName) | PID: $($proc.Id) | RAM: $memMB MB" "Tecnico"
    }
    Esperar-Tecla "RAM analizada. Continuar..."
}

# =============================================================================
# MÓDULO 4: DIAGNÓSTICO DE DISCO
# =============================================================================
function Diagnostico-Disco {
    Write-Titulo "DIAGNÓSTICO DE ESPACIO EN DISCO"
    Write-Info "Revisando capacidad, espacio libre y archivos temporales..."

    $discos = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Used -and $_.Free }
    foreach ($d in $discos) {
        $total = [math]::Round(($d.Used + $d.Free) / 1GB, 2)
        $libre = [math]::Round($d.Free / 1GB, 2)
        $porcLibre = [math]::Round(($libre / $total) * 100, 1)
        $barra = "█" * [math]::Round((100 - $porcLibre) / 2.5) + "░" * [math]::Round($porcLibre / 2.5)
        Write-Host "  Unidad $($d.Name): $total GB total [$barra] $libre GB libres ($porcLibre%)" -ForegroundColor White
        Agregar-AlReporte "Disco $($d.Name): $total GB | Libre: $libre GB ($porcLibre%)" "Usuario"

        if ($porcLibre -le 5) {
            Write-Error "Espacio CRÍTICO en $($d.Name) → libera espacio urgentemente"
            Registrar-Problema "Disco $($d.Name) con solo $porcLibre% libre"
        } elseif ($porcLibre -le 10) {
            Write-Alerta "Poco espacio en $($d.Name) ($porcLibre% libre)"
            Registrar-Alerta "Disco $($d.Name) con menos del 10% libre"
        } else {
            Write-OK "Espacio adecuado en $($d.Name)"
            Registrar-OK "Disco $($d.Name) con $porcLibre% libre"
        }
    }

    # Archivos temporales
    $tempSize = 0
    $tempPaths = @($env:TEMP, "$env:SystemRoot\Temp")
    foreach ($path in $tempPaths) {
        if (Test-Path $path) {
            $tempSize += (Get-ChildItem $path -Recurse -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
        }
    }
    $tempGB = [math]::Round($tempSize / 1GB, 2)
    $tempMB = [math]::Round($tempSize / 1MB, 0)
    if ($tempSize -gt 500MB) {
        Write-Alerta "Archivos temporales: $tempGB GB ($tempMB MB) → pueden borrarse sin riesgo"
        Registrar-Alerta "Acumulados $tempGB GB de archivos temporales"
    } else {
        Write-OK "Archivos temporales: $tempMB MB (espacio aceptable)"
        Registrar-OK "Archivos temporales en nivel normal"
    }
    Esperar-Tecla "Disco analizado. Continuar..."
}

# =============================================================================
# GENERACIÓN DEL REPORTE FINAL (USUARIO + TÉCNICO)
# =============================================================================
function Generar-Reporte {
    Write-Titulo " GENERANDO REPORTE DE DIAGNÓSTICO"
    $contenido = @()
    $contenido += "=" * 70
    $contenido += "   REPORTE DE DIAGNÓSTICO - ASISTENTE REPAIR"
    $contenido += "=" * 70
    $contenido += "  Fecha:     $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')"
    $contenido += "  Equipo:    $env:COMPUTERNAME"
    $contenido += "  Usuario:   $env:USERNAME"
    $contenido += "  Admin:     $esAdmin"
    $contenido += ""
    $contenido += "=" * 70
    $contenido += "   RESUMEN PARA EL USUARIO"
    $contenido += "=" * 70
    $contenido += "  Problemas encontrados: $TotalProblemas"
    $contenido += "  Alertas:               $TotalAlertas"
    $contenido += "  Áreas correctas:       $TotalOK"
    $contenido += ""
    if ($ResumenProblemas.Count -gt 0) {
        $contenido += "  LISTA DE INCIDENCIAS:"
        foreach ($item in $ResumenProblemas) { $contenido += "    $item" }
        $contenido += ""
    }
    $contenido += "=" * 70
    $contenido += "   DETALLE AMIGABLE (LEER CON EL TÉCNICO)"
    $contenido += "=" * 70
    $contenido += $ReporteUsuario
    $contenido += ""
    $contenido += "=" * 70
    $contenido += "   DETALLE TÉCNICO (PARA SOPORTE)"
    $contenido += "=" * 70
    $contenido += $ReporteTecnico
    $contenido += ""
    $contenido += "=" * 70
    $contenido += "   COMANDOS ÚTILES (ejecutar como administrador)"
    $contenido += "=" * 70
    $contenido += "  ipconfig /flushdns          # Limpiar caché DNS"
    $contenido += "  netsh int ip reset          # Reiniciar TCP/IP"
    $contenido += "  net stop spooler && net start spooler  # Reiniciar impresión"
    $contenido += "  cleanmgr                    # Liberador de espacio"
    $contenido += "  Get-Process | Sort WS -Descending | Select -First 10  # Top procesos"
    $contenido += "=" * 70

    try {
        $contenido | Out-File $RutaReporte -Encoding UTF8 -ErrorAction Stop
        Write-OK "Reporte guardado en tu escritorio: $NombreReporte"
    } catch {
        Write-Error "No se pudo guardar el reporte en el escritorio. Se guardará en tu perfil."
        $alternativa = Join-Path $env:USERPROFILE $NombreReporte
        $contenido | Out-File $alternativa -Encoding UTF8
        Write-Info "Reporte guardado en: $alternativa"
        $script:RutaReporte = $alternativa
    }
}

# =============================================================================
# FUNCIONES DE REPARACIÓN (basadas en los .bat originales)
# =============================================================================
function Reparacion-LimpiezaBasica {
    Write-Titulo " LIMPIEZA BÁSICA (temp + papelera)"
    Write-Info "Eliminando archivos temporales del sistema..."
    Remove-Item "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item "$env:SystemRoot\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue
    Write-OK "Temporales eliminados."

    Write-Info "Vaciando papelera de reciclaje..."
    Clear-RecycleBin -Force -ErrorAction SilentlyContinue
    Write-OK "Papelera vaciada."

    Write-Info "Limpiando caché de Windows Update..."
    Remove-Item "$env:SystemRoot\SoftwareDistribution\Download\*" -Recurse -Force -ErrorAction SilentlyContinue
    Write-OK "Caché de Windows Update limpiada."
    Esperar-Tecla "Limpieza básica finalizada."
}

function Reparacion-Red {
    Write-Titulo " REPARACIÓN DE RED"
    if (-not $esAdmin) { Write-Error "Se requieren permisos de administrador para reparar la red."; return }
    Write-Info "Liberando IP actual..."
    ipconfig /release | Out-Null
    Write-Info "Renovando IP (puede tardar unos segundos)..."
    ipconfig /renew | Out-Null
    Write-Info "Limpiando caché DNS..."
    ipconfig /flushdns | Out-Null
    Write-OK "Red reparada (IP renovada, DNS limpiado)."
    Esperar-Tecla "Reparación de red completada."
}

function Reparacion-Impresora {
    Write-Titulo " REPARACIÓN DE IMPRESORA"
    if (-not $esAdmin) { Write-Error "Se requieren permisos de administrador para reparar impresoras."; return }
    Write-Info "Deteniendo servicio de impresión..."
    Stop-Service Spooler -Force -ErrorAction SilentlyContinue
    Write-Info "Eliminando trabajos atascados..."
    Remove-Item "$env:SystemRoot\System32\spool\PRINTERS\*" -Force -ErrorAction SilentlyContinue
    Write-Info "Iniciando servicio de impresión..."
    Start-Service Spooler -ErrorAction SilentlyContinue
    Write-OK "Cola de impresión limpiada y servicio reiniciado."
    Esperar-Tecla "Reparación de impresora completada."
}

function Reparacion-RAM {
    Write-Titulo "OPTIMIZACIÓN DE MEMORIA"
    Write-Info "Ejecutando tareas de liberación de memoria (ProcessIdleTasks)..."
    rundll32.exe advapi32.dll,ProcessIdleTasks
    Write-OK "Memoria optimizada."
    Write-Info "Si el equipo sigue lento, cierra manualmente los programas que no uses."
    Esperar-Tecla "Optimización de RAM finalizada."
}

# =============================================================================
# MENÚ PRINCIPAL ACCESIBLE
# =============================================================================
function Mostrar-Menu {
    Clear-Host
    Write-Host @"
  ╔══════════════════════════════════════════════════════════════╗
  ║                  .:.:. R E P A I R .:.:.                     ║
  ║               - DIAGNÓSTICO Y REPARACIÓN  -                  ║
  ║         Genera un reporte doble (usuario + técnico)          ║
  ╚══════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Cyan
    Write-Host "`n  Elige una opción escribiendo el número y presionando ENTER:`n"
    Write-Host "  1)  DIAGNOSTICAR (solo mirar, no cambiar nada)" -ForegroundColor White
    Write-Host "  2)  DIAGNOSTICAR + LIMPIEZA BÁSICA (temp, papelera)" -ForegroundColor White
    Write-Host "  3)  REPARAR RED (flus DNS, renovar IP) [requiere admin]" -ForegroundColor White
    Write-Host "  4)  REPARAR IMPRESORA (reiniciar spooler, limpiar cola) [admin]" -ForegroundColor White
    Write-Host "  5)  OPTIMIZAR RAM (liberar memoria)" -ForegroundColor White
    Write-Host "  6)  HACER TODO LO ANTERIOR (diagnóstico + todas las reparaciones)" -ForegroundColor Green
    Write-Host "  7)  SALIR" -ForegroundColor Red
    Write-Host ""
}

# =============================================================================
# PROGRAMA PRINCIPAL
# =============================================================================
do {
    Mostrar-Menu
    $opcion = Read-Host "   Tu elección (1-7)"

    switch ($opcion) {
        "1" {
            Diagnostico-Red
            Diagnostico-Impresora
            Diagnostico-RAM
            Diagnostico-Disco
            Generar-Reporte
            Write-Host "`n  ok Diagnóstico completado. Reporte guardado en el escritorio." -ForegroundColor Green
            Esperar-Tecla "Presiona ENTER para volver al menú principal."
        }
        "2" {
            Diagnostico-Red
            Diagnostico-Impresora
            Diagnostico-RAM
            Diagnostico-Disco
            Generar-Reporte
            Write-Host "`n  ¿Aplicar limpieza básica (temporales + papelera)?" -ForegroundColor Yellow
            $resp = Read-Host "  Escribe S (Sí) o N (No)"
            if ($resp -eq 'S' -or $resp -eq 's') { Reparacion-LimpiezaBasica }
            Esperar-Tecla "Volviendo al menú principal."
        }
        "3" { Reparacion-Red; Esperar-Tecla }
        "4" { Reparacion-Impresora; Esperar-Tecla }
        "5" { Reparacion-RAM; Esperar-Tecla }
        "6" {
            Diagnostico-Red
            Diagnostico-Impresora
            Diagnostico-RAM
            Diagnostico-Disco
            Generar-Reporte
            Write-Host "`n  alerta  Se aplicarán TODAS las reparaciones disponibles (requieren admin)." -ForegroundColor Yellow
            $resp = Read-Host "  ¿Confirmas? (S/N)"
            if ($resp -eq 'S' -or $resp -eq 's') {
                if ($esAdmin) {
                    Reparacion-LimpiezaBasica
                    Reparacion-Red
                    Reparacion-Impresora
                    Reparacion-RAM
                    Write-OK "Todas las reparaciones se han ejecutado."
                } else {
                    Write-Error "Ejecuta el script como Administrador para poder reparar."
                }
            }
            Esperar-Tecla "Volviendo al menú principal."
        }
        "7" { Write-Host "`n   ¡Hasta luego! Cuida tu equipo y el planeta." -ForegroundColor Cyan; break }
        default { Write-Error "Opción no válida. Elige un número del 1 al 7."; Esperar-Tecla "Presiona ENTER y vuelve a intentarlo." }
    }
} while ($opcion -ne "7")