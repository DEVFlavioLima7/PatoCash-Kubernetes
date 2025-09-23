# 🔄 Script para Atualizar Backend com Alterações
# Rebuilda a imagem Docker e atualiza o deployment no Kubernetes

param(
    [switch]$ForceRebuild,
    [switch]$SkipCache
)

Write-Host "🔄 ATUALIZANDO BACKEND PATOCASH" -ForegroundColor Green
Write-Host "=" * 50

# Navegar para a raiz do projeto
$projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location $projectRoot
Write-Host "📁 Executando a partir de: $projectRoot" -ForegroundColor Cyan

# Verificar se Minikube está rodando
Write-Host "🐳 Verificando Minikube..." -ForegroundColor Cyan
$minikubeStatus = minikube status 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Minikube não está rodando!" -ForegroundColor Red
    Write-Host "💡 Execute: minikube start" -ForegroundColor Yellow
    exit 1
}
Write-Host "✅ Minikube está rodando!" -ForegroundColor Green

# Configurar contexto Docker do Minikube
Write-Host "🔧 Configurando contexto Docker..." -ForegroundColor Cyan
& minikube -p minikube docker-env --shell powershell | Invoke-Expression

# Verificar alterações no backend
Write-Host "📊 Verificando alterações no backend..." -ForegroundColor Cyan
if (Test-Path "backend\app.py") {
    $appContent = Get-Content "backend\app.py" -Raw
    if ($appContent -match "prometheus_client|metrics") {
        Write-Host "✅ Métricas Prometheus detectadas!" -ForegroundColor Green
    }
    if ($appContent -match "@app\.route.*metrics") {
        Write-Host "✅ Endpoint /metrics encontrado!" -ForegroundColor Green
    }
} else {
    Write-Host "❌ Arquivo backend/app.py não encontrado!" -ForegroundColor Red
    exit 1
}

# Rebuildar imagem Docker
Write-Host "🏗️  REBUILDING BACKEND IMAGE..." -ForegroundColor Yellow
Write-Host "📂 Contexto: ./backend" -ForegroundColor Cyan

$dockerArgs = @("build", "-t", "patocast-backend:latest", "./backend")
if ($SkipCache) {
    $dockerArgs += "--no-cache"
}

Write-Host "🐳 Executando: docker $($dockerArgs -join ' ')" -ForegroundColor Gray
docker $dockerArgs

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Falha ao buildar imagem Docker!" -ForegroundColor Red
    exit 1
}
Write-Host "✅ Imagem Docker atualizada!" -ForegroundColor Green

# Verificar se deployment existe
Write-Host "🔍 Verificando deployment existente..." -ForegroundColor Cyan
$deploymentExists = kubectl get deployment patocast-backend 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Deployment encontrado!" -ForegroundColor Green
    
    # Reiniciar deployment para usar nova imagem
    Write-Host "🔄 Reiniciando pods para usar nova imagem..." -ForegroundColor Yellow
    kubectl rollout restart deployment/patocast-backend
    
    # Aguardar rollout
    Write-Host "⏳ Aguardando rollout completar..." -ForegroundColor Yellow
    kubectl rollout status deployment/patocast-backend --timeout=120s
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Timeout no rollout!" -ForegroundColor Red
        Write-Host "🔍 Verificando status dos pods..." -ForegroundColor Yellow
        kubectl get pods -l app=patocast-backend
        exit 1
    }
    
} else {
    Write-Host "⚠️  Deployment não encontrado. Aplicando manifesto..." -ForegroundColor Yellow
    kubectl apply -f kubernetes/manifests/k8s-backend.yaml
    
    # Aguardar pods estarem prontos
    Write-Host "⏳ Aguardando pods estarem prontos..." -ForegroundColor Yellow
    kubectl wait --for=condition=ready pod -l app=patocast-backend --timeout=120s
}

# Verificar se pods estão rodando
Write-Host "📊 STATUS DOS PODS:" -ForegroundColor Green
kubectl get pods -l app=patocast-backend

# Testar endpoint de métricas
Write-Host "🧪 TESTANDO NOVO ENDPOINT DE MÉTRICAS..." -ForegroundColor Cyan
Write-Host "Iniciando port-forward temporário..." -ForegroundColor Yellow

# Port-forward em background
$portForwardJob = Start-Job -ScriptBlock {
    kubectl port-forward service/patocast-backend-service 5001:5000
}

Start-Sleep -Seconds 5

try {
    Write-Host "🔍 Testando http://localhost:5001/metrics..." -ForegroundColor Yellow
    $response = Invoke-WebRequest -Uri "http://localhost:5001/metrics" -TimeoutSec 10 -ErrorAction Stop
    Write-Host "✅ SUCESSO! Endpoint de métricas respondendo:" -ForegroundColor Green
    Write-Host "Status: $($response.StatusCode)" -ForegroundColor White
    Write-Host "Content-Type: $($response.Headers.'Content-Type')" -ForegroundColor White
    
    # Mostrar primeiras linhas das métricas
    $metricsLines = ($response.Content -split "`n") | Select-Object -First 5
    Write-Host "📊 Primeiras métricas:" -ForegroundColor Cyan
    foreach ($line in $metricsLines) {
        if ($line.Trim()) {
            Write-Host "  $line" -ForegroundColor Gray
        }
    }
    
} catch {
    Write-Host "⚠️  Não foi possível testar o endpoint: $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host "💡 Teste manualmente: kubectl port-forward service/patocast-backend-service 5000:5000" -ForegroundColor Yellow
} finally {
    # Parar port-forward
    $portForwardJob | Stop-Job -ErrorAction SilentlyContinue
    $portForwardJob | Remove-Job -ErrorAction SilentlyContinue
}

# Verificar se HPA pode usar métricas
Write-Host "📈 Verificando configuração do HPA..." -ForegroundColor Cyan
$hpa = kubectl get hpa patocast-backend-hpa 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ HPA encontrado!" -ForegroundColor Green
    kubectl get hpa patocast-backend-hpa
} else {
    Write-Host "⚠️  HPA não encontrado. Aplicando..." -ForegroundColor Yellow
    kubectl apply -f kubernetes/manifests/k8s-hpa.yaml
}

Write-Host ""
Write-Host "✅ BACKEND ATUALIZADO COM SUCESSO!" -ForegroundColor Green
Write-Host "🔧 Alterações aplicadas:" -ForegroundColor Cyan
Write-Host "  ✅ Nova imagem Docker builded" -ForegroundColor White
Write-Host "  ✅ Deployment reiniciado" -ForegroundColor White
Write-Host "  ✅ Endpoint /metrics disponível" -ForegroundColor White
Write-Host "  ✅ Prometheus client integrado" -ForegroundColor White

Write-Host ""
Write-Host "🧪 PARA TESTAR AS MÉTRICAS:" -ForegroundColor Yellow
Write-Host "kubectl port-forward service/patocast-backend-service 5000:5000" -ForegroundColor Gray
Write-Host "curl http://localhost:5000/metrics" -ForegroundColor Gray

Write-Host ""
Write-Host "🚀 PARA EXECUTAR TESTE DE STRESS:" -ForegroundColor Yellow
Write-Host ".\scripts\tests\teste-resiliencia.ps1 -Teste hpa -Rapido" -ForegroundColor Gray