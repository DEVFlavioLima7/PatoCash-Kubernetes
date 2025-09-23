# 🌐 Script para Acessar a Aplicação PatoCash
# Este script configura o port-forward para acessar a aplicação no Windows

Write-Host "🌐 CONFIGURANDO ACESSO À APLICAÇÃO PATOCASH" -ForegroundColor Green
Write-Host "=" * 50

# Verificar se o serviço existe
Write-Host "🔍 Verificando se a aplicação está rodando..." -ForegroundColor Cyan
$serviceCheck = kubectl get service patocast-frontend-service 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Serviço patocast-frontend-service não encontrado!" -ForegroundColor Red
    Write-Host "📋 Execute primeiro: .\deploy-seguro.ps1" -ForegroundColor Yellow
    exit 1
}

Write-Host "✅ Serviço encontrado!" -ForegroundColor Green

# Verificar se já existe um port-forward ativo na porta 3000
Write-Host "🔍 Verificando porta 3000..." -ForegroundColor Cyan
$portCheck = netstat -an | Select-String ":3000.*LISTENING"
if ($portCheck) {
    Write-Host "⚠️  Porta 3000 já está em uso!" -ForegroundColor Yellow
    Write-Host "Tentando matar processos existentes..." -ForegroundColor Yellow
    
    # Tentar encontrar e matar processos kubectl na porta 3000
    $processes = Get-Process | Where-Object { $_.ProcessName -eq "kubectl" }
    foreach ($proc in $processes) {
        try {
            $proc.Kill()
            Write-Host "✅ Processo kubectl $($proc.Id) terminado" -ForegroundColor Green
        } catch {
            Write-Host "⚠️  Não foi possível terminar processo $($proc.Id)" -ForegroundColor Yellow
        }
    }
    
    Start-Sleep -Seconds 2
}

# Verificar se pods estão rodando
Write-Host "🔍 Verificando status dos pods..." -ForegroundColor Cyan
kubectl get pods -l app=patocast-frontend
kubectl get pods -l app=patocast-backend

# Executar port-forward (em paralelo)
Write-Host "🌐 Aplicação disponível em: http://localhost:3000" -ForegroundColor Green
Write-Host "🔗 Para testar cadastro: http://localhost:3000/save_conta" -ForegroundColor Cyan
Write-Host ""

# Iniciar port-forward para frontend
Start-Process powershell -ArgumentList "kubectl port-forward service/patocast-frontend-service 3000:3000" -WindowStyle Hidden

# Iniciar port-forward para backend
Start-Process powershell -ArgumentList "kubectl port-forward service/patocast-backend-service 5000:5000" -WindowStyle Hidden

Write-Host "🚀 Port-forwards iniciados em background. Pressione qualquer tecla para sair." -ForegroundColor Green
[void][System.Console]::ReadKey($true)
