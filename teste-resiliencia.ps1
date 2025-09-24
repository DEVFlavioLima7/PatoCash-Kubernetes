# Script de Teste - PatoCash Kubernetes
# Testa Auto-Healing e HPA sem emojis nem caracteres especiais

param(
    [string]$Teste = "todos",
    [int]$DuracaoStress = 30,
    [switch]$Rapido
)

Write-Host "=== TESTE PATOCASH KUBERNETES ===" -ForegroundColor Green
Write-Host "Teste: $Teste" -ForegroundColor Cyan
Write-Host "Modo Rapido: $Rapido" -ForegroundColor Yellow
Write-Host ""

# Verificar se aplicacao esta rodando
Write-Host "Verificando aplicacao..." -ForegroundColor Cyan
$backend = kubectl get deployment patocast-backend 2>$null
$hpa1 = kubectl get hpa patocast-backend-hpa 2>$null
$hpa2 = kubectl get hpa patocast-frontend-hpa 2>$null

if (-not $backend) {
    Write-Host "ERRO: Deployment patocast-backend nao encontrado!" -ForegroundColor Red
    Write-Host "Execute: .\scripts\deployment\deploy-seguro.ps1" -ForegroundColor Yellow
    exit 1
}

if (-not $hpa1 -or -not $hpa2) {
    Write-Host "ERRO: HPAs nao encontrados!" -ForegroundColor Red
    Write-Host "Execute: .\scripts\deployment\deploy-seguro.ps1" -ForegroundColor Yellow
    exit 1
}

Write-Host "OK: Aplicacao PatoCash encontrada!" -ForegroundColor Green
Write-Host ""

# Funcao de Auto-Healing
function Test-AutoHealing {
    Write-Host "=== TESTE AUTO-HEALING ===" -ForegroundColor Red
    Write-Host ""
    
    # Mostrar pods atuais
    Write-Host "Pods ANTES do teste:" -ForegroundColor Yellow
    kubectl get pods -l app=patocast-backend
    Write-Host ""
    
    # Obter pods para deletar
    $pods = kubectl get pods -l app=patocast-backend -o jsonpath='{.items[*].metadata.name}' 2>$null
    if (-not $pods) {
        Write-Host "ERRO: Nenhum pod backend encontrado!" -ForegroundColor Red
        return
    }
    
    $podArray = $pods -split ' '
    $podToDelete = $podArray[0]
    
    Write-Host "Pod selecionado para delecao: $podToDelete" -ForegroundColor Yellow
    Write-Host ""
    
    # Sleep antes de deletar
    if (-not $Rapido) {
        Write-Host "Deletando em 3 segundos..." -ForegroundColor Red
        Start-Sleep -Seconds 3
    }
    
    # Deletar pod
    $tempoInicio = Get-Date
    Write-Host "DELETANDO POD: $podToDelete" -ForegroundColor Red
    kubectl delete pod $podToDelete
    Write-Host ""
    
    # Monitorar recuperacao
    Write-Host "Monitorando recuperacao..." -ForegroundColor Green
    $podRecuperado = $false
    $tentativas = 0
    $maxTentativas = 30
    
    while (-not $podRecuperado -and $tentativas -lt $maxTentativas) {
        $tentativas++
        $tempoDecorrido = [math]::Round(((Get-Date) - $tempoInicio).TotalSeconds)
        
        # Verificar pods atuais
        $podsAtuais = kubectl get pods -l app=patocast-backend --no-headers 2>$null
        $podsRunning = ($podsAtuais | Where-Object { $_ -match "Running" }).Count
        
        Write-Host "[$tentativas/$maxTentativas] Tempo: ${tempoDecorrido}s | Pods Running: $podsRunning" -ForegroundColor Gray
        
        # Verificar se temos pods suficientes rodando
        if ($podsRunning -ge 2) {
            $podRecuperado = $true
            Write-Host "SUCESSO: Auto-healing funcionou!" -ForegroundColor Green
            break
        }
        
        # Sleep entre verificacoes
        $sleepTime = if ($Rapido) { 1 } else { 2 }
        Start-Sleep -Seconds $sleepTime
    }
    
    # Resultado final
    $tempoTotal = [math]::Round(((Get-Date) - $tempoInicio).TotalSeconds)
    Write-Host ""
    Write-Host "=== RESULTADO AUTO-HEALING ===" -ForegroundColor Cyan
    Write-Host "Tempo total: $tempoTotal segundos" -ForegroundColor White
    
    if ($podRecuperado) {
        Write-Host "STATUS: SUCESSO - Pod foi recriado automaticamente!" -ForegroundColor Green
    } else {
        Write-Host "STATUS: TIMEOUT - Verifique manualmente" -ForegroundColor Yellow
    }
    
    Write-Host ""
    Write-Host "Pods APOS o teste:" -ForegroundColor Yellow
    kubectl get pods -l app=patocast-backend
    Write-Host ""
}

# Funcao de HPA
function Test-HPA {
    Write-Host "=== TESTE HPA ===" -ForegroundColor Blue
    Write-Host ""
    
    # Mostrar estado inicial
    Write-Host "Estado inicial dos HPAs:" -ForegroundColor Yellow
    kubectl get hpa
    Write-Host ""
    
    # Obter pods para stress
    $pods = kubectl get pods -l app=patocast-backend -o jsonpath='{.items[*].metadata.name}' 2>$null
    if (-not $pods) {
        Write-Host "ERRO: Nenhum pod backend encontrado!" -ForegroundColor Red
        return
    }
    
    $podArray = $pods -split ' '
    Write-Host "Pods encontrados: $($podArray.Count)" -ForegroundColor Yellow
    Write-Host "Lista: $($podArray -join ', ')" -ForegroundColor Cyan
    Write-Host ""
    
    # Sleep antes do stress
    if (-not $Rapido) {
        Write-Host "Iniciando stress em 3 segundos..." -ForegroundColor Red
        Start-Sleep -Seconds 3
    }
    
    # Obter URL do servico dinamicamente
    Write-Host "Descobrindo URL do servico..." -ForegroundColor Cyan
    
    # Tentar obter URL do servico via kubectl
    $serviceInfo = kubectl get service patocast-backend-service -o jsonpath='{.spec.type}:{.spec.ports[0].nodePort}' 2>$null
    $serviceUrl = if ($serviceInfo -match "NodePort:(\d+)") {
        "http://localhost:$($matches[1])"
    } else {
        # Fallback para port-forward
        Write-Host "Tentando port-forward..." -ForegroundColor Yellow
        Start-Job -ScriptBlock { kubectl port-forward service/patocast-backend-service 5000:5000 } | Out-Null
        Start-Sleep -Seconds 3
        "http://localhost:5000"
    }
    
    Write-Host "Verificando servico em: $serviceUrl" -ForegroundColor Cyan
    
    # Testar se servico esta acessivel
    try {
        $response = Invoke-WebRequest -Uri "$serviceUrl/health" -TimeoutSec 5 -ErrorAction Stop
        Write-Host "Servico respondendo: Status $($response.StatusCode)" -ForegroundColor Green
    } catch {
        Write-Host "AVISO: Servico nao acessivel em $serviceUrl" -ForegroundColor Yellow
        Write-Host "Usando stress de CPU interno como fallback..." -ForegroundColor Yellow
        
        # Fallback para stress de CPU
        foreach ($pod in $podArray) {
            Write-Host "Stress CPU no pod: $pod" -ForegroundColor Yellow
            $job = Start-Job -ScriptBlock {
                param($podName, $duracao)
                kubectl exec $podName -- sh -c "timeout $duracao yes > /dev/null &"
            } -ArgumentList $pod, $DuracaoStress
            $jobs += $job
        }
        return
    }
    
    # Iniciar stress de requisicoes HTTP
    Write-Host "Iniciando STRESS DE REQUISICOES HTTP por $DuracaoStress segundos..." -ForegroundColor Red
    Write-Host "Simulando multiplos usuarios fazendo requisicoes..." -ForegroundColor Yellow
    
    $jobs = @()
    $numWorkers = 8  # Numero de workers paralelos por endpoint
    
    # Endpoints para testar
    $endpoints = @(
        "/health",
        "/api/users", 
        "/api/transactions",
        "/api/cards"
    )
    
    foreach ($endpoint in $endpoints) {
        Write-Host "Stress no endpoint: $endpoint" -ForegroundColor Yellow
        
        for ($i = 1; $i -le $numWorkers; $i++) {
            $job = Start-Job -ScriptBlock {
                param($url, $endpoint, $duracao)
                $endTime = (Get-Date).AddSeconds($duracao)
                $requestCount = 0
                
                while ((Get-Date) -lt $endTime) {
                    try {
                        # Fazer requisicoes rapidas
                        Invoke-WebRequest -Uri "$url$endpoint" -TimeoutSec 2 -ErrorAction SilentlyContinue | Out-Null
                        $requestCount++
                        
                        # Pequeno delay para nao sobrecarregar demais
                        Start-Sleep -Milliseconds 100
                    } catch {
                        # Ignorar erros e continuar
                    }
                }
                
                Write-Output "Worker finalizado: $requestCount requisicoes para $endpoint"
            } -ArgumentList $serviceUrl, $endpoint, $DuracaoStress
            
            $jobs += $job
        }
    }
    
    Write-Host ""
    Write-Host "Stress de requisicoes HTTP iniciado!" -ForegroundColor Green
    Write-Host "Workers ativos: $($jobs.Count) | Endpoints: $($endpoints.Count)" -ForegroundColor Cyan
    
    # Monitorar HPA com deteccao inteligente de scaling
    $tempoMonitoramento = $DuracaoStress + 90  # stress + 1.5 min extra
    $inicio = Get-Date
    $podsIniciais = $podArray.Count
    $scalingDetectado = $false
    
    while (((Get-Date) - $inicio).TotalSeconds -lt $tempoMonitoramento) {
        $tempoDecorrido = [math]::Round(((Get-Date) - $inicio).TotalSeconds)
        
        Clear-Host
        Write-Host "=== MONITORAMENTO HPA ===" -ForegroundColor Blue
        Write-Host "Tempo decorrido: $tempoDecorrido / $tempoMonitoramento segundos" -ForegroundColor Yellow
        Write-Host "Pods iniciais: $podsIniciais" -ForegroundColor Cyan
        Write-Host ""
        
        # Obter informacoes do HPA
        $hpaInfo = kubectl get hpa patocast-backend-hpa --no-headers 2>$null
        if ($hpaInfo) {
            $hpaFields = $hpaInfo -split '\s+'
            $currentReplicas = $hpaFields[5]  # Campo REPLICAS
            $cpuPercent = $hpaFields[2]       # Campo TARGETS
            
            # Extrair apenas o numero da CPU
            $cpuNumber = if ($cpuPercent -match '(\d+)%') { $matches[1] } else { "?" }
            
            Write-Host "CPU: $cpuNumber% (limite: 70%) | Replicas: $currentReplicas" -ForegroundColor Yellow
            
            # Mostrar status baseado no CPU
            if ($cpuNumber -match '\d+' -and [int]$cpuNumber -gt 70) {
                Write-Host "STATUS: CPU ALTA - Scaling deve ocorrer!" -ForegroundColor Red
            } elseif ($cpuNumber -match '\d+' -and [int]$cpuNumber -gt 50) {
                Write-Host "STATUS: CPU subindo..." -ForegroundColor Yellow
            }
            
            # Verificar se houve scaling
            if ([int]$currentReplicas -gt $podsIniciais -and -not $scalingDetectado) {
                Write-Host "SCALING DETECTADO! Pods aumentaram de $podsIniciais para $currentReplicas" -ForegroundColor Green
                $scalingDetectado = $true
            }
        }
        
        Write-Host ""
        # Mostrar status atual
        kubectl get hpa patocast-backend-hpa
        Write-Host ""
        kubectl get pods -l app=patocast-backend
        Write-Host ""
        
        # Se scaling foi detectado e ja passou tempo suficiente, pode encerrar mais cedo
        if ($scalingDetectado -and $tempoDecorrido -gt ($DuracaoStress + 30)) {
            Write-Host "Scaling detectado e tempo suficiente decorrido. Encerrando monitoramento..." -ForegroundColor Green
            break
        }
        
        $sleepTime = if ($Rapido) { 3 } else { 5 }
        Start-Sleep -Seconds $sleepTime
    }
    
    # Limpar jobs
    $jobs | Stop-Job -ErrorAction SilentlyContinue
    $jobs | Remove-Job -ErrorAction SilentlyContinue
    
    Write-Host "=== RESULTADO HPA ===" -ForegroundColor Cyan
    Write-Host "Teste HPA concluido!" -ForegroundColor Green
    
    # Verificar resultado final
    $podsFinal = kubectl get pods -l app=patocast-backend --no-headers 2>$null
    $countFinal = ($podsFinal | Measure-Object).Count
    
    if ($scalingDetectado) {
        Write-Host "STATUS: SUCESSO - Scaling automatico funcionou!" -ForegroundColor Green
        Write-Host "Pods: $podsIniciais -> $countFinal" -ForegroundColor White
    } else {
        Write-Host "STATUS: Scaling nao detectado - Pode precisar de mais stress" -ForegroundColor Yellow
        Write-Host "Pods mantidos: $countFinal" -ForegroundColor White
    }
    Write-Host ""
}

# Executar teste baseado no parametro
switch ($Teste.ToLower()) {
    "auto-healing" {
        Test-AutoHealing
    }
    "hpa" {
        Test-HPA
    }
    "todos" {
        Test-AutoHealing
        Write-Host "Aguardando antes do proximo teste..." -ForegroundColor Gray
        if (-not $Rapido) {
            Start-Sleep -Seconds 10
        } else {
            Start-Sleep -Seconds 5
        }
        Test-HPA
    }
    default {
        Write-Host "ERRO: Teste invalido '$Teste'" -ForegroundColor Red
        Write-Host "Opcoes validas: auto-healing, hpa, todos" -ForegroundColor Yellow
        exit 1
    }
}

Write-Host ""
Write-Host "=== TESTE CONCLUIDO ===" -ForegroundColor Green
Write-Host "Script finalizado com sucesso!" -ForegroundColor White