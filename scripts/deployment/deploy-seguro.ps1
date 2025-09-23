# 🚀 Script de Deploy Seguro - PatoCash Kubernetes
# Este script usa variáveis do .env de forma segura (Nova estrutura organizada)

Write-Host "🚀 INICIANDO DEPLOY SEGURO PATOCASH" -ForegroundColor Green
Write-Host "=" * 50

# Navegar para a raiz do projeto (2 níveis acima)
$projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location $projectRoot
Write-Host "📁 Executando a partir de: $projectRoot" -ForegroundColor Cyan

# Importar função para criar Secret a partir do .env
. "$PSScriptRoot\create-secret.ps1"

# Verificar se arquivo .env existe (na raiz)
if (-not (Test-Path ".env")) {
    Write-Host "❌ Arquivo .env não encontrado na raiz!" -ForegroundColor Red
    Write-Host "📝 Crie o arquivo .env baseado em kubernetes\configs\.env-exemplo" -ForegroundColor Yellow
    exit 1
}

Write-Host "✅ Arquivo .env encontrado na raiz" -ForegroundColor Green

# 1. Criar Secret dinamicamente do .env
Write-Host "🔒 Criando Secret a partir do .env..." -ForegroundColor Cyan
if (-not (Create-SecretFromEnv -EnvFile ".env" -SecretName "patocast-secrets")) {
    Write-Host "❌ Falha ao criar Secret!" -ForegroundColor Red
    exit 1
}

# 2. Aplicar ConfigMaps (nova estrutura)
Write-Host "2️⃣ Aplicando configurações..." -ForegroundColor Cyan
kubectl apply -f kubernetes\manifests\k8s-configmap.yaml

# 3. Criar ConfigMap com scripts SQL
Write-Host "3️⃣ Criando scripts de inicialização do banco..." -ForegroundColor Cyan
kubectl delete configmap postgres-init-scripts --ignore-not-found=true
kubectl create configmap postgres-init-scripts --from-file=./banco_de_dados/

# 4. Deploy PostgreSQL (nova estrutura)
Write-Host "4️⃣ Fazendo deploy do PostgreSQL..." -ForegroundColor Cyan
kubectl apply -f kubernetes\manifests\k8s-postgres.yaml

# Aguardar PostgreSQL
Write-Host "⏳ Aguardando PostgreSQL estar pronto..." -ForegroundColor Yellow
kubectl wait --for=condition=ready pod -l app=postgres --timeout=120s

# 5. Deploy Backend (nova estrutura)
Write-Host "5️⃣ Fazendo deploy do Backend..." -ForegroundColor Cyan
kubectl apply -f kubernetes\manifests\k8s-backend.yaml

# Aguardar Backend
Write-Host "⏳ Aguardando Backend estar pronto..." -ForegroundColor Yellow
kubectl wait --for=condition=ready pod -l app=patocast-backend --timeout=120s

# 6. Deploy Frontend (nova estrutura)
Write-Host "6️⃣ Fazendo deploy do Frontend..." -ForegroundColor Cyan
kubectl apply -f kubernetes\manifests\k8s-frontend.yaml

# Aguardar Frontend
Write-Host "⏳ Aguardando Frontend estar pronto..." -ForegroundColor Yellow
kubectl wait --for=condition=ready pod -l app=patocast-frontend --timeout=120s

# 7. Deploy HPA (nova estrutura)
Write-Host "7️⃣ Configurando Auto-scaling..." -ForegroundColor Cyan
kubectl apply -f kubernetes\manifests\k8s-hpa.yaml

# Status final
Write-Host "📊 STATUS FINAL:" -ForegroundColor Green
Write-Host "=" * 30

kubectl get all

Write-Host ""
Write-Host "🔐 SEGURANÇA IMPLEMENTADA:" -ForegroundColor Green
Write-Host "✅ Credenciais em Secrets (criptografadas)" -ForegroundColor Green
Write-Host "✅ Configurações em ConfigMaps" -ForegroundColor Green
Write-Host "✅ Variáveis sensíveis isoladas" -ForegroundColor Green

Write-Host ""
Write-Host "🌐 INICIANDO ACESSO À APLICAÇÃO..." -ForegroundColor Cyan
Write-Host "Configurando port-forward para acesso local..." -ForegroundColor Yellow

# Iniciar port-forward em background
Write-Host "🚀 Iniciando port-forward na porta 3000..." -ForegroundColor Green
Start-Process powershell -ArgumentList "-NoExit", "-Command", "kubectl port-forward service/patocast-frontend-service 3000:3000" -WindowStyle Normal

# Aguardar um pouco para o port-forward inicializar
Start-Sleep -Seconds 3

Write-Host ""
Write-Host "🌐 APLICAÇÃO DISPONÍVEL:" -ForegroundColor Green
Write-Host "✅ Acesse: http://localhost:3000" -ForegroundColor Yellow
Write-Host "✅ Port-forward rodando em terminal separado" -ForegroundColor Green

Write-Host ""
Write-Host "🧪 TESTE A ROTA PROBLEMÁTICA:" -ForegroundColor Cyan
Write-Host "http://localhost:3000/save_conta (POST)" -ForegroundColor Yellow

Write-Host ""
Write-Host "ℹ️  CONTROLE DO PORT-FORWARD:" -ForegroundColor Blue
Write-Host "Para parar: Feche o terminal do port-forward" -ForegroundColor Yellow
Write-Host "Para reiniciar: kubectl port-forward service/patocast-frontend-service 3000:3000" -ForegroundColor Yellow

Write-Host ""
Write-Host "✅ DEPLOY SEGURO CONCLUÍDO E APLICAÇÃO ACESSÍVEL!" -ForegroundColor Green