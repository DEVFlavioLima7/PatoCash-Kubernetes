# Teste Completo do Zero - PatoCash Kubernetes
# Este script faz limpeza COMPLETA e instalação do zero em qualquer PC

param(
    [switch]$LimparTudo,
    [switch]$SemPrompt
)

# Função para verificar comandos disponíveis
function Test-Prerequisites {
    $prerequisites = @()
    
    try {
        $dockerVersion = docker --version 2>$null
        if ($dockerVersion) {
            Write-Host "✅ Docker: $dockerVersion" -ForegroundColor Green
        }
        else {
            Write-Host "❌ Docker não encontrado!" -ForegroundColor Red
            $prerequisites += "Docker Desktop"
        }
    }
    catch {
        Write-Host "❌ Docker não encontrado!" -ForegroundColor Red
        $prerequisites += "Docker Desktop"
    }
    
    try {
        $kubectlVersion = kubectl version --client=true 2>$null | Select-String "Client Version"
        if ($kubectlVersion) {
            Write-Host "✅ kubectl: $kubectlVersion" -ForegroundColor Green
        }
        else {
            Write-Host "❌ kubectl não encontrado!" -ForegroundColor Red
            $prerequisites += "kubectl"
        }
    }
    catch {
        Write-Host "❌ kubectl não encontrado!" -ForegroundColor Red
        $prerequisites += "kubectl"
    }
    
    try {
        $minikubeVersion = minikube version 2>$null | Select-String "minikube version"
        if ($minikubeVersion) {
            Write-Host "✅ Minikube: $minikubeVersion" -ForegroundColor Green
        }
        else {
            Write-Host "❌ Minikube não encontrado!" -ForegroundColor Red
            $prerequisites += "Minikube"
        }
    }
    catch {
        Write-Host "❌ Minikube não encontrado!" -ForegroundColor Red
        $prerequisites += "Minikube"
    }
    
    if ($prerequisites.Count -gt 0) {
        Write-Host "PRÉ-REQUISITOS FALTANDO:" -ForegroundColor Red
        foreach ($item in $prerequisites) {
            Write-Host "   - $item" -ForegroundColor Yellow
        }
        Write-Host "Instale os pré-requisitos antes de continuar!" -ForegroundColor Yellow
        return $false
    }
    
    Write-Host ""
    Write-Host "TODOS OS PRÉ-REQUISITOS ATENDIDOS!" -ForegroundColor Green
    return $true
}

function Clear-Environment {
    Write-Host "Matando TODOS os port-forwards e processos kubectl..." -ForegroundColor Cyan
    Get-Process | Where-Object { 
        $_.ProcessName -eq "kubectl" -or 
        $_.ProcessName -eq "minikube" -or
        $_.MainWindowTitle -like "*port-forward*"
    } | ForEach-Object {
        try {
            $_.Kill()
            Write-Host "Processo $($_.ProcessName) $($_.Id) terminado" -ForegroundColor Green
        }
        catch {
            Write-Host "Processo $($_.Id) já terminado" -ForegroundColor Yellow
        }
    }
    
    $resourceTypes = @(
        "hpa",
        "deployment", 
        "service",
        "configmap",
        "secret",
        "pod",
        "replicaset"
    )
    
    foreach ($type in $resourceTypes) {
        Write-Host "Removendo todos os $type..." -ForegroundColor Gray
        kubectl delete $type --all --ignore-not-found=true 2>$null | Out-Null
    }
    minikube delete 2>$null | Out-Null
}

function Test-MinikubeCluster {
    $minikubeStatus = minikube status 2>$null
    if ($minikubeStatus -match "Running") {
        Write-Host "Minikube já está rodando" -ForegroundColor Green
        $metricsServer = kubectl get apiservice v1beta1.metrics.k8s.io 2>$null
        if (-not $metricsServer) {
            Write-Host "Habilitando metrics-server..." -ForegroundColor Yellow
            minikube addons enable metrics-server
        }
        else {
            Write-Host "Metrics-server disponível" -ForegroundColor Green
        }
        
        return $true
    }
    
    Write-Host "Iniciando Minikube..." -ForegroundColor Yellow
    minikube start --driver=docker
    Write-Host "Minikube iniciado" -ForegroundColor Green
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Habilitando metrics-server..." -ForegroundColor Cyan
        minikube addons enable metrics-server
        Write-Host "Aguardando metrics-server..." -ForegroundColor Yellow
        Start-Sleep -Seconds 30
        return $true
    }
    else {
        Write-Host "Falha ao iniciar Minikube!" -ForegroundColor Red
        return $false
    }
}

# Função para construir imagens Docker
function Build-DockerImages {
    
    Write-Host "Configurando Docker para usar daemon do Minikube..." -ForegroundColor Yellow
    try {
        minikube -p minikube docker-env --shell powershell | Invoke-Expression
        Write-Host "Docker configurado para Minikube" -ForegroundColor Green
    }
    catch {
        Write-Host "Falha ao configurar Docker: $_" -ForegroundColor Red
        return $false
    }
    
    
    Write-Host "Baixando imagem base do PostgreSQL..." -ForegroundColor Yellow
    try {
        docker pull postgres:16-alpine
        if ($LASTEXITCODE -ne 0) {
            throw "Falha ao baixar postgres:16-alpine"
        }
        Write-Host "Imagem PostgreSQL baixada: postgres:16-alpine" -ForegroundColor Green
    }
    catch {
        Write-Host "Falha ao baixar PostgreSQL: $_" -ForegroundColor Red
        return $false
    }
    
    Write-Host "Construindo imagem do backend..." -ForegroundColor Yellow
    try {
        docker build -t patocast-backend:latest .\backend
        if ($LASTEXITCODE -ne 0) {
            throw "Build do backend falhou"
        }
        Write-Host "Imagem do backend construída: patocast-backend:latest" -ForegroundColor Green
    }
    catch {
        Write-Host "Falha na construção do backend: $_" -ForegroundColor Red
        return $false
    }
    
    Write-Host "Construindo imagem do frontend..." -ForegroundColor Yellow
    try {
        docker build -t patocast-frontend:latest .\front
        if ($LASTEXITCODE -ne 0) {
            throw "Build do frontend falhou"
        }
        Write-Host "Imagem do frontend construída: patocast-frontend:latest" -ForegroundColor Green
    }
    catch {
        Write-Host "Falha na construção do frontend: $_" -ForegroundColor Red
        return $false
    }
    
    Write-Host "TODAS AS IMAGENS PRONTAS PARA USO!" -ForegroundColor Green
    Write-Host "Imagens estão disponíveis no daemon do Minikube" -ForegroundColor Cyan
    return $true
}

function Test-Application {
    Write-Host "STATUS FINAL DOS PODS:" -ForegroundColor Green
    kubectl get all
    return $true
}

# EXECUÇÃO PRINCIPAL
Write-Host "INICIANDO TESTE COMPLETO..." -ForegroundColor Green
Write-Host ""

# 1. Verificar pré-requisitos
if (-not (Test-Prerequisites)) {
    exit 1
}

# 2. Limpar ambiente
Clear-Environment

# 3. Verificar/iniciar Minikube
if (-not (Test-MinikubeCluster)) {
    exit 1
}

# 4. Verificar arquivo .env existente
if (-not (Test-Path ".env")) {
    Write-Host "❌ Arquivo .env não encontrado na raiz!" -ForegroundColor Red
    Write-Host "Certifique-se de que o arquivo .env existe e está configurado" -ForegroundColor Yellow
    exit 1
}
Write-Host "Arquivo .env encontrado" -ForegroundColor Green

if (-not (Build-DockerImages)) {
    exit 1
}

Write-Host "EXECUTANDO DEPLOY SEGURO..." -ForegroundColor Green
Write-Host "-" * 40
try {
    & ".\scripts\deployment\deploy-seguro.ps1"
    if ($LASTEXITCODE -ne 0) {
        throw "Deploy falhou"
    }
    Write-Host "Deploy executado com sucesso!" -ForegroundColor Green
}
catch {
    Write-Host "Falha no deploy: $_" -ForegroundColor Red
    exit 1
}

Test-Application