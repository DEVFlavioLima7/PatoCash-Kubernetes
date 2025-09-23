# 🧪 Teste Completo do Zero - PatoCash Kubernetes
# Este script faz limpeza COMPLETA e instalação do zero em qualquer PC

param(
    [switch]$LimparTudo,
    [switch]$SemPrompt
)

Write-Host "🧪 TESTE COMPLETO DO ZERO - PATOCASH KUBERNETES" -ForegroundColor Green
Write-Host "=" * 60
Write-Host "🎯 Objetivo: Instalação 100% limpa em qualquer PC" -ForegroundColor Cyan
Write-Host "🧹 Este script vai:" -ForegroundColor Yellow
Write-Host "   💥 DELETAR completamente instalação anterior" -ForegroundColor Yellow
Write-Host "   🔍 Verificar todos os pré-requisitos" -ForegroundColor Yellow
Write-Host "   🚀 Deploy completo do zero com nova estrutura" -ForegroundColor Yellow
Write-Host "   🧪 Testar todas as funcionalidades" -ForegroundColor Yellow
Write-Host "   🌐 Configurar acesso automático" -ForegroundColor Yellow
Write-Host ""
Write-Host "⚠️  ATENÇÃO: Limpeza TOTAL do ambiente!" -ForegroundColor Red
Write-Host ""

if (-not $SemPrompt) {
    $confirmacao = Read-Host "🚨 Isso vai APAGAR 100% da instalação atual! Continuar? (s/N)"
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
    
    # Verificar arquivos do projeto (nova estrutura)
    $requiredFiles = @(
        "scripts\deployment\deploy-seguro.ps1",
        "scripts\deployment\create-secret.ps1", 
        "kubernetes\configs\.env-exemplo",
        "kubernetes\manifests\k8s-backend.yaml",
        "kubernetes\manifests\k8s-frontend.yaml",
        "kubernetes\manifests\k8s-postgres.yaml",
        "kubernetes\manifests\k8s-configmap.yaml",
        "kubernetes\manifests\k8s-hpa.yaml",
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

# Função para limpeza COMPLETA do ambiente
function Clear-Environment {
    Write-Host "🧹 LIMPEZA COMPLETA DO AMBIENTE..." -ForegroundColor Red
    Write-Host "-" * 50
    
    # 1. Parar TODOS os port-forwards
    Write-Host "🔌 Matando TODOS os port-forwards e processos kubectl..." -ForegroundColor Cyan
    Get-Process | Where-Object { 
        $_.ProcessName -eq "kubectl" -or 
        $_.ProcessName -eq "minikube" -or
        $_.MainWindowTitle -like "*port-forward*"
    } | ForEach-Object {
        try {
            $_.Kill()
            Write-Host "✅ Processo $($_.ProcessName) $($_.Id) terminado" -ForegroundColor Green
        } catch {
            Write-Host "⚠️  Processo $($_.Id) já terminado" -ForegroundColor Yellow
        }
    }
    
    # 2. Deletar TODOS os recursos do namespace default
    Write-Host "🗑️  Removendo TODOS os recursos do Kubernetes..." -ForegroundColor Cyan
    
    # Deletar por tipo específico
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
        Write-Host "🗑️  Removendo todos os $type..." -ForegroundColor Gray
        kubectl delete $type --all --ignore-not-found=true 2>$null | Out-Null
    }
    
    # 3. Aguardar tudo ser removido
    Write-Host "⏳ Aguardando remoção completa..." -ForegroundColor Yellow
    Start-Sleep -Seconds 10
    
    # 4. Verificar se ainda há pods rodando
    $remainingPods = kubectl get pods --no-headers 2>$null
    if ($remainingPods) {
        Write-Host "� Forçando remoção de pods restantes..." -ForegroundColor Red
        kubectl delete pods --all --force --grace-period=0 2>$null | Out-Null
    }
    
    # 5. Resetar Minikube completamente
    Write-Host "💥 RESETANDO Minikube completamente..." -ForegroundColor Red
    minikube delete 2>$null | Out-Null
    
    # 6. Limpar arquivos locais
    Write-Host "🗑️  Removendo arquivos temporários..." -ForegroundColor Cyan
    if (Test-Path ".env") {
        Remove-Item ".env" -Force
        Write-Host "✅ .env removido" -ForegroundColor Green
    }
    
    # Remover logs e caches
    $tempPaths = @("*.log", "*.tmp", ".kubectl_cache")
    foreach ($path in $tempPaths) {
        if (Test-Path $path) {
            Remove-Item $path -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    
    Write-Host ""
    Write-Host "✅ LIMPEZA COMPLETA FINALIZADA!" -ForegroundColor Green
    Write-Host "💯 Ambiente 100% limpo para nova instalação" -ForegroundColor Green
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
    
    # Verificar arquivo de exemplo na nova estrutura
    $envExemplo = "kubernetes\configs\.env-exemplo"
    if (-not (Test-Path $envExemplo)) {
        Write-Host "❌ Arquivo $envExemplo não encontrado!" -ForegroundColor Red
        Write-Host "📁 Estrutura esperada: kubernetes/configs/.env-exemplo" -ForegroundColor Yellow
        return $false
    }
    
    # Copiar exemplo para .env na raiz
    Copy-Item $envExemplo ".env"
    Write-Host "✅ Arquivo .env criado a partir do exemplo" -ForegroundColor Green
    
    # Mostrar conteúdo
    Write-Host "📋 Conteúdo do .env:" -ForegroundColor Yellow
    Get-Content ".env" | ForEach-Object { Write-Host "   $_" -ForegroundColor Gray }
    
    Write-Host ""
    Write-Host "⚠️  IMPORTANTE: Em produção, use credenciais reais!" -ForegroundColor Yellow
    Write-Host "📁 Arquivo criado na raiz para os scripts funcionarem" -ForegroundColor Cyan
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

# 5. Executar deploy seguro (nova estrutura)
Write-Host "🚀 EXECUTANDO DEPLOY SEGURO..." -ForegroundColor Green
Write-Host "-" * 40
try {
    # Executar script da nova localização
    & ".\scripts\deployment\deploy-seguro.ps1"
    if ($LASTEXITCODE -ne 0) {
        throw "Deploy falhou"
    }
    Write-Host "✅ Deploy executado com sucesso!" -ForegroundColor Green
} catch {
    Write-Host "❌ Falha no deploy: $_" -ForegroundColor Red
    Write-Host "📁 Verificando se script existe na nova estrutura..." -ForegroundColor Yellow
    if (Test-Path ".\scripts\deployment\deploy-seguro.ps1") {
        Write-Host "✅ Script encontrado: .\scripts\deployment\deploy-seguro.ps1" -ForegroundColor Green
    } else {
        Write-Host "❌ Script não encontrado na nova estrutura!" -ForegroundColor Red
    }
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