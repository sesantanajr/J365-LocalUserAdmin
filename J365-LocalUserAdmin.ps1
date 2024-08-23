#####################################
##### Jornada 365 | Admin Local ##### 
#####      jornada365.cloud     #####
#####################################

# Definição das variáveis
$Username = "helpdesk"
$Password = ConvertTo-SecureString "@367Mund*17" -AsPlainText -Force
$LogFile = "C:\Windows\Temp\CriarAdminLocal.log"

# Função para logging com níveis de severidade
function Write-Log {
    param (
        [string]$message,
        [string]$level = "INFO"
    )
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $logEntry = "$timestamp [$level] - $message"
    Add-Content -Path $LogFile -Value $logEntry
    Write-Host $logEntry
}

# Função para verificar se o usuário existe usando Get-CimInstance
function User-Exists {
    param([string]$username)
    $user = Get-CimInstance -ClassName Win32_UserAccount -Filter "Name='$username' AND LocalAccount=True"
    return ($null -ne $user)
}

# Função para criar ou atualizar o usuário
function Manage-User {
    if (User-Exists $Username) {
        Write-Log "Usuário $Username já existe. Atualizando a senha."
        try {
            $user = [ADSI]"WinNT://$env:COMPUTERNAME/$Username,user"
            $user.SetPassword($Password.ToString())
            $user.SetInfo()
            Write-Log "Senha do usuário $Username atualizada com sucesso."
        } catch {
            Write-Log "Erro ao atualizar a senha do usuário: $($_.Exception.Message)" "ERROR"
            return $false
        }
    } else {
        Write-Log "Criando novo usuário $Username."
        try {
            $computer = [ADSI]"WinNT://$env:COMPUTERNAME,computer"
            $user = $computer.Create("User", $Username)
            $user.SetPassword($Password.ToString())
            $user.UserFlags = 65536 # ADS_UF_DONT_EXPIRE_PASSWD
            $user.SetInfo()
            Write-Log "Usuário $Username criado com sucesso."
        } catch {
            Write-Log "Erro ao criar o usuário: $($_.Exception.Message)" "ERROR"
            return $false
        }
    }
    return $true
}

# Função para obter o nome do grupo de Administradores
function Get-AdminGroupName {
    try {
        $adminGroup = Get-CimInstance -ClassName Win32_Group -Filter "SID='S-1-5-32-544'"
        return $adminGroup.Name
    } catch {
        Write-Log "Erro ao obter o grupo de administradores: $($_.Exception.Message)" "ERROR"
        return $null
    }
}

# Função para adicionar o usuário ao grupo de Administradores
function Add-To-Admins {
    $adminGroupName = Get-AdminGroupName
    if ($null -eq $adminGroupName) {
        Write-Log "Não foi possível encontrar o grupo de Administradores." "ERROR"
        return $false
    }

    try {
        $group = [ADSI]"WinNT://$env:COMPUTERNAME/$adminGroupName,group"
        $members = @($group.Invoke("Members"))
        $isMember = $members | ForEach-Object { $_.GetType().InvokeMember("Name", 'GetProperty', $null, $_, $null) } | Where-Object { $_ -eq $Username }

        if ($isMember) {
            Write-Log "Usuário $Username já é membro do grupo $adminGroupName."
        } else {
            $group.Add("WinNT://$env:COMPUTERNAME/$Username,user")
            Write-Log "Usuário $Username adicionado ao grupo $adminGroupName com sucesso."
        }
        return $true
    } catch {
        Write-Log "Erro ao adicionar o usuário ao grupo de Administradores: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

# Função para criar o perfil do usuário no C:\Users usando robocopy com exclusão de junction points
function Create-UserProfile {
    $profilePath = "C:\Users\$Username"

    if (-Not (Test-Path $profilePath)) {
        Write-Log "Perfil do usuário $Username não encontrado. Criando perfil padrão..."

        try {
            # Usar Start-Process para rodar robocopy com exclusão de junction points (/XJ)
            $cmd = "robocopy C:\Users\Default $profilePath /MIR /R:3 /W:5 /XJ"
            Write-Log "Executando: $cmd"
            $process = Start-Process -FilePath "cmd.exe" -ArgumentList "/c $cmd" -Wait -NoNewWindow -PassThru

            if ($process.ExitCode -eq 0) {
                Write-Log "Perfil padrão criado com sucesso para o usuário $Username."
            } else {
                throw "O robocopy retornou um código de erro: $($process.ExitCode)."
            }
        } catch {
            Write-Log "Erro ao criar o perfil do usuário: $($_.Exception.Message)" "ERROR"
            return $false
        }
    } else {
        Write-Log "O perfil do usuário $Username já existe em $profilePath."
        return $true
    }
}

# Execução principal
try {
    Write-Log "Iniciando script"

    $userManaged = Manage-User
    if (-not $userManaged) {
        throw "Falha ao gerenciar o usuário."
    }

    $adminAdded = Add-To-Admins
    if (-not $adminAdded) {
        throw "Falha ao adicionar o usuário ao grupo de Administradores."
    }

    $profileCreated = Create-UserProfile
    if (-not $profileCreated) {
        throw "Falha ao criar o perfil do usuário."
    }

    Write-Log "Todas as etapas foram concluídas com êxito."
} catch {
    Write-Log "Ocorreu um erro inesperado: $($_.Exception.Message)" "ERROR"
    exit 1
} finally {
    Write-Log "Encerrando script."
}

