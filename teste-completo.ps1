# Teste Completo Simplificado - PatoCash Kubernetes

param(
    [switch]$LimparTudo,
    [switch]$SemPrompt,
    [switch]$ForcarReconstrucao,
    [switch]$ForcarDeploy
)

# Verificar e iniciar Docker se necessário
function Start-DockerService {
    Write-Host "Verificando Docker..." -ForegroundColor Yellow
    
    # Verificar se Docker está instalado
    if (!(Get-Command docker -ErrorAction SilentlyContinue)) {
        throw "Docker não está instalado!"
    }
    
    # Verificar se Docker está rodando
    try {
        docker version 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Docker: Já rodando" -ForegroundColor Green
            return
        }
    } catch {
        # Docker não está rodando
    }
    
    Write-Host "Iniciando Docker Desktop..." -ForegroundColor Yellow
    
    # Tentar iniciar Docker Desktop
    $dockerDesktopPath = @(
        "${env:ProgramFiles}\Docker\Docker\Docker Desktop.exe",
        "${env:LOCALAPPDATA}\Programs\Docker\Docker\Docker Desktop.exe"
    ) | Where-Object { Test-Path $_ } | Select-Object -First 1
    
    if ($dockerDesktopPath) {
        Start-Process -FilePath $dockerDesktopPath -WindowStyle Hidden
        Write-Host "Aguardando Docker inicializar..." -ForegroundColor Yellow
        
        # Aguardar até 60 segundos para Docker inicializar
        $timeout = 60
        $elapsed = 0
        while ($elapsed -lt $timeout) {
            try {
                docker version 2>$null | Out-Null
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "Docker: Iniciado com sucesso" -ForegroundColor Green
                    return
                }
            } catch { }
            
            Start-Sleep -Seconds 2
            $elapsed += 2
            Write-Host "." -NoNewline -ForegroundColor Yellow
        }
        Write-Host ""
        
        # Se chegou aqui, Docker não iniciou no tempo esperado
        Write-Host "Docker demorou para inicializar. Tentando prosseguir..." -ForegroundColor Yellow
    } else {
        Write-Host "Docker Desktop não encontrado nos caminhos padrão" -ForegroundColor Red
        throw "Por favor, inicie o Docker Desktop manualmente"
    }
}

# Verificar pré-requisitos essenciais
function Test-Prerequisites {
    $missing = @()
    
    if (!(docker --version 2>$null)) { $missing += "Docker" }
    if (!(kubectl version --client=true 2>$null)) { $missing += "kubectl" }
    if (!(minikube version 2>$null)) { $missing += "Minikube" }
    
    if ($missing.Count -gt 0) {
        Write-Host "FALTANDO: $($missing -join ', ')" -ForegroundColor Red
        return $false
    }
    
    Write-Host "PRE-REQUISITOS: OK" -ForegroundColor Green
    return $true
}

function Clear-Environment {
    if (!$LimparTudo) { return }
    
    Write-Host "Limpando ambiente..." -ForegroundColor Yellow
    
    # Parar processos
    Get-Job | Stop-Job -ErrorAction SilentlyContinue
    Get-Job | Remove-Job -ErrorAction SilentlyContinue
    Get-Process | Where-Object { $_.ProcessName -match "kubectl|minikube" } | Stop-Process -Force -ErrorAction SilentlyContinue
    
    # Limpar recursos K8s (incluindo namespace monitoring)
    kubectl delete namespace monitoring --ignore-not-found=true 2>$null | Out-Null
    @("hpa", "deployment", "service", "configmap", "secret", "pod", "replicaset") | ForEach-Object {
        kubectl delete $_ --all --ignore-not-found=true 2>$null | Out-Null
    }
    
    minikube delete 2>$null | Out-Null
    Write-Host "Ambiente limpo" -ForegroundColor Green
}

# Verificar estado do ambiente
function Get-EnvironmentStatus {
    $minikubeRunning = (minikube status 2>$null) -match "Running"
    $appDeployed = (kubectl get deployment patocast-backend 2>$null) -and (kubectl get hpa patocast-backend-hpa 2>$null)
    
    $imagesBuilt = $false
    if ($minikubeRunning) {
        minikube docker-env --shell powershell | Invoke-Expression 2>$null
        $imagesBuilt = (docker images patocast-backend:latest -q 2>$null) -and (docker images patocast-frontend:latest -q 2>$null)
    }
    
    Write-Host "Status: Minikube=$minikubeRunning | App=$appDeployed | Images=$imagesBuilt)" -ForegroundColor Cyan
    
    return @{
        MinikubeRunning = $minikubeRunning
        AppDeployed = $appDeployed
        ImagesBuilt = $imagesBuilt
    }
}

# Iniciar/verificar Minikube
function Start-MinikubeCluster {
    if ((minikube status 2>$null) -match "Running" -and !$LimparTudo) {
        Write-Host "Minikube: Ja rodando" -ForegroundColor Green
    } else {
        Write-Host "Iniciando Minikube..." -ForegroundColor Yellow
        minikube start --driver=docker
        if ($LASTEXITCODE -ne 0) { throw "Falha ao iniciar Minikube" }
    }
    
    # Habilitar metrics-server se necessário
    if (!(kubectl get apiservice v1beta1.metrics.k8s.io 2>$null)) {
        Write-Host "Habilitando metrics-server..." -ForegroundColor Yellow
        minikube addons enable metrics-server
        Start-Sleep -Seconds 15
    }
}

# Construir imagens Docker
function Build-DockerImages {
    Write-Host "Configurando Docker para Minikube..." -ForegroundColor Yellow
    minikube docker-env --shell powershell | Invoke-Expression
    
    # Sempre construir após limpar ambiente
    if ($LimparTudo -or $ForcarReconstrucao) {
        Write-Host "Reconstruindo imagens..." -ForegroundColor Yellow
    } else {
        $backendExists = docker images patocast-backend:latest -q 2>$null
        $frontendExists = docker images patocast-frontend:latest -q 2>$null
        
        if ($backendExists -and $frontendExists) {
            Write-Host "Imagens Docker: Reutilizando existentes" -ForegroundColor Green
            return $true
        }
    }
    
    if (!(docker images postgres:16-alpine -q 2>$null)) {
        docker pull postgres:16-alpine | Out-Null
    }
    
    Write-Host "Construindo imagens..." -ForegroundColor Yellow
    
    docker build -t patocast-backend:latest .\backend
    if ($LASTEXITCODE -ne 0) { throw "Falha no build do backend" }
    
    docker build -t patocast-frontend:latest .\front  
    if ($LASTEXITCODE -ne 0) { throw "Falha no build do frontend" }
    
    Write-Host "Imagens Docker: Construidas" -ForegroundColor Green
}

# Configurar Kubernetes
function Setup-KubernetesConfig {
    # Criar namespace monitoring
    kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f - 2>$null
    
    # Verificar/criar arquivo .env
    if (!(Test-Path ".env")) {
        if (Test-Path ".env-exemplo") {
            Copy-Item ".env-exemplo" ".env"
            Write-Host ".env criado a partir do exemplo" -ForegroundColor Green
        } else {
            # Criar .env básico
            @"
POSTGRES_DB=patocast_db
POSTGRES_USER=patocast_user
POSTGRES_PASSWORD=patocast123
DATABASE_URL=postgresql://patocast_user:patocast123@postgres-service:5432/patocast_db
HOST_BACKEND=patocast-backend-service
PORT_BACKEND=5000
NODE_ENV=production
"@ | Out-File -FilePath ".env" -Encoding UTF8
            Write-Host ".env basico criado" -ForegroundColor Yellow
        }
    }
    
    # Criar Secrets e ConfigMaps
    kubectl delete secret patocast-secrets --ignore-not-found=true 2>$null
    kubectl create secret generic patocast-secrets --from-env-file=.env 2>$null
    
    kubectl delete configmap patocast-config postgres-init-scripts --ignore-not-found=true 2>$null
    kubectl create configmap patocast-config --from-literal=HOST_BACKEND="patocast-backend-service" --from-literal=PORT_BACKEND="5000" --from-literal=NODE_ENV="production" 2>$null
    
    # Verificar se existe diretório banco_de_dados
    if (Test-Path "./banco_de_dados/") {
        kubectl create configmap postgres-init-scripts --from-file=./banco_de_dados/ 2>$null
    }
    
    Write-Host "Kubernetes configurado" -ForegroundColor Green
}

# Deploy da aplicação
function Deploy-Application {
    Write-Host "Executando deploy..." -ForegroundColor Yellow

    # Se ForcarDeploy estiver ativo, excluir recursos existentes primeiro
    if ($ForcarDeploy) {
        Write-Host "ForcarDeploy ativo - removendo recursos existentes..." -ForegroundColor Yellow
        
        # Excluir recursos no namespace default
        @("hpa", "deployment", "service") | ForEach-Object {
            kubectl delete $_ --all --ignore-not-found=true 2>$null | Out-Null
        }
        
        # Excluir recursos no namespace monitoring
        kubectl delete deployment,service,configmap -n monitoring --all --ignore-not-found=true 2>$null | Out-Null
        
        # Excluir kube-state-metrics no namespace kube-system
        kubectl delete deployment,service -n kube-system -l app.kubernetes.io/name=kube-state-metrics --ignore-not-found=true 2>$null | Out-Null
        
        Write-Host "Recursos removidos - aguardando limpeza..." -ForegroundColor Yellow
        Start-Sleep -Seconds 10
    }

    # 1. Deploy dos manifestos principais da aplicação
    # O comando abaixo só pega arquivos .yaml em subpastas de "Kubernetes", mas não inclui arquivos diretamente em "Kubernetes" nem em sub-subpastas.
    # Para pegar todos os arquivos .yaml em "Kubernetes" e em todas as subpastas, use -Recurse:
    Get-ChildItem "kubernetes" -Recurse -Filter *.yaml | ForEach-Object {
        $manifest = $_.FullName
        if (Test-Path $manifest) {
            Write-Host "Aplicando $manifest..." -ForegroundColor Yellow
            kubectl apply -f $manifest | Out-Null
            Start-Sleep -Seconds 3
        }
    }

    Write-Host "Aguardando pods..." -ForegroundColor Yellow
    $timeout = 180
    $start = Get-Date
    
    while (((Get-Date) - $start).TotalSeconds -lt $timeout) {
        $backendReady = kubectl get pods -l app=patocast-backend --field-selector=status.phase=Running 2>$null
        $frontendReady = kubectl get pods -l app=patocast-frontend --field-selector=status.phase=Running 2>$null
        $postgresReady = kubectl get pods -l app=postgres --field-selector=status.phase=Running 2>$null

        if ($backendReady -and $frontendReady -and $postgresReady -and $prometheusReady) {
            Write-Host "Deploy concluido!" -ForegroundColor Green
            return
        }
        
        Start-Sleep -Seconds 10
    }
    
    Write-Host "Timeout - verificando status..." -ForegroundColor Yellow
    kubectl get pods --all-namespaces
}

# Obter endereço IP da máquina
function Get-LocalIPAddress {
    try {
        # Priorizar interfaces físicas (Ethernet, Wi-Fi) sobre virtuais
        $priorityInterfaces = @("Ethernet", "Wi-Fi", "Wireless")
        
        # Buscar por interface prioritária primeiro
        foreach ($priority in $priorityInterfaces) {
            $ipAddress = Get-NetIPAddress -AddressFamily IPv4 | Where-Object { 
                $_.InterfaceAlias -match $priority -and 
                $_.IPAddress -notmatch "^127\." -and 
                $_.IPAddress -notmatch "^169\.254\." -and
                $_.IPAddress -notmatch "^172\.(1[6-9]|2[0-9]|3[01])\." -and  # Excluir Docker/Hyper-V
                $_.IPAddress -notmatch "^100\."  # Excluir Tailscale/VPN
            } | Select-Object -First 1
            
            if ($ipAddress) {
                return $ipAddress.IPAddress
            }
        }
        
        # Se não encontrou interface prioritária, buscar qualquer IP válido de rede local
        $ipAddress = Get-NetIPAddress -AddressFamily IPv4 | Where-Object { 
            $_.IPAddress -match "^192\.168\." -or 
            $_.IPAddress -match "^10\." -or 
            ($_.IPAddress -match "^172\." -and $_.IPAddress -notmatch "^172\.(1[6-9]|2[0-9]|3[01])\.")
        } | Select-Object -First 1
        
        if ($ipAddress) {
            return $ipAddress.IPAddress
        }
        
        # Fallback: qualquer IP não-loopback, não-APIPA
        $ipAddress = Get-NetIPAddress -AddressFamily IPv4 | Where-Object { 
            $_.IPAddress -notmatch "^127\." -and 
            $_.IPAddress -notmatch "^169\.254\."
        } | Select-Object -First 1
        
        if ($ipAddress) {
            return $ipAddress.IPAddress
        }
        
        # Se tudo falhar, retornar localhost
        return "localhost"
    } catch {
        return "localhost"
    }
}

# Configurar acesso à aplicação
function Setup-ApplicationAccess {
    Get-Job | Stop-Job -ErrorAction SilentlyContinue
    Get-Job | Remove-Job -ErrorAction SilentlyContinue
    
    Write-Host "Configurando acesso..." -ForegroundColor Cyan
    
    # Obter endereço IP local
    $localIP = Get-LocalIPAddress
    Write-Host "IP Local detectado: $localIP" -ForegroundColor Gray
    
    # Verificar quais serviços existem
    $services = @()
    $services += @{ Name = "Frontend"; Service = "patocast-frontend-service"; Port = 3000 }
    $services += @{ Name = "Backend"; Service = "patocast-backend-service"; Port = 5000 }
    $services += @{ Name = "PostgreSQL"; Service = "postgres-service"; Port = 5432 }
    $services += @{ Name = "kube-state-metrics"; Service = "kube-state-metrics"; Port = 8080; Namespace = "kube-system" }
    
    # Iniciar kubectl proxy para cAdvisor (necessário para Prometheus Máquina 2)
    Write-Host "Iniciando kubectl proxy para cAdvisor..." -ForegroundColor Yellow
    Start-Job -Name "kubectl-proxy" -ScriptBlock {
        kubectl proxy --address='0.0.0.0' --accept-hosts='^.*$' --port=8001
    }
    
    foreach ($svc in $services) {
        $cmd = if ($svc.Namespace) { 
            "kubectl port-forward -n $($svc.Namespace) service/$($svc.Service) --address=0.0.0.0 $($svc.Port):$($svc.Port)" 
        } else { 
            "kubectl port-forward service/$($svc.Service) --address=0.0.0.0 $($svc.Port):$($svc.Port)" 
        }
        
        Start-Job -ScriptBlock {
            param($command)
            Invoke-Expression $command
        } -ArgumentList $cmd
    }
    
    Start-Sleep -Seconds 5
    
    Write-Host "`nURLs DISPONIVEIS:" -ForegroundColor Green
    Write-Host "kubectl proxy (cAdvisor): http://${localIP}:8001/api/v1/nodes" -ForegroundColor Cyan
    foreach ($svc in $services) {
        $protocol = if ($svc.Name -eq "PostgreSQL") { "postgresql" } else { "http" }
        Write-Host "$($svc.Name): ${protocol}://${localIP}:$($svc.Port)" -ForegroundColor Cyan
    }
}

# Mostrar status da aplicação
function Show-ApplicationStatus {
    Write-Host "`nSTATUS DA APLICACAO:" -ForegroundColor Green
    Write-Host "===================" -ForegroundColor Green
    
    # Status do namespace default
    $pods = kubectl get pods --no-headers 2>$null
    $runningPods = ($pods | Where-Object { $_ -match "Running" }).Count
    $totalPods = ($pods | Measure-Object).Count
    $hpaCount = (kubectl get hpa --no-headers 2>$null | Measure-Object).Count
    
    Write-Host "Pods (default): $runningPods/$totalPods rodando" -ForegroundColor White
    Write-Host "HPAs: $hpaCount configurados" -ForegroundColor White
    
    # Status do namespace monitoring
    $monitoringPods = kubectl get pods -n monitoring --no-headers 2>$null
    if ($monitoringPods) {
        $monitoringRunning = ($monitoringPods | Where-Object { $_ -match "Running" }).Count
        $monitoringTotal = ($monitoringPods | Measure-Object).Count
        Write-Host "Pods (monitoring): $monitoringRunning/$monitoringTotal rodando" -ForegroundColor White
    }
    
    # Status detalhado
    Write-Host "`nDETALHES:" -ForegroundColor Cyan
    kubectl get pods,hpa,svc --all-namespaces
}

Write-Host "TESTE COMPLETO PATOCASH KUBERNETES" -ForegroundColor Green
Write-Host "Parametros: LimparTudo=$LimparTudo, ForcarReconstrucao=$ForcarReconstrucao, ForcarDeploy=$ForcarDeploy" -ForegroundColor Cyan

try {
    # 1. Iniciar Docker se necessário
    Write-Host "`n1. Verificando e iniciando Docker..." -ForegroundColor Cyan
    Start-DockerService
    
    # 2. Verificar pré-requisitos
    Write-Host "`n2. Verificando pre-requisitos..." -ForegroundColor Cyan
    if (!(Test-Prerequisites)) {
        throw "Pre-requisitos nao atendidos!"
    }
    
    # 3. verificar estado
    $status = Get-EnvironmentStatus
    
    # 4. Limpar ambiente se solicitado
    Clear-Environment
    
    # 5. Configurar Minikube
    Write-Host "`n3. Configurando Minikube..." -ForegroundColor Cyan
    Start-MinikubeCluster
    
    # 6. Configurar Kubernetes
    Write-Host "`n4. Configurando Kubernetes..." -ForegroundColor Cyan
    Setup-KubernetesConfig
    
    # 7. Construir imagens sempre após limpar ambiente
    if (!$status.ImagesBuilt -or $ForcarReconstrucao -or $LimparTudo) {
        Write-Host "`n5. Construindo imagens Docker..." -ForegroundColor Cyan
        Build-DockerImages
    }
    
    # 8. Deploy sempre após limpar ambiente ou se ForcarDeploy estiver ativo
    if (!$status.AppDeployed -or $LimparTudo -or $ForcarReconstrucao -or $ForcarDeploy) {
        Write-Host "`n6. Executando deploy..." -ForegroundColor Cyan
        Deploy-Application
    }
    
    # 9. Mostrar status
    Show-ApplicationStatus
    
    # 10. Configurar acesso
    Write-Host "`n7. Configurando acesso..." -ForegroundColor Cyan
    $configurarAcesso = if ($SemPrompt) { "y" } else { Read-Host "Configurar port-forwards? (Y/n)" }
    
    if ($configurarAcesso -ne "n" -and $configurarAcesso -ne "N") {
        Setup-ApplicationAccess
        
        Write-Host "`nCOMANDOS UTEIS:" -ForegroundColor Green
        Write-Host "Status: kubectl get pods,hpa,svc --all-namespaces" -ForegroundColor Cyan
        Write-Host "Logs: kubectl logs -l app=patocast-backend" -ForegroundColor Cyan
        Write-Host "Prometheus: kubectl logs -l app=prometheus -n monitoring" -ForegroundColor Cyan
        Write-Host "Parar port-forwards: Get-Job | Stop-Job" -ForegroundColor Cyan
        Write-Host "`nPROMETHEUS MAQUINA 2:" -ForegroundColor Green
        Write-Host "UI: http://${localIP}:9090" -ForegroundColor Cyan
        Write-Host "Targets: http://${localIP}:9090/targets" -ForegroundColor Cyan
        Write-Host "Rules: http://${localIP}:9090/rules" -ForegroundColor Cyan
        Write-Host "cAdvisor Test: curl http://${localIP}:8001/api/v1/nodes/minikube/proxy/metrics/cadvisor" -ForegroundColor Cyan
        Write-Host "`nQUERIES CADVISOR (cole no Prometheus):" -ForegroundColor Green
        Write-Host "CPU Backend: sum by (pod) (rate(container_cpu_usage_seconds_total{pod=~`"patocast-backend.*`",container!=`"POD`"}[1m]))*100" -ForegroundColor Gray
        Write-Host "Memory Backend: sum by (pod) (container_memory_usage_bytes{pod=~`"patocast-backend.*`",container!=`"POD`"})/1024/1024" -ForegroundColor Gray
        Write-Host "Replicas: count(count by (pod) (container_cpu_usage_seconds_total{pod=~`"patocast-backend.*`",container!=`"POD`"}))" -ForegroundColor Gray
        
        if (!$SemPrompt) {
            Write-Host "`nManter port-forwards? (Y/n): " -NoNewline -ForegroundColor Cyan
            $manter = Read-Host
            
            if ($manter -ne "n" -and $manter -ne "N") {
                Write-Host "Port-forwards ativos. Ctrl+C para encerrar." -ForegroundColor Yellow
                try {
                    while ($true) {
                        Start-Sleep -Seconds 10
                        $jobs = Get-Job | Where-Object { $_.State -eq "Running" }
                        if ($jobs.Count -eq 0) { break }
                        Write-Host "Port-forwards: $($jobs.Count) ativos | $(Get-Date -Format 'HH:mm:ss')" -ForegroundColor Gray
                    }
                } finally {
                    Get-Job | Stop-Job -ErrorAction SilentlyContinue
                    Get-Job | Remove-Job -ErrorAction SilentlyContinue
                }
            }
        }
    }
    
    Write-Host "`nTESTE COMPLETO FINALIZADO!" -ForegroundColor Green
    Write-Host "Proximo: .\teste-resiliencia.ps1" -ForegroundColor Yellow
    
} catch {
    Write-Host "`nERRO: $_" -ForegroundColor Red
    exit 1
}