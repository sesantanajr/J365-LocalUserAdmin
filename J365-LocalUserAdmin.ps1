#####################################
##### Jornada 365 | Admin Local ##### 
#####      jornada365.cloud     #####
#####################################

# Verificacao do Sistema Operacional
$osVersion = [System.Environment]::OSVersion.Version
$isWindows10Or11 = $false

if ($osVersion.Major -eq 10 -and ($osVersion.Build -ge 10240 -and $osVersion.Build -lt 22000)) {
    $isWindows10Or11 = $true
} elseif ($osVersion.Major -eq 10 -and $osVersion.Build -ge 22000) {
    $isWindows10Or11 = $true
}

if (-not $isWindows10Or11) {
    Write-Host "Sistema operacional incompativel. Saindo do script."
    Exit
}

Write-Host "Sistema operacional compativel. Continuando..."

# Nome do usuario e senha
$username = "Administrador"
$password = "@367Mund*17"
$logFileBase = "C:\Windows\Temp\CriarAdminLocal"
$logFile = "$logFileBase.log"

# Gerenciando o arquivo de log
if (Test-Path $logFile) {
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $logFile = "$logFileBase_$timestamp.log"
}

# Redirecionando a saida para um arquivo de log
Start-Transcript -Path $logFile

# Verifica se o usuario ja existe
$user = Get-LocalUser -Name $username -ErrorAction SilentlyContinue

if ($user -eq $null) {
    Write-Host "Usuario $username nao existe. Criando..."
    
    # Criando o usuario 'helpdesk'
    New-LocalUser -Name $username -Password (ConvertTo-SecureString $password -AsPlainText -Force) -FullName "Helpdesk User" -Description "Conta criada para suporte tecnico" -UserMayNotChangePassword -PasswordNeverExpires
    Write-Host "Usuario $username criado."
} else {
    Write-Host "O usuario $username ja existe."
}

# Forca a criacao do perfil do usuario atraves de logon temporario
$profilePath = "C:\Users\$username"
if (-Not (Test-Path $profilePath)) {
    Write-Host "Perfil do usuario $username nao encontrado. Tentando forcar a criacao do perfil..."
    
    try {
        Start-Process -FilePath "cmd.exe" -ArgumentList "/c", "exit" -Credential (New-Object System.Management.Automation.PSCredential($username, (ConvertTo-SecureString $password -AsPlainText -Force))) -NoNewWindow -Wait
        Write-Host "Processo temporario iniciado para criar o perfil do usuario."
    } catch {
        Write-Error "Erro ao forcar a criacao do perfil do usuario. Detalhes: $_"
        Exit 1
    }
    
    # Verifica novamente se a pasta do perfil foi criada
    if (Test-Path $profilePath) {
        Write-Host "O perfil do usuario $username foi criado com sucesso em $profilePath."
    } else {
        Write-Host "Falha ao criar o perfil do usuario $username em $profilePath."
        Exit 1
    }
} else {
    Write-Host "O perfil do usuario $username ja existe em $profilePath."
}

# Identificando o nome do grupo Administradores no idioma local
$adminGroupName = (Get-LocalGroup | Where-Object { $_.SID -eq 'S-1-5-32-544' }).Name

if (-not $adminGroupName) {
    Write-Error "Falha ao localizar o grupo de Administradores usando o SID."
    Exit 1
}

# Adicionando o usuario ao grupo de Administradores
try {
    Add-LocalGroupMember -Group $adminGroupName -Member $username
    Write-Host "Usuario $username adicionado ao grupo $adminGroupName com sucesso."
} catch {
    Write-Error "Falha ao adicionar o usuario $username ao grupo $adminGroupName. Detalhes: $_"
    Exit 1
}

# Encerrando a transcricao do log se estiver ativa
if ($transcript = (Get-Variable -Name "Transcribing" -ValueOnly -ErrorAction SilentlyContinue)) {
    Stop-Transcript
}
