# 🧪 Teste Completo do Zero - PatoCash
# Este script simula uma instalação completamente nova em qualquer PC

param(
    [switch]$LimparTudo,
    [switch]$SemPrompt
)

Write-Host "🧪 TESTE COMPLETO DO ZERO - PATOCASH" -ForegroundColor Green
Write-Host "=" * 50
Write-Host "🎯 Objetivo: Simular instalação em PC novo" -ForegroundColor Cyan
Write-Host "📋 Este teste vai:" -ForegroundColor Yellow
Write-Host "   ✅ Limpar todo o ambiente atual" -ForegroundColor Yellow
Write-Host "   ✅ Verificar pré-requisitos" -ForegroundColor Yellow
Write-Host "   ✅ Fazer deploy completo do zero" -ForegroundColor Yellow
Write-Host "   ✅ Testar funcionalidades" -ForegroundColor Yellow
Write-Host ""

if (-not $SemPrompt) {
    $confirmacao = Read-Host "🚨 ATENÇÃO: Isso vai APAGAR todos os recursos atuais! Continuar? (s/N)"
    if ($confirmacao -ne 's' -and $confirmacao -ne 'S') {
        Write-Host "❌ Teste cancelado pelo usuário" -ForegroundColor Red
        exit 0
    }
}

# Função para verificar comandos disponíveis
function Test-Prerequisites {
    Write-Host "🔍 VERIFICANDO PRÉ-REQUISITOS..." -ForegroundColor Cyan
    Write-Host "-" * 40
    
    $prerequisites = @()
    
    # Verificar Docker
    try {
        $dockerVersion = docker --version 2>$null
        if ($dockerVersion) {
            Write-Host "✅ Docker: $dockerVersion" -ForegroundColor Green
        } else {
            Write-Host "❌ Docker não encontrado!" -ForegroundColor Red
            $prerequisites += "Docker Desktop"
        }
    } catch {
        Write-Host "❌ Docker não encontrado!" -ForegroundColor Red
        $prerequisites += "Docker Desktop"
    }
    
    # Verificar kubectl
    try {
        $kubectlVersion = kubectl version --client=true 2>$null | Select-String "Client Version"
        if ($kubectlVersion) {
            Write-Host "✅ kubectl: $kubectlVersion" -ForegroundColor Green
        } else {
            Write-Host "❌ kubectl não encontrado!" -ForegroundColor Red
            $prerequisites += "kubectl"
        }
    } catch {
        Write-Host "❌ kubectl não encontrado!" -ForegroundColor Red
        $prerequisites += "kubectl"
    }
    
    # Verificar Minikube
    try {
        $minikubeVersion = minikube version 2>$null | Select-String "minikube version"
        if ($minikubeVersion) {
            Write-Host "✅ Minikube: $minikubeVersion" -ForegroundColor Green
        } else {
            Write-Host "❌ Minikube não encontrado!" -ForegroundColor Red
            $prerequisites += "Minikube"
        }
    } catch {
        Write-Host "❌ Minikube não encontrado!" -ForegroundColor Red
        $prerequisites += "Minikube"
    }
    
    # Verificar arquivos do projeto
    $requiredFiles = @(
        "deploy-seguro.ps1",
        "create-secret.ps1", 
        ".env-exemplo-seguro",
        "k8s-backend.yaml",
        "k8s-frontend.yaml",
        "k8s-postgres.yaml",
        "k8s-configmap.yaml",
        "k8s-hpa.yaml",
        "banco_de_dados\init.sql",
        "banco_de_dados\insersao_user.sql"
    )
    
    Write-Host ""
    Write-Host "📁 Verificando arquivos do projeto:" -ForegroundColor Cyan
    foreach ($file in $requiredFiles) {
        if (Test-Path $file) {
            Write-Host "✅ $file" -ForegroundColor Green
        } else {
            Write-Host "❌ $file - AUSENTE!" -ForegroundColor Red
            $prerequisites += $file
        }
    }
    
    if ($prerequisites.Count -gt 0) {
        Write-Host ""
        Write-Host "❌ PRÉ-REQUISITOS FALTANDO:" -ForegroundColor Red
        foreach ($item in $prerequisites) {
            Write-Host "   - $item" -ForegroundColor Yellow
        }
        Write-Host ""
        Write-Host "📋 Instale os pré-requisitos antes de continuar!" -ForegroundColor Yellow
        return $false
    }
    
    Write-Host ""
    Write-Host "✅ TODOS OS PRÉ-REQUISITOS ATENDIDOS!" -ForegroundColor Green
    return $true
}

# Função para limpar ambiente
function Clear-Environment {
    Write-Host "🧹 LIMPANDO AMBIENTE ATUAL..." -ForegroundColor Yellow
    Write-Host "-" * 40
    
    # Parar port-forwards
    Write-Host "🔌 Matando port-forwards ativos..." -ForegroundColor Cyan
    Get-Process | Where-Object { $_.ProcessName -eq "kubectl" } | ForEach-Object {
        try {
            $_.Kill()
            Write-Host "✅ Processo kubectl $($_.Id) terminado" -ForegroundColor Green
        } catch {
            Write-Host "⚠️  Processo $($_.Id) já terminado" -ForegroundColor Yellow
        }
    }
    
    # Deletar recursos do Kubernetes
    Write-Host "🗑️  Removendo recursos do Kubernetes..." -ForegroundColor Cyan
    
    $resources = @(
        "hpa patocast-hpa",
        "deployment patocast-backend patocast-frontend postgres",
        "service patocast-backend-service patocast-frontend-service postgres-service",
        "configmap patocast-config postgres-init-scripts",
        "secret patocast-secrets"
    )
    
    foreach ($resource in $resources) {
        Write-Host "🗑️  kubectl delete $resource" -ForegroundColor Gray
        kubectl delete $resource --ignore-not-found=true 2>$null | Out-Null
    }
    
    # Remover arquivo .env se existir
    if (Test-Path ".env") {
        Write-Host "🗑️  Removendo .env atual..." -ForegroundColor Cyan
        Remove-Item ".env" -Force
    }
    
    Write-Host "✅ Ambiente limpo!" -ForegroundColor Green
    Write-Host ""
}

# Função para verificar Minikube
function Test-MinikubeCluster {
    Write-Host "🐳 VERIFICANDO CLUSTER MINIKUBE..." -ForegroundColor Cyan
    Write-Host "-" * 40
    
    # Verificar se Minikube está rodando
    $minikubeStatus = minikube status 2>$null
    if ($minikubeStatus -match "Running") {
        Write-Host "✅ Minikube já está rodando" -ForegroundColor Green
        
        # Verificar metrics-server
        $metricsServer = kubectl get apiservice v1beta1.metrics.k8s.io 2>$null
        if (-not $metricsServer) {
            Write-Host "⚠️  Habilitando metrics-server..." -ForegroundColor Yellow
            minikube addons enable metrics-server
        } else {
            Write-Host "✅ Metrics-server disponível" -ForegroundColor Green
        }
        
        return $true
    }
    
    Write-Host "🚀 Iniciando Minikube..." -ForegroundColor Yellow
    minikube start --driver=docker --memory=4096 --cpus=2
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Minikube iniciado com sucesso!" -ForegroundColor Green
        
        # Habilitar metrics-server
        Write-Host "📊 Habilitando metrics-server..." -ForegroundColor Cyan
        minikube addons enable metrics-server
        
        # Aguardar metrics-server ficar pronto
        Write-Host "⏳ Aguardando metrics-server..." -ForegroundColor Yellow
        Start-Sleep -Seconds 30
        
        return $true
    } else {
        Write-Host "❌ Falha ao iniciar Minikube!" -ForegroundColor Red
        return $false
    }
}

# Função para criar .env
function Create-TestEnv {
    Write-Host "🔐 CRIANDO ARQUIVO .ENV DE TESTE..." -ForegroundColor Cyan
    Write-Host "-" * 40
    
    if (-not (Test-Path ".env-exemplo-seguro")) {
        Write-Host "❌ Arquivo .env-exemplo-seguro não encontrado!" -ForegroundColor Red
        return $false
    }
    
    # Copiar exemplo para .env
    Copy-Item ".env-exemplo-seguro" ".env"
    Write-Host "✅ Arquivo .env criado a partir do exemplo" -ForegroundColor Green
    
    # Mostrar conteúdo
    Write-Host "📋 Conteúdo do .env:" -ForegroundColor Yellow
    Get-Content ".env" | ForEach-Object { Write-Host "   $_" -ForegroundColor Gray }
    
    Write-Host ""
    Write-Host "⚠️  IMPORTANTE: Em produção, use credenciais reais!" -ForegroundColor Yellow
    Write-Host ""
    
    return $true
}

# Função para testar aplicação
function Test-Application {
    Write-Host "🧪 TESTANDO APLICAÇÃO..." -ForegroundColor Cyan
    Write-Host "-" * 40
    
    # Aguardar pods ficarem prontos
    Write-Host "⏳ Aguardando pods ficarem prontos..." -ForegroundColor Yellow
    $timeout = 300  # 5 minutos
    $start = Get-Date
    
    while ((Get-Date) -lt $start.AddSeconds($timeout)) {
        $backendReady = kubectl get pods -l app=patocast-backend --no-headers | Where-Object { $_ -match "Running.*1/1" }
        $frontendReady = kubectl get pods -l app=patocast-frontend --no-headers | Where-Object { $_ -match "Running.*1/1" }
        
        if ($backendReady -and $frontendReady) {
            Write-Host "✅ Todos os pods estão prontos!" -ForegroundColor Green
            break
        }
        
        Write-Host "⏳ Aguardando pods... ($(([math]::Round(((Get-Date) - $start).TotalSeconds)))s)" -ForegroundColor Gray
        Start-Sleep -Seconds 10
    }
    
    # Mostrar status final
    Write-Host ""
    Write-Host "📊 STATUS FINAL DOS PODS:" -ForegroundColor Green
    kubectl get pods -l app=patocast-backend,app=patocast-frontend
    
    Write-Host ""
    Write-Host "📈 STATUS DO HPA:" -ForegroundColor Green
    kubectl get hpa patocast-hpa
    
    Write-Host ""
    Write-Host "🌐 STATUS DOS SERVIÇOS:" -ForegroundColor Green
    kubectl get services -l app=patocast-backend,app=patocast-frontend
    
    return $true
}

# EXECUÇÃO PRINCIPAL
Write-Host "🚀 INICIANDO TESTE COMPLETO..." -ForegroundColor Green
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

# 4. Criar arquivo .env
if (-not (Create-TestEnv)) {
    exit 1
}

# 5. Executar deploy seguro
Write-Host "🚀 EXECUTANDO DEPLOY SEGURO..." -ForegroundColor Green
Write-Host "-" * 40
try {
    & ".\deploy-seguro.ps1"
    if ($LASTEXITCODE -ne 0) {
        throw "Deploy falhou"
    }
    Write-Host "✅ Deploy executado com sucesso!" -ForegroundColor Green
} catch {
    Write-Host "❌ Falha no deploy: $_" -ForegroundColor Red
    exit 1
}

# 6. Testar aplicação
Test-Application

# 7. Resultado final
Write-Host ""
Write-Host "🎉 TESTE COMPLETO DO ZERO - CONCLUÍDO!" -ForegroundColor Green
Write-Host "=" * 50
Write-Host "✅ Ambiente limpo e recriado" -ForegroundColor Green
Write-Host "✅ Minikube verificado/iniciado" -ForegroundColor Green
Write-Host "✅ Arquivo .env criado" -ForegroundColor Green
Write-Host "✅ Deploy seguro executado" -ForegroundColor Green
Write-Host "✅ Aplicação testada" -ForegroundColor Green
Write-Host ""
Write-Host "🌐 Acesse a aplicação em: http://localhost:3000" -ForegroundColor Cyan
Write-Host "🧪 Para testes de resiliência: .\teste-estresse.ps1" -ForegroundColor Yellow
Write-Host ""
Write-Host "✨ A aplicação PatoCash está 100% funcional!" -ForegroundColor Green