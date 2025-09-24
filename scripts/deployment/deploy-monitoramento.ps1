# Script para Deploy do Monitoramento - Prometheus APENAS
# Configura monitoramento com Prometheus (sem Grafana para o trabalho)

Write-Host "INICIANDO DEPLOY DO MONITORAMENTO PROMETHEUS PATOCASH" -ForegroundColor Green
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

# Criar namespace de monitoramento
Write-Host "Criando namespace de monitoramento..." -ForegroundColor Cyan
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

# Verificar se backend PatoCash esta rodando
Write-Host "Verificando backend PatoCash..." -ForegroundColor Cyan
$backend = kubectl get service patocast-backend-service 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "AVISO: Backend PatoCash nao encontrado!" -ForegroundColor Yellow
    Write-Host "Execute primeiro: .\scripts\deployment\deploy-seguro.ps1" -ForegroundColor Yellow
    Write-Host "Continuando com deploy do monitoramento..." -ForegroundColor Cyan
} else {
    Write-Host "OK: Backend PatoCash encontrado!" -ForegroundColor Green
}

# Deploy do Prometheus ConfigMap
Write-Host "1. Aplicando configuracao do Prometheus..." -ForegroundColor Cyan
kubectl apply -f kubernetes/monitoring/prometheus-configmap.yaml

# Deploy do Prometheus e Grafana
Write-Host "2. Fazendo deploy do Prometheus e Grafana..." -ForegroundColor Cyan
kubectl apply -f kubernetes/monitoring/prometheus-deployment.yaml

# Aguardar Prometheus estar pronto
Write-Host "Aguardando Prometheus estar pronto..." -ForegroundColor Yellow
kubectl wait --for=condition=ready pod -l app=prometheus -n monitoring --timeout=120s

# NOTA: Grafana removido para este trabalho - apenas Prometheus conforme solicitado

# Verificar status dos pods
Write-Host "STATUS DO MONITORAMENTO:" -ForegroundColor Green
Write-Host "=" * 30
kubectl get pods -n monitoring
Write-Host ""
kubectl get services -n monitoring

# Obter URLs de acesso
Write-Host ""
Write-Host "CONFIGURANDO ACESSO AOS DASHBOARDS..." -ForegroundColor Cyan

# Obter NodePort do Prometheus
$prometheusPort = kubectl get service prometheus-service -n monitoring -o jsonpath='{.spec.ports[0].nodePort}' 2>$null
if ($prometheusPort) {
    $prometheusUrl = "http://localhost:$prometheusPort"
} else {
    $prometheusUrl = "http://localhost:30000"
}

Write-Host ""
Write-Host "INTERFACE DE MONITORAMENTO:" -ForegroundColor Green
Write-Host "=" * 30
Write-Host "Prometheus Web UI: $prometheusUrl" -ForegroundColor Yellow

Write-Host ""
Write-Host "COMO USAR O PROMETHEUS:" -ForegroundColor Yellow
Write-Host "1. Acesse: $prometheusUrl" -ForegroundColor Gray
Write-Host "2. Va para a aba 'Graph'" -ForegroundColor Gray
Write-Host "3. Digite queries PromQL no campo 'Expression'" -ForegroundColor Gray
Write-Host "4. Clique 'Execute' para ver resultados" -ForegroundColor Gray
Write-Host "5. Use 'Graph' para visualizacao temporal" -ForegroundColor Gray

Write-Host ""
Write-Host "METRICAS DISPONIVEIS DO PATOCASH:" -ForegroundColor Cyan
Write-Host "- python_gc_objects_collected_total" -ForegroundColor Gray
Write-Host "- python_info" -ForegroundColor Gray
Write-Host "- process_cpu_seconds_total" -ForegroundColor Gray
Write-Host "- process_resident_memory_bytes" -ForegroundColor Gray
Write-Host "- E mais metricas automaticas do Flask/Python" -ForegroundColor Gray

Write-Host ""
Write-Host "PARA TESTAR AS METRICAS:" -ForegroundColor Yellow
Write-Host "1. Acesse Prometheus: $prometheusUrl" -ForegroundColor Gray
Write-Host "2. Va em Graph e digite: python_info" -ForegroundColor Gray
Write-Host "3. Execute para ver metricas do backend PatoCash" -ForegroundColor Gray

Write-Host ""
Write-Host "CONFIGURANDO PORT-FORWARDS PARA ACESSO..." -ForegroundColor Cyan

# Verificar se portas estao em uso e limpar se necessario
$prometheus_port = 9090
$grafana_port = 3001

Write-Host "Verificando portas disponiveis..." -ForegroundColor Yellow

# Limpar processos kubectl existentes se necessario
$portCheck = netstat -an | Select-String ":$prometheus_port.*LISTENING|:$grafana_port.*LISTENING"
if ($portCheck) {
    Write-Host "Limpando port-forwards existentes..." -ForegroundColor Yellow
    $processes = Get-Process | Where-Object { $_.ProcessName -eq "kubectl" }
    foreach ($proc in $processes) {
        try {
            $proc.Kill()
        } catch {
            # Ignorar erros
        }
    }
    Start-Sleep -Seconds 3
}

# Configurar port-forward apenas para Prometheus
Write-Host "Iniciando port-forward Prometheus (porta 9090)..." -ForegroundColor Cyan
Start-Process powershell -ArgumentList "-Command", "kubectl port-forward -n monitoring service/prometheus-service 9090:9090" -WindowStyle Hidden

# NOTA: Port-forward do Grafana removido - usando apenas Prometheus

# Aguardar port-forwards iniciarem
Write-Host "Aguardando port-forwards iniciarem..." -ForegroundColor Yellow
Start-Sleep -Seconds 8

# Testar acesso
Write-Host "Testando acesso aos dashboards..." -ForegroundColor Cyan

try {
    $prometheusTest = Invoke-WebRequest -Uri "http://localhost:9090/-/healthy" -TimeoutSec 5 -ErrorAction Stop
    Write-Host "OK: Prometheus acessivel em http://localhost:9090" -ForegroundColor Green
} catch {
    Write-Host "AVISO: Prometheus pode nao estar pronto ainda" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "ACESSE O PROMETHEUS:" -ForegroundColor Green
Write-Host "Interface Web: http://localhost:9090" -ForegroundColor Yellow

Write-Host ""
Write-Host "QUERIES UTEIS PARA O TRABALHO:" -ForegroundColor Cyan
Write-Host "• Pods ativos: count(up{app=\"patocast-backend\"} == 1)" -ForegroundColor Gray
Write-Host "• CPU usage: rate(process_cpu_seconds_total{app=\"patocast-backend\"}[5m]) * 100" -ForegroundColor Gray
Write-Host "• Memoria: process_resident_memory_bytes{app=\"patocast-backend\"}" -ForegroundColor Gray
Write-Host "• HPA status: kube_horizontalpodautoscaler_status_current_replicas" -ForegroundColor Gray

Write-Host ""
Write-Host "COMANDOS UTEIS:" -ForegroundColor Blue
Write-Host "Ver logs Prometheus: kubectl logs -l app=prometheus -n monitoring" -ForegroundColor Gray
Write-Host "Parar port-forwards: Get-Process kubectl | Stop-Process" -ForegroundColor Gray
Write-Host "Testar metricas: curl http://localhost:5000/metrics" -ForegroundColor Gray

Write-Host ""
Write-Host "PROMETHEUS CONFIGURADO - PRONTO PARA O TRABALHO!" -ForegroundColor Green