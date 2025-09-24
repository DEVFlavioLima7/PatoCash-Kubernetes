# Teste Completo Simplificado - PatoCash Kubernetes

param(
    [switch]$LimparTudo,
    [switch]$SemPrompt,
    [switch]$ForcarReconstrucao
)

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
    
    # Verificar se Prometheus está deployado
    $prometheusDeployed = kubectl get deployment prometheus -n monitoring 2>$null
    
    $imagesBuilt = $false
    if ($minikubeRunning) {
        minikube docker-env --shell powershell | Invoke-Expression 2>$null
        $imagesBuilt = (docker images patocast-backend:latest -q 2>$null) -and (docker images patocast-frontend:latest -q 2>$null)
    }
    
    Write-Host "Status: Minikube=$minikubeRunning | App=$appDeployed | Images=$imagesBuilt | Prometheus=$([bool]$prometheusDeployed)" -ForegroundColor Cyan
    
    return @{
        MinikubeRunning = $minikubeRunning
        AppDeployed = $appDeployed
        ImagesBuilt = $imagesBuilt
        PrometheusDeployed = [bool]$prometheusDeployed
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

    Get-ChildItem "Kubernetes\*\*.yaml" | ForEach-Object {
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
        $prometheusReady = kubectl get pods -n monitoring -l app=prometheus --field-selector=status.phase=Running 2>$null

        if ($backendReady -and $frontendReady -and $postgresReady -and $prometheusReady) {
            Write-Host "Deploy concluido!" -ForegroundColor Green
            return
        }
        
        Start-Sleep -Seconds 10
    }
    
    Write-Host "Timeout - verificando status..." -ForegroundColor Yellow
    kubectl get pods --all-namespaces
}

# Configurar acesso à aplicação
function Setup-ApplicationAccess {
    Get-Job | Stop-Job -ErrorAction SilentlyContinue
    Get-Job | Remove-Job -ErrorAction SilentlyContinue
    
    Write-Host "Configurando acesso..." -ForegroundColor Cyan
    
    # Verificar quais serviços existem
    $services = @()
    $services += @{ Name = "Frontend"; Service = "patocast-frontend-service"; Port = 3000 }
    $services += @{ Name = "Backend"; Service = "patocast-backend-service"; Port = 5000 }
    $services += @{ Name = "PostgreSQL"; Service = "postgres-service"; Port = 5432 }
    $services += @{ Name = "Prometheus"; Service = "prometheus-service"; Port = 9090; Namespace = "monitoring" }
    
    foreach ($svc in $services) {
        $cmd = if ($svc.Namespace) { 
            "kubectl port-forward -n $($svc.Namespace) service/$($svc.Service) $($svc.Port):$($svc.Port)" 
        } else { 
            "kubectl port-forward service/$($svc.Service) $($svc.Port):$($svc.Port)" 
        }
        
        Start-Job -ScriptBlock {
            param($command)
            Invoke-Expression $command
        } -ArgumentList $cmd
    }
    
    Start-Sleep -Seconds 5
    
    Write-Host "`nURLs DISPONIVEIS:" -ForegroundColor Green
    foreach ($svc in $services) {
        $protocol = if ($svc.Name -eq "PostgreSQL") { "postgresql" } else { "http" }
        Write-Host "$($svc.Name): ${protocol}://localhost:$($svc.Port)" -ForegroundColor Cyan
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
Write-Host "Parametros: LimparTudo=$LimparTudo, ForcarReconstrucao=$ForcarReconstrucao" -ForegroundColor Cyan

try {
    # 1. Verificar pré-requisitos
    Write-Host "`n1. Verificando pre-requisitos..." -ForegroundColor Cyan
    if (!(Test-Prerequisites)) {
        throw "Pre-requisitos nao atendidos!"
    }
    
    # 2. verificar estado
    $status = Get-EnvironmentStatus
    
    # 3. Limpar ambiente se solicitado
    Clear-Environment
    
    # 4. Configurar Minikube
    Write-Host "`n2. Configurando Minikube..." -ForegroundColor Cyan
    Start-MinikubeCluster
    
    # 5. Configurar Kubernetes
    Write-Host "`n3. Configurando Kubernetes..." -ForegroundColor Cyan
    Setup-KubernetesConfig
    
    # 6. Construir imagens sempre após limpar ambiente
    if (!$status.ImagesBuilt -or $ForcarReconstrucao -or $LimparTudo) {
        Write-Host "`n4. Construindo imagens Docker..." -ForegroundColor Cyan
        Build-DockerImages
    }
    
    # 7. Deploy sempre após limpar ambiente
    if (!$status.AppDeployed -or !$status.PrometheusDeployed -or $LimparTudo -or $ForcarReconstrucao) {
        Write-Host "`n5. Executando deploy..." -ForegroundColor Cyan
        Deploy-Application
    }
    
    # 8. Mostrar status
    Show-ApplicationStatus
    
    # 9. Configurar acesso
    Write-Host "`n6. Configurando acesso..." -ForegroundColor Cyan
    $configurarAcesso = if ($SemPrompt) { "y" } else { Read-Host "Configurar port-forwards? (Y/n)" }
    
    if ($configurarAcesso -ne "n" -and $configurarAcesso -ne "N") {
        Setup-ApplicationAccess
        
        Write-Host "`nCOMANDOS UTEIS:" -ForegroundColor Green
        Write-Host "Status: kubectl get pods,hpa,svc --all-namespaces" -ForegroundColor Cyan
        Write-Host "Logs: kubectl logs -l app=patocast-backend" -ForegroundColor Cyan
        Write-Host "Prometheus: kubectl logs -l app=prometheus -n monitoring" -ForegroundColor Cyan
        Write-Host "Parar port-forwards: Get-Job | Stop-Job" -ForegroundColor Cyan
        
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