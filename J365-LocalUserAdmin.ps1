##### J365-LocalUserAdmin
# Defina o nome do usuário, senha e o arquivo de log
$Username = "helpdesk"
$Password = ConvertTo-SecureString "@365Mund@354" -AsPlainText -Force
$LogDirectory = "C:\Logs"
$LogFile = "$LogDirectory\CriarAdminLocal.log"

# Função para logar mensagens
function Log-Message {
    param (
        [string]$Message,
        [string]$LogType = "INFO"
    )
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "$Timestamp [$LogType] - $Message"
    Write-Host $LogEntry
    try {
        Add-Content -Path $LogFile -Value $LogEntry
    } catch {
        Write-Host "Falha ao gravar no arquivo de log. Detalhes: $_" -ForegroundColor Red
    }
}

# Criar diretório de log se não existir
if (-not (Test-Path $LogDirectory)) {
    try {
        New-Item -Path $LogDirectory -ItemType Directory -Force
        Log-Message "Diretório de log $LogDirectory criado com sucesso."
    } catch {
        Write-Host "Não foi possível criar o diretório de log. Detalhes: $_" -ForegroundColor Red
        exit 1
    }
}

# Iniciar o log
Log-Message "Iniciando o script de criação de usuário."

# Validar se a senha cumpre requisitos básicos
if ($Password.Length -lt 8) {
    Log-Message "A senha fornecida é muito curta. A senha deve ter pelo menos 8 caracteres." "ERROR"
    exit 1
}

# Função para encontrar o nome correto do grupo de Administradores
function Get-AdministratorsGroup {
    $GroupNames = @("Administrators", "Administradores", "Administratoren", "Администраторы", "Amministratori", "Administradorzy", "Адміністратори", "管理员")
    foreach ($Name in $GroupNames) {
        try {
            $Group = Get-LocalGroup -Name $Name -ErrorAction Stop
            return $Name
        } catch {
            continue
        }
    }
    Log-Message "Nenhum grupo de administradores encontrado neste sistema." "ERROR"
    exit 1
}

$GroupName = Get-AdministratorsGroup

# Criação do usuário
try {
    $UserExists = Get-LocalUser -Name $Username -ErrorAction Stop
    Log-Message "Usuário $Username já existe. Atualizando a senha."
    $UserExists | Set-LocalUser -Password $Password
} catch {
    try {
        Log-Message "Criando o usuário $Username."
        New-LocalUser -Name $Username -Password $Password -FullName "Helpdesk" -Description "Conta de administrador local" -PasswordNeverExpires -AccountNeverExpires
    } catch {
        Log-Message "Erro ao tentar criar o usuário $Username. Detalhes: $_" "ERROR"
        exit 1
    }
}

# Adicionar o usuário ao grupo de administradores
try {
    Remove-LocalGroupMember -Group $GroupName -Member $Username -ErrorAction SilentlyContinue
    Add-LocalGroupMember -Group $GroupName -Member $Username -ErrorAction Stop
    Log-Message "Usuário $Username foi adicionado ao grupo $GroupName com sucesso."
} catch {
    Log-Message "Erro ao tentar adicionar o usuário $Username ao grupo $GroupName. Detalhes: $_" "ERROR"
    exit 1
}

Log-Message "Script concluído com sucesso."
