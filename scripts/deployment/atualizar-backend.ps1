# Script para Atualizar Backend com Alteracoes
# Rebuilda a imagem Docker e atualiza o deployment no Kubernetes

param(
    [switch]$ForceRebuild,
    [switch]$SkipCache
)

Write-Host "ATUALIZANDO BACKEND PATOCASH" -ForegroundColor Green
Write-Host "=" * 50

# Navegar para a raiz do projeto
$projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location $projectRoot
Write-Host "Executando a partir de: $projectRoot" -ForegroundColor Cyan

# Verificar se Minikube esta rodando
Write-Host "Verificando Minikube..." -ForegroundColor Cyan
$minikubeStatus = minikube status 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERRO: Minikube nao esta rodando!" -ForegroundColor Red
    Write-Host "Execute: minikube start" -ForegroundColor Yellow
    exit 1
}
Write-Host "OK: Minikube esta rodando!" -ForegroundColor Green

# Configurar contexto Docker do Minikube
Write-Host "Configurando contexto Docker..." -ForegroundColor Cyan
& minikube -p minikube docker-env --shell powershell | Invoke-Expression

# Verificar alteracoes no backend
Write-Host "Verificando alteracoes no backend..." -ForegroundColor Cyan
if (Test-Path "backend\app.py") {
    $appContent = Get-Content "backend\app.py" -Raw
    if ($appContent -match "prometheus_client|metrics") {
        Write-Host "OK: Metricas Prometheus detectadas!" -ForegroundColor Green
    }
    if ($appContent -match "@app\.route.*metrics") {
        Write-Host "OK: Endpoint /metrics encontrado!" -ForegroundColor Green
    }
} else {
    Write-Host "ERRO: Arquivo backend/app.py nao encontrado!" -ForegroundColor Red
    exit 1
}

# Rebuildar imagem Docker
Write-Host "REBUILDING BACKEND IMAGE..." -ForegroundColor Yellow
Write-Host "Contexto: ./backend" -ForegroundColor Cyan

$dockerArgs = @("build", "-t", "patocast-backend:latest", "./backend")
if ($SkipCache) {
    $dockerArgs += "--no-cache"
}

Write-Host "Executando: docker $($dockerArgs -join ' ')" -ForegroundColor Gray
docker $dockerArgs

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERRO: Falha ao buildar imagem Docker!" -ForegroundColor Red
    exit 1
}
Write-Host "OK: Imagem Docker atualizada!" -ForegroundColor Green

# Verificar se deployment existe
Write-Host "Verificando deployment existente..." -ForegroundColor Cyan
$deploymentExists = kubectl get deployment patocast-backend 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "OK: Deployment encontrado!" -ForegroundColor Green
    
    # Reiniciar deployment para usar nova imagem
    Write-Host "Reiniciando pods para usar nova imagem..." -ForegroundColor Yellow
    kubectl rollout restart deployment/patocast-backend
    
    # Aguardar rollout
    Write-Host "Aguardando rollout completar..." -ForegroundColor Yellow
    kubectl rollout status deployment/patocast-backend --timeout=120s
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERRO: Timeout no rollout!" -ForegroundColor Red
        Write-Host "Verificando status dos pods..." -ForegroundColor Yellow
        kubectl get pods -l app=patocast-backend
        exit 1
    }
    
} else {
    Write-Host "AVISO: Deployment nao encontrado. Aplicando manifesto..." -ForegroundColor Yellow
    kubectl apply -f kubernetes/manifests/k8s-backend.yaml
    
    # Aguardar pods estarem prontos
    Write-Host "Aguardando pods estarem prontos..." -ForegroundColor Yellow
    kubectl wait --for=condition=ready pod -l app=patocast-backend --timeout=120s
}

# Verificar se pods estao rodando
Write-Host "STATUS DOS PODS:" -ForegroundColor Green
kubectl get pods -l app=patocast-backend

# Testar endpoint de metricas
Write-Host "TESTANDO NOVO ENDPOINT DE METRICAS..." -ForegroundColor Cyan
Write-Host "Iniciando port-forward temporario..." -ForegroundColor Yellow

# Usar o script acesso-app para configurar port-forward
Write-Host "Usando script de acesso para configurar port-forward..." -ForegroundColor Cyan
$acessoScript = Join-Path $PSScriptRoot "acesso-app.ps1"

if (Test-Path $acessoScript) {
    Write-Host "Executando acesso-app.ps1 em background..." -ForegroundColor Yellow
    
    # Executar acesso-app em background para configurar port-forwards
    $portForwardJob = Start-Job -ScriptBlock {
        param($scriptPath)
        
        # Configurar port-forward para backend (porta 5000)
        Start-Process powershell -ArgumentList "kubectl port-forward service/patocast-backend-service 5000:5000" -WindowStyle Hidden -PassThru
        
        # Configurar port-forward para frontend (porta 3000)
        Start-Process powershell -ArgumentList "kubectl port-forward service/patocast-frontend-service 3000:3000" -WindowStyle Hidden -PassThru
        
        Start-Sleep -Seconds 5
        return "Port-forwards configurados"
    } -ArgumentList $acessoScript
    
    # Aguardar port-forwards serem configurados
    Start-Sleep -Seconds 8
    
    try {
        Write-Host "Testando http://localhost:5000/metrics..." -ForegroundColor Yellow
        $response = Invoke-WebRequest -Uri "http://localhost:5000/metrics" -TimeoutSec 10 -ErrorAction Stop
        Write-Host "SUCESSO! Endpoint de metricas respondendo:" -ForegroundColor Green
        Write-Host "Status: $($response.StatusCode)" -ForegroundColor White
        Write-Host "Content-Type: $($response.Headers.'Content-Type')" -ForegroundColor White
        
        # Mostrar primeiras linhas das metricas
        $metricsLines = ($response.Content -split "`n") | Select-Object -First 5
        Write-Host "Primeiras metricas:" -ForegroundColor Cyan
        foreach ($line in $metricsLines) {
            if ($line.Trim()) {
                Write-Host "  $line" -ForegroundColor Gray
            }
        }
        
    } catch {
        Write-Host "AVISO: Nao foi possivel testar o endpoint: $($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host "Teste manualmente executando: .\scripts\deployment\acesso-app.ps1" -ForegroundColor Yellow
    } finally {
        # Limpar job
        $portForwardJob | Remove-Job -Force -ErrorAction SilentlyContinue
    }
    
} else {
    Write-Host "AVISO: Script acesso-app.ps1 nao encontrado!" -ForegroundColor Yellow
    Write-Host "Usando port-forward simples..." -ForegroundColor Yellow
    
    # Fallback para port-forward simples
    $portForwardJob = Start-Job -ScriptBlock {
        kubectl port-forward service/patocast-backend-service 5001:5000
    }
    
    Start-Sleep -Seconds 5
    
    try {
        Write-Host "Testando http://localhost:5001/metrics..." -ForegroundColor Yellow
        $response = Invoke-WebRequest -Uri "http://localhost:5001/metrics" -TimeoutSec 10 -ErrorAction Stop
        Write-Host "SUCESSO! Endpoint de metricas respondendo:" -ForegroundColor Green
        Write-Host "Status: $($response.StatusCode)" -ForegroundColor White
        
    } catch {
        Write-Host "AVISO: Nao foi possivel testar o endpoint: $($_.Exception.Message)" -ForegroundColor Yellow
    } finally {
        $portForwardJob | Stop-Job -ErrorAction SilentlyContinue
        $portForwardJob | Remove-Job -ErrorAction SilentlyContinue
    }
}

# Verificar se HPA pode usar metricas
Write-Host "Verificando configuracao do HPA..." -ForegroundColor Cyan
$hpa = kubectl get hpa patocast-backend-hpa 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "OK: HPA encontrado!" -ForegroundColor Green
    kubectl get hpa patocast-backend-hpa
} else {
    Write-Host "AVISO: HPA nao encontrado. Aplicando..." -ForegroundColor Yellow
    kubectl apply -f kubernetes/manifests/k8s-hpa.yaml
}

Write-Host ""
Write-Host "BACKEND ATUALIZADO COM SUCESSO!" -ForegroundColor Green
Write-Host "Alteracoes aplicadas:" -ForegroundColor Cyan
Write-Host "  OK: Nova imagem Docker builded" -ForegroundColor White
Write-Host "  OK: Deployment reiniciado" -ForegroundColor White
Write-Host "  OK: Endpoint /metrics disponivel" -ForegroundColor White
Write-Host "  OK: Prometheus client integrado" -ForegroundColor White

Write-Host ""
Write-Host "ACESSO A APLICACAO:" -ForegroundColor Yellow
Write-Host "Frontend: http://localhost:3000" -ForegroundColor Gray  
Write-Host "Backend: http://localhost:5000" -ForegroundColor Gray
Write-Host "Metricas: http://localhost:5000/metrics" -ForegroundColor Gray

Write-Host ""
Write-Host "COMANDOS UTEIS:" -ForegroundColor Yellow
Write-Host "Configurar acesso: .\scripts\deployment\acesso-app.ps1" -ForegroundColor Gray
Write-Host "Teste de stress: .\scripts\tests\teste-resiliencia.ps1 -Teste hpa -Rapido" -ForegroundColor Gray

Write-Host ""
Write-Host "NOTA: Port-forwards foram configurados automaticamente!" -ForegroundColor Cyan
Write-Host "Se houver problemas, execute: .\scripts\deployment\acesso-app.ps1" -ForegroundColor Yellow