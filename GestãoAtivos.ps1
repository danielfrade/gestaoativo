# Script de Gestão de Ativos de Equipamentos no Domínio
# Autor: Daniel Vocurca Frade (otimizado)
# Data: 06/03/2025

# Importar o módulo Active Directory
Import-Module ActiveDirectory -ErrorAction SilentlyContinue
if (-not (Get-Module -Name ActiveDirectory)) {
    Write-Host "Módulo Active Directory não encontrado. Instale o RSAT-AD-PowerShell." -ForegroundColor Red
    exit
}

# Configurações globais

# Digite o seu dominio
$Domain = ""
# Digite o caminho da OU BASE
$BaseOU = ""
$LogPath = "C:\Logs\Gestao_Ativos.log"
$ReportPath = "C:\Relatorios"
$CacheInventory = $null # Cache para evitar consultas repetidas
$MaxThreads = 20 # Máximo de threads para verificações paralelas

# Função para registrar logs
function Write-Log {
    param($Message)
    $logMessage = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss'): $Message"
    Write-Host $logMessage -ForegroundColor Gray
    Add-Content -Path $LogPath -Value $logMessage
}

# Criar diretórios de logs e relatórios
if (-not (Test-Path $LogPath)) { New-Item -Path (Split-Path $LogPath -Parent) -ItemType Directory -Force }
if (-not (Test-Path $ReportPath)) { New-Item -Path $ReportPath -ItemType Directory -Force }

# Função para criar uma interface simples
function Show-Menu {
    Clear-Host
    Write-Host "======================================" -ForegroundColor Cyan
    Write-Host "    Gestão de Ativos de Equipamentos  " -ForegroundColor Cyan
    Write-Host "======================================" -ForegroundColor Cyan
    Write-Host "1. Listar equipamentos por setor" -ForegroundColor Green
    Write-Host "2. Listar equipamentos por usuário" -ForegroundColor Green
    Write-Host "3. Listar usuários inativos e seus equipamentos" -ForegroundColor Green
    Write-Host "4. Listar equipamentos online/offline" -ForegroundColor Green
    Write-Host "5. Listar equipamentos órfãos (sem usuário)" -ForegroundColor Green
    Write-Host "6. Exportar relatório completo (CSV)" -ForegroundColor Green
    Write-Host "7. Exportar relatório completo (HTML)" -ForegroundColor Green
    Write-Host "8. Limpar equipamentos inativos (90 dias)" -ForegroundColor Green
    Write-Host "9. Atualizar inventário (limpar cache)" -ForegroundColor Green
    Write-Host "10. Sair" -ForegroundColor Red
    Write-Host "======================================" -ForegroundColor Cyan
    $choice = Read-Host "Escolha uma opção (1-10)"
    return $choice
}

# Função para coletar informações do Active Directory
function Get-Inventory {
    if ($null -ne $script:CacheInventory) {
        Write-Log "Usando dados em cache..."
        return $script:CacheInventory
    }

    Write-Log "Coletando informações do Active Directory no domínio $Domain..."
    $inventory = @()

    try {
        # Filtrar computadores e usuários ativos para reduzir carga
        Write-Host "Buscando computadores na OU $BaseOU..." -ForegroundColor Yellow
        $computers = Get-ADComputer -Filter {Enabled -eq $true} -SearchBase $BaseOU -Properties Name, OperatingSystem, OperatingSystemVersion, LastLogonDate, DistinguishedName, Created -Server $Domain -ErrorAction Stop
        Write-Host "Buscando usuários na OU $BaseOU..." -ForegroundColor Yellow
        $users = Get-ADUser -Filter {Enabled -eq $true} -SearchBase $BaseOU -Properties SamAccountName, Enabled, Department, LastLogonDate, DistinguishedName, Mail -Server $Domain -ErrorAction Stop

        if (-not $computers) { Write-Log "Nenhum computador encontrado."; return $inventory }
        if (-not $users) { Write-Log "Nenhum usuário encontrado."; return $inventory }

        Write-Log "Encontrados $($computers.Count) computadores e $($users.Count) usuários."

        # Processamento paralelo para verificações online/offline e WMI
        $inventoryJobs = @()
        $computers | ForEach-Object {
            $computer = $_
            while (@(Get-Job -State Running).Count -ge $MaxThreads) {
                Start-Sleep -Milliseconds 100
            }
            $inventoryJobs += Start-Job -ScriptBlock {
                param($computer, $users)
                $user = $null
                $department = "Sem setor"
                $userStatus = "N/A"
                $onlineStatus = "Offline"
                $ipAddress = "N/A"
                $manufacturer = "N/A"
                $model = "N/A"
                $serialNumber = "N/A"
                $osVersion = $computer.OperatingSystemVersion
                $createdDate = $computer.Created

                # Verificar status online/offline
                if (Test-Connection -ComputerName $computer.Name -Count 1 -Quiet -ErrorAction SilentlyContinue) {
                    $onlineStatus = "Online"
                    try {
                        $ipAddress = [System.Net.Dns]::GetHostAddresses($computer.Name) | Where-Object { $_.AddressFamily -eq "InterNetwork" } | Select-Object -First 1 -ExpandProperty IPAddressToString
                    } catch { $ipAddress = "Erro ao obter IP" }

                    # Obter fabricante, modelo e número de série via WMI
                    try {
                        $bios = Get-WmiObject -Class Win32_BIOS -ComputerName $computer.Name -ErrorAction Stop
                        $system = Get-WmiObject -Class Win32_ComputerSystem -ComputerName $computer.Name -ErrorAction Stop
                        $manufacturer = $system.Manufacturer
                        $model = $system.Model
                        $serialNumber = $bios.SerialNumber
                    } catch {
                        Write-Output "Erro ao obter informações de hardware para $($computer.Name): $_"
                    }
                }

                # Associar computador a um usuário
                $lastUser = $null
                try {
                    $lastUser = (Get-WmiObject -Class Win32_ComputerSystem -ComputerName $computer.Name -ErrorAction SilentlyContinue).UserName
                    if ($lastUser) {
                        $lastUser = $lastUser.Split('\')[-1]
                        $user = $users | Where-Object { $_.SamAccountName -eq $lastUser }
                    }
                } catch { Write-Output "Erro ao obter usuário do computador $($computer.Name): $_" }

                # Determinar setor
                if ($user -and $user.Department) {
                    $department = $user.Department
                } else {
                    $ou = $computer.DistinguishedName -split ',' | Where-Object { $_ -like "OU=*" }
                    if ($ou) { $department = ($ou[0] -split '=')[1] }
                }

                # Determinar status do usuário
                if ($user) {
                    $userStatus = if ($user.Enabled) { "Ativo" } else { "Inativo" }
                }

                # Criar objeto personalizado
                return [PSCustomObject]@{
                    ComputerName    = $computer.Name
                    OperatingSystem = $computer.OperatingSystem
                    OSVersion       = $osVersion
                    LastLogonDate   = $computer.LastLogonDate
                    CreatedDate     = $createdDate
                    User            = if ($user) { $user.SamAccountName } else { "N/A" }
                    UserEmail       = if ($user -and $user.Mail) { $user.Mail } else { "N/A" }
                    Department      = $department
                    UserStatus      = $userStatus
                    OnlineStatus    = $onlineStatus
                    IPAddress       = $ipAddress
                    Manufacturer    = $manufacturer
                    Model           = $model
                    SerialNumber    = $serialNumber
                    OU              = $computer.DistinguishedName
                }
            } -ArgumentList $computer, $users
        }

        # Aguardar conclusão dos jobs e coletar resultados
        $i = 0
        $total = $inventoryJobs.Count
        foreach ($job in $inventoryJobs) {
            $i++
            Write-Progress -Activity "Processando computadores" -Status "Computador $i de $total" -PercentComplete (($i / $total) * 100)
            $result = Receive-Job -Job $job -Wait
            if ($result) { $inventory += $result }
            Remove-Job -Job $job
        }
        Write-Progress -Activity "Processando computadores" -Completed
        $script:CacheInventory = $inventory
    } catch {
        Write-Log "Erro ao coletar informações do Active Directory: $_"
    }
    return $inventory
}

# Função para listar por setor
function List-ByDepartment {
    $inventory = Get-Inventory
    if (-not $inventory) { Write-Host "Nenhum dado para listar." -ForegroundColor Yellow; Pause; return }
    $departments = $inventory | Group-Object Department
    foreach ($dept in $departments) {
        Write-Host "`nSetor: $($dept.Name)" -ForegroundColor Cyan
        Write-Host "----------------------------------------"
        $dept.Group | Format-Table ComputerName, User, OperatingSystem, LastLogonDate, OnlineStatus, SerialNumber -AutoSize
    }
    Pause
}

# Função para listar por usuário
function List-ByUser {
    $inventory = Get-Inventory
    if (-not $inventory) { Write-Host "Nenhum dado para listar." -ForegroundColor Yellow; Pause; return }
    $users = $inventory | Group-Object User
    foreach ($user in $users) {
        Write-Host "`nUsuário: $($user.Name)" -ForegroundColor Cyan
        Write-Host "----------------------------------------"
        $user.Group | Format-Table ComputerName, Department, OperatingSystem, LastLogonDate, OnlineStatus, SerialNumber -AutoSize
    }
    Pause
}

# Função para listar usuários inativos
function List-InactiveUsers {
    $inventory = Get-Inventory
    if (-not $inventory) { Write-Host "Nenhum dado para listar." -ForegroundColor Yellow; Pause; return }
    $inactive = $inventory | Where-Object { $_.UserStatus -eq "Inativo" }
    if ($inactive) {
        Write-Host "`nUsuários Inativos e Equipamentos Associados" -ForegroundColor Cyan
        Write-Host "----------------------------------------"
        $inactive | Format-Table ComputerName, User, Department, OperatingSystem, LastLogonDate, OnlineStatus, SerialNumber -AutoSize
    } else {
        Write-Host "`nNenhum usuário inativo encontrado." -ForegroundColor Yellow
    }
    Pause
}

# Função para listar equipamentos online/offline
function List-OnlineOffline {
    $inventory = Get-Inventory
    if (-not $inventory) { Write-Host "Nenhum dado para listar." -ForegroundColor Yellow; Pause; return }
    Write-Host "`nEquipamentos Online" -ForegroundColor Cyan
    Write-Host "----------------------------------------"
    $inventory | Where-Object { $_.OnlineStatus -eq "Online" } | Format-Table ComputerName, IPAddress, User, Department, OperatingSystem, SerialNumber -AutoSize
    Write-Host "`nEquipamentos Offline" -ForegroundColor Cyan
    Write-Host "----------------------------------------"
    $inventory | Where-Object { $_.OnlineStatus -eq "Offline" } | Format-Table ComputerName, User, Department, OperatingSystem, SerialNumber -AutoSize
    Pause
}

# Função para listar equipamentos órfãos
function List-OrphanedEquipment {
    $inventory = Get-Inventory
    if (-not $inventory) { Write-Host "Nenhum dado para listar." -ForegroundColor Yellow; Pause; return }
    $orphaned = $inventory | Where-Object { $_.User -eq "N/A" }
    if ($orphaned) {
        Write-Host "`nEquipamentos sem Usuário Associado" -ForegroundColor Cyan
        Write-Host "----------------------------------------"
        $orphaned | Format-Table ComputerName, Department, OperatingSystem, LastLogonDate, OnlineStatus, SerialNumber -AutoSize
    } else {
        Write-Host "`nNenhum equipamento órfão encontrado." -ForegroundColor Yellow
    }
    Pause
}

# Função para exportar relatório completo em CSV
function Export-ReportCSV {
    $inventory = Get-Inventory
    if (-not $inventory) { Write-Host "Nenhum dado para exportar." -ForegroundColor Yellow; Pause; return }
    $date = Get-Date -Format "yyyyMMdd_HHmmss"
    $filePath = "$ReportPath\Inventario_Ativos_$date.csv"
    $inventory | Select-Object ComputerName, OperatingSystem, OSVersion, LastLogonDate, CreatedDate, User, UserEmail, Department, UserStatus, OnlineStatus, IPAddress, Manufacturer, Model, SerialNumber, OU | Export-Csv -Path $filePath -NoTypeInformation -Encoding UTF8
    Write-Log "Relatório CSV exportado para $filePath"
    Write-Host "Relatório CSV exportado para $filePath" -ForegroundColor Green
    Pause
}

# Função para exportar relatório completo em HTML
function Export-ReportHTML {
    $inventory = Get-Inventory
    if (-not $inventory) { Write-Host "Nenhum dado para exportar." -ForegroundColor Yellow; Pause; return }
    $date = Get-Date -Format "yyyyMMdd_HHmmss"
    $filePath = "$ReportPath\Inventario_Ativos_$date.html"
    $htmlHeader = @"
    <style>
        table { border-collapse: collapse; width: 100%; font-family: Arial, sans-serif; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #4CAF50; color: white; }
        tr:nth-child(even) { background-color: #f2f2f2; }
    </style>
"@
    $inventory | Select-Object ComputerName, OperatingSystem, OSVersion, LastLogonDate, CreatedDate, User, UserEmail, Department, UserStatus, OnlineStatus, IPAddress, Manufacturer, Model, SerialNumber, OU | ConvertTo-Html -Head $htmlHeader | Set-Content -Path $filePath
    Write-Log "Relatório HTML exportado para $filePath"
    Write-Host "Relatório HTML exportado para $filePath" -ForegroundColor Green
    Pause
}

# Função para limpar equipamentos inativos
function Clear-InactiveEquipment {
    $inventory = Get-Inventory
    if (-not $inventory) { Write-Host "Nenhum dado para processar." -ForegroundColor Yellow; Pause; return }
    $threshold = (Get-Date).AddDays(-90)
    $inactive = $inventory | Where-Object { $_.LastLogonDate -and $_.LastLogonDate -lt $threshold }
    
    if ($inactive) {
        Write-Host "`nEquipamentos inativos há mais de 90 dias" -ForegroundColor Cyan
        Write-Host "----------------------------------------"
        $inactive | Format-Table ComputerName, LastLogonDate, User, Department, SerialNumber -AutoSize
        $confirm = Read-Host "Deseja desativar esses equipamentos no Active Directory? (S/N)"
        if ($confirm -eq "S") {
            foreach ($item in $inactive) {
                try {
                    Disable-ADAccount -Identity $item.ComputerName -Server $Domain -ErrorAction Stop
                    Write-Log "Computador $($item.ComputerName) desativado."
                } catch {
                    Write-Log "Erro ao desativar $($item.ComputerName): $_"
                }
            }
        }
    } else {
        Write-Host "`nNenhum equipamento inativo há mais de 90 dias." -ForegroundColor Yellow
    }
    Pause
}

# Função para limpar cache
function Clear-Cache {
    $script:CacheInventory = $null
    Write-Host "Cache limpo. O próximo inventário será atualizado." -ForegroundColor Green
    Pause
}

# Loop principal
do {
    $choice = Show-Menu
    switch ($choice) {
        "1" { List-ByDepartment }
        "2" { List-ByUser }
        "3" { List-InactiveUsers }
        "4" { List-OnlineOffline }
        "5" { List-OrphanedEquipment }
        "6" { Export-ReportCSV }
        "7" { Export-ReportHTML }
        "8" { Clear-InactiveEquipment }
        "9" { Clear-Cache }
        "10" { Write-Host "Sair..." -ForegroundColor Red; break }
        default { Write-Host "Opção inválida!" -ForegroundColor Red; Pause }
    }
} while ($true)
