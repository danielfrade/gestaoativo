﻿# Script de Gestão de Ativos de Equipamentos no Domínio
# Autor: Daniel Vocurca Frade
# Data: 06/03/2025

# Importar o módulo Active Directory
Import-Module ActiveDirectory -ErrorAction SilentlyContinue
if (-not (Get-Module -Name ActiveDirectory)) {
    Write-Host "Módulo Active Directory não encontrado. Instale o RSAT-AD-PowerShell." -ForegroundColor Red
    exit
}

# Função para criar uma interface simples
function Show-Menu {
    Clear-Host
    Write-Host "======================================" -ForegroundColor Cyan
    Write-Host "    Gestão de Ativos de Equipamentos  " -ForegroundColor Cyan
    Write-Host "======================================" -ForegroundColor Cyan
    Write-Host "1. Listar equipamentos por setor" -ForegroundColor Green
    Write-Host "2. Listar equipamentos por usuário" -ForegroundColor Green
    Write-Host "3. Listar usuários inativos e seus equipamentos" -ForegroundColor Green
    Write-Host "4. Exportar relatório completo (CSV)" -ForegroundColor Green
    Write-Host "5. Sair" -ForegroundColor Red
    Write-Host "======================================" -ForegroundColor Cyan
    $choice = Read-Host "Escolha uma opção (1-5)"
    return $choice
}

# Função para obter informações de computadores e usuários
function Get-Inventory {
    Write-Host "Coletando informações do Active Directory..." -ForegroundColor Yellow
    $computers = Get-ADComputer -Filter * -Properties Name, OperatingSystem, LastLogonDate, DistinguishedName
    $users = Get-ADUser -Filter * -Properties SamAccountName, Enabled, Department, LastLogonDate, DistinguishedName
    $inventory = @()

    foreach ($computer in $computers) {
        $user = $null
        $department = "Sem setor"
        $userStatus = "N/A"

        # Tentar associar o computador a um usuário (baseado no logon ou nome do computador)
        $computerName = $computer.Name
        $lastUser = (Get-WmiObject -Class Win32_ComputerSystem -ComputerName $computerName -ErrorAction SilentlyContinue).UserName
        if ($lastUser) {
            $lastUser = $lastUser.Split('\')[-1] # Pegar apenas o SamAccountName
            $user = $users | Where-Object { $_.SamAccountName -eq $lastUser }
        }

        # Determinar o setor (usando o Department do usuário ou OU do computador)
        if ($user -and $user.Department) {
            $department = $user.Department
        } else {
            # Se não houver usuário ou departamento, usar a OU do computador
            $ou = $computer.DistinguishedName -split ',' | Where-Object { $_ -like "OU=*" }
            if ($ou) { $department = ($ou[0] -split '=')[1] }
        }

        # Determinar o status do usuário (ativo/inativo)
        if ($user) {
            $userStatus = if ($user.Enabled) { "Ativo" } else { "Inativo" }
        }

        # Criar objeto personalizado para o inventário
        $inventory += [PSCustomObject]@{
            ComputerName     = $computer.Name
            OperatingSystem  = $computer.OperatingSystem
            LastLogonDate    = $computer.LastLogonDate
            User             = if ($user) { $user.SamAccountName } else { "N/A" }
            Department       = $department
            UserStatus       = $userStatus
            OU               = $computer.DistinguishedName
        }
    }
    return $inventory
}

# Função para listar por setor
function List-ByDepartment {
    $inventory = Get-Inventory
    $departments = $inventory | Group-Object Department
    foreach ($dept in $departments) {
        Write-Host "`nSetor: $($dept.Name)" -ForegroundColor Cyan
        Write-Host "----------------------------------------"
        $dept.Group | Format-Table ComputerName, User, OperatingSystem, LastLogonDate -AutoSize
    }
    Pause
}

# Função para listar por usuário
function List-ByUser {
    $inventory = Get-Inventory
    $users = $inventory | Group-Object User
    foreach ($user in $users) {
        Write-Host "`nUsuário: $($user.Name)" -ForegroundColor Cyan
        Write-Host "----------------------------------------"
        $user.Group | Format-Table ComputerName, Department, OperatingSystem, LastLogonDate -AutoSize
    }
    Pause
}

# Função para listar usuários inativos
function List-InactiveUsers {
    $inventory = Get-Inventory
    $inactive = $inventory | Where-Object { $_.UserStatus -eq "Inativo" }
    if ($inactive) {
        Write-Host "`nUsuários Inativos e Equipamentos Associados" -ForegroundColor Cyan
        Write-Host "----------------------------------------"
        $inactive | Format-Table ComputerName, User, Department, OperatingSystem, LastLogonDate -AutoSize
    } else {
        Write-Host "`nNenhum usuário inativo encontrado." -ForegroundColor Yellow
    }
    Pause
}

# Função para exportar relatório completo
function Export-Report {
    $inventory = Get-Inventory
    $date = Get-Date -Format "yyyyMMdd_HHmmss"
    $filePath = "C:\Relatorios\Inventario_Ativos_$date.csv"
    
    # Criar diretório se não existir
    $dir = Split-Path $filePath -Parent
    if (-not (Test-Path $dir)) { New-Item -Path $dir -ItemType Directory }

    $inventory | Export-Csv -Path $filePath -NoTypeInformation -Encoding UTF8
    Write-Host "Relatório exportado para $filePath" -ForegroundColor Green
    Pause
}

# Loop principal
do {
    $choice = Show-Menu
    switch ($choice) {
        "1" { List-ByDepartment }
        "2" { List-ByUser }
        "3" { List-InactiveUsers }
        "4" { Export-Report }
        "5" { Write-Host "Saindo..." -ForegroundColor Red; break }
        default { Write-Host "Opção inválida!" -ForegroundColor Red; Pause }
    }
} while ($true)