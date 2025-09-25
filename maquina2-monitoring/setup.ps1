# Script de setup para Maquina 2 - PatoCash Monitoring (Windows)

Write-Host "[SETUP] PatoCash Monitoring Setup - Maquina 2" -ForegroundColor Cyan
Write-Host "========================================"

# Verificar se Docker esta instalado
try {
    docker --version | Out-Null
    docker-compose --version | Out-Null
    Write-Host "[OK] Docker e Docker Compose encontrados" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] Docker nao encontrado. Instale o Docker Desktop primeiro." -ForegroundColor Red
    exit 1
}

# Solicitar IP da Maquina 1
Write-Host ""
Write-Host "[CONFIG] Configuracao de Rede" -ForegroundColor Yellow
Write-Host "----------------------"
# $MAQUINA1_IP = Read-Host "Digite o IP da Maquina 1 (Kubernetes)"
$MAQUINA1_IP = "192.168.1.100"

if ([string]::IsNullOrEmpty($MAQUINA1_IP)) {
    Write-Host "[ERROR] IP nao pode estar vazio" -ForegroundColor Red
    exit 1
}

Write-Host "[CONFIG] Configurando IP: $MAQUINA1_IP" -ForegroundColor Yellow

# Substituir IP no prometheus.yml
$prometheusContent = Get-Content "prometheus.yml" -Raw
$prometheusContent = $prometheusContent -replace "MAQUINA1_IP", $MAQUINA1_IP
Set-Content "prometheus.yml" $prometheusContent

Write-Host "[OK] Arquivo prometheus.yml configurado" -ForegroundColor Green

# Testar conectividade
Write-Host ""
Write-Host "[TEST] Testando conectividade com Maquina 1..." -ForegroundColor Yellow
try {
    $ping = Test-Connection -ComputerName $MAQUINA1_IP -Count 3 -Quiet
    if ($ping) {
        Write-Host "[OK] Conectividade OK" -ForegroundColor Green
    } else {
        Write-Host "[WARN] Aviso: Nao foi possivel ping na Maquina 1" -ForegroundColor Yellow
        Write-Host "   Verifique se a Maquina 1 esta ligada e acessivel"
    }
} catch {
    Write-Host "[WARN] Erro ao testar conectividade" -ForegroundColor Yellow
}

# Testar porta especifica
Write-Host "[TEST] Testando porta kube-state-metrics (30080)..." -ForegroundColor Yellow
try {
    $tcpClient = New-Object System.Net.Sockets.TcpClient
    $connect = $tcpClient.BeginConnect($MAQUINA1_IP, 30080, $null, $null)
    $wait = $connect.AsyncWaitHandle.WaitOne(3000, $false)
    if ($wait -and $tcpClient.Connected) {
        Write-Host "[OK] Porta 30080 acessivel" -ForegroundColor Green
    } else {
        Write-Host "[WARN] Porta 30080 nao acessivel - verifique se Kubernetes esta rodando" -ForegroundColor Yellow
    }
    $tcpClient.Close()
} catch {
    Write-Host "[WARN] Nao foi possivel testar porta 30080" -ForegroundColor Yellow
}

# Iniciar stack
Write-Host ""
Write-Host "[DEPLOY] Iniciando stack de monitoramento..." -ForegroundColor Yellow
docker-compose down 2>$null | Out-Null  # Limpar se ja estiver rodando
docker-compose up -d

if ($LASTEXITCODE -eq 0) {
    Write-Host "[OK] Stack iniciado com sucesso!" -ForegroundColor Green
    Write-Host ""
    Write-Host "[ACCESS] Acessos disponiveis:" -ForegroundColor Cyan
    Write-Host "   Prometheus: http://localhost:9090"
    Write-Host "   Grafana:    http://localhost:3000 (admin/admin123)"
    Write-Host ""
    Write-Host "[INFO] Verificar targets do Prometheus:" -ForegroundColor Cyan
    Write-Host "   http://localhost:9090/targets"
    Write-Host ""
    Write-Host "[INFO] Dashboard PatoCash no Grafana:" -ForegroundColor Cyan
    Write-Host "   http://localhost:3000/d/patocash-backend-monitor"
    Write-Host ""
    Write-Host "[WAIT] Aguarde alguns minutos para coleta de metricas..." -ForegroundColor Yellow
} else {
    Write-Host "[ERROR] Erro ao iniciar stack" -ForegroundColor Red
    Write-Host "Ver logs: docker-compose logs"
    exit 1
}

# Mostrar status final
Write-Host ""
Write-Host "[STATUS] Status dos containers:" -ForegroundColor Cyan
docker-compose ps

Write-Host ""
Write-Host "[SUCCESS] Setup concluido!" -ForegroundColor Green
Write-Host "[INFO] Para parar: docker-compose down" -ForegroundColor Yellow
Write-Host "[INFO] Para ver logs: docker-compose logs -f" -ForegroundColor Yellow