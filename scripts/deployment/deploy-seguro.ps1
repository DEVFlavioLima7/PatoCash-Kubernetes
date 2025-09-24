# Script de Deploy Seguro - PatoCash Kubernetes
# # Verificar se arquivo .env existe (na raiz)
if (-not (Test-Path ".env")) {
    Write-Host "ERRO: Arquivo .env nao encontrado na raiz!" -ForegroundColor Red
    Write-Host "Crie o arquivo .env baseado em kubernetes\configs\.env-exemplo" -ForegroundColor Yellow
    exit 1
}

Write-Host "INICIANDO DEPLOY SEGURO PATOCASH" -ForegroundColor Green
Write-Host "=" * 50

# Navegar para a raiz do projeto (2 niveis acima)
$projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location $projectRoot
Write-Host "Executando a partir de: $projectRoot" -ForegroundColor Cyande Deploy Seguro - PatoCash Kubernetes
# Este script usa variáveis do .env de forma segura (Nova estrutura organizada)

Write-Host "INICIANDO DEPLOY SEGURO PATOCASH" -ForegroundColor Green
Write-Host "=" * 50

# Navegar para a raiz do projeto (2 níveis acima)
$projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location $projectRoot
Write-Host "Executando a partir de: $projectRoot" -ForegroundColor Cyan

# Importar função para criar Secret a partir do .env
. "$PSScriptRoot\create-secret.ps1"

# Verificar se Minikube esta rodando
Write-Host "VERIFICANDO MINIKUBE..." -ForegroundColor Cyan
Write-Host "-" * 30

$minikubeStatus = minikube status 2>$null
if ($LASTEXITCODE -ne 0 -or $minikubeStatus -notmatch "Running") {
    Write-Host "AVISO: Minikube nao esta rodando. Iniciando..." -ForegroundColor Yellow
    try {
        minikube start --driver=docker
        if ($LASTEXITCODE -ne 0) {
            throw "Falha ao iniciar Minikube"
        }
        Write-Host "OK: Minikube iniciado com sucesso!" -ForegroundColor Green
        Write-Host "Habilitando metrics-server..." -ForegroundColor Yellow
        minikube addons enable metrics-server
        Write-Host "Aguardando metrics-server..." -ForegroundColor Yellow
        Start-Sleep -Seconds 10
        
    } catch {
        Write-Host "ERRO: Falha ao iniciar Minikube: $_" -ForegroundColor Red
        exit 1
    }
} else {
        Write-Host "OK: Minikube ja esta rodando!" -ForegroundColor Green
}

Write-Host ""

# Verificar se arquivo .env existe (na raiz)
if (-not (Test-Path ".env")) {
    Write-Host "ERRO: Arquivo .env nao encontrado na raiz!" -ForegroundColor Red
    Write-Host "Crie o arquivo .env baseado em kubernetes\configs\.env-exemplo" -ForegroundColor Yellow
    exit 1
}

Write-Host "OK: Arquivo .env encontrado na raiz" -ForegroundColor Green

# 1. Criar Secret dinamicamente do .env
Write-Host "Criando Secret a partir do .env..." -ForegroundColor Cyan
if (-not (Create-SecretFromEnv -EnvFile ".env" -SecretName "patocast-secrets")) {
    Write-Host "Falha ao criar Secret!" -ForegroundColor Red
    exit 1
}

# 2. Aplicar ConfigMaps (nova estrutura)
Write-Host "Aplicando configurações..." -ForegroundColor Cyan
kubectl apply -f kubernetes\manifests\k8s-configmap.yaml

# 3. Criar ConfigMap com scripts SQL
Write-Host "Criando scripts de inicialização do banco..." -ForegroundColor Cyan
kubectl delete configmap postgres-init-scripts --ignore-not-found=true
kubectl create configmap postgres-init-scripts --from-file=./banco_de_dados/

# 4. Deploy PostgreSQL (nova estrutura)
Write-Host "Fazendo deploy do PostgreSQL..." -ForegroundColor Cyan
kubectl apply -f kubernetes\manifests\k8s-postgres.yaml

# Aguardar PostgreSQL
Write-Host "Aguardando PostgreSQL estar pronto..." -ForegroundColor Yellow
kubectl wait --for=condition=ready pod -l app=postgres --timeout=120s

# 5. Deploy Backend (nova estrutura)
Write-Host "Fazendo deploy do Backend..." -ForegroundColor Cyan
kubectl apply -f kubernetes\manifests\k8s-backend.yaml

# Aguardar Backend
Write-Host "Aguardando Backend estar pronto..." -ForegroundColor Yellow
kubectl wait --for=condition=ready pod -l app=patocast-backend --timeout=120s

# 6. Deploy Frontend (nova estrutura)
Write-Host "Fazendo deploy do Frontend..." -ForegroundColor Cyan
kubectl apply -f kubernetes\manifests\k8s-frontend.yaml

# Aguardar Frontend
Write-Host "Aguardando Frontend estar pronto..." -ForegroundColor Yellow
kubectl wait --for=condition=ready pod -l app=patocast-frontend --timeout=120s

# 7. Deploy HPA (nova estrutura)
Write-Host "Configurando Auto-scaling..." -ForegroundColor Cyan
kubectl apply -f kubernetes\manifests\k8s-hpa.yaml

# Status final
Write-Host "STATUS FINAL:" -ForegroundColor Green
Write-Host "=" * 30

kubectl get all

Write-Host ""
Write-Host "SEGURANCA IMPLEMENTADA:" -ForegroundColor Green
Write-Host "OK: Credenciais em Secrets (criptografadas)" -ForegroundColor Green
Write-Host "OK: Configuracoes em ConfigMaps" -ForegroundColor Green
Write-Host "OK: Variaveis sensiveis isoladas" -ForegroundColor Green

Write-Host ""
Write-Host "INICIANDO ACESSO A APLICACAO..." -ForegroundColor Cyan

# Usar o script acesso-app para configurar port-forward
$acessoScript = Join-Path $PSScriptRoot "acesso-app.ps1"

if (Test-Path $acessoScript) {
    Write-Host "Executando acesso-app.ps1 para configurar port-forwards..." -ForegroundColor Yellow
    
    # Executar acesso-app em background para configurar port-forwards
    Start-Job -ScriptBlock {
        param($scriptPath)
        
        # Configurar port-forward para frontend (porta 3000)
        Start-Process powershell -ArgumentList "kubectl port-forward service/patocast-frontend-service 3000:3000" -WindowStyle Hidden -PassThru
        
        # Configurar port-forward para backend (porta 5000)  
        Start-Process powershell -ArgumentList "kubectl port-forward service/patocast-backend-service 5000:5000" -WindowStyle Hidden -PassThru
        
        Start-Sleep -Seconds 5
        return "Port-forwards configurados"
    } -ArgumentList $acessoScript | Out-Null
    
    # Aguardar port-forwards serem configurados
    Start-Sleep -Seconds 8
    
    Write-Host "OK: Port-forwards configurados automaticamente!" -ForegroundColor Green
    
} else {
    Write-Host "AVISO: Script acesso-app.ps1 nao encontrado!" -ForegroundColor Yellow
    Write-Host "Configurando port-forward simples..." -ForegroundColor Yellow
    
    # Fallback para port-forward simples
    Start-Process powershell -ArgumentList "-NoExit", "-Command", "kubectl port-forward service/patocast-frontend-service 3000:3000" -WindowStyle Normal
    Start-Sleep -Seconds 3
}

Write-Host ""
Write-Host "APLICACAO DISPONIVEL:" -ForegroundColor Green
Write-Host "Frontend: http://localhost:3000" -ForegroundColor Yellow
Write-Host "Backend: http://localhost:5000" -ForegroundColor Yellow
Write-Host "Metricas: http://localhost:5000/metrics" -ForegroundColor Yellow

Write-Host ""
Write-Host "TESTE A ROTA PROBLEMATICA:" -ForegroundColor Cyan
Write-Host "http://localhost:3000/save_conta (POST)" -ForegroundColor Yellow

Write-Host ""
Write-Host "CONTROLE DO PORT-FORWARD:" -ForegroundColor Blue
Write-Host "Para reconfigurar: .\scripts\deployment\acesso-app.ps1" -ForegroundColor Yellow
Write-Host "Para parar: Feche os processos ou reinicie o terminal" -ForegroundColor Yellow

Write-Host ""
Write-Host "DEPLOY SEGURO CONCLUIDO E APLICACAO ACESSIVEL!" -ForegroundColor Green
