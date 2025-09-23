# Testes Rápidos - PatoCash Kubernetes
# Scripts individuais para testes específicos

Write-Host "TESTES RÁPIDOS PATOCASH" -ForegroundColor Green
Write-Host "=" * 40

# Função para mostrar menu
function Show-Menu {
    Write-Host ""
    Write-Host "Escolha um teste:" -ForegroundColor Cyan
    Write-Host "1. Deletar Pod (Auto-Healing)" -ForegroundColor Yellow
    Write-Host "2. Stress CPU (HPA)" -ForegroundColor Yellow  
    Write-Host "3. Status Atual" -ForegroundColor Yellow
    Write-Host "4. Escalar Manualmente" -ForegroundColor Yellow
    Write-Host "5. Reset Completo" -ForegroundColor Yellow
    Write-Host "0. Sair" -ForegroundColor Red
    Write-Host ""
}

# Função para deletar pod
function Delete-Pod {
    Write-Host "TESTE: Deletar Pod (Auto-Healing)" -ForegroundColor Red
    
    $pods = kubectl get pods -l app=patocast-backend --no-headers -o custom-columns=":metadata.name"
    if (-not $pods) {
        Write-Host "Nenhum pod backend encontrado!" -ForegroundColor Red
        return
    }
    
    $podArray = $pods -split "`n" | Where-Object { $_ -ne "" }
    Write-Host "Pods disponíveis:" -ForegroundColor Cyan
    for ($i = 0; $i -lt $podArray.Count; $i++) {
    Write-Host "  $($i+1). $($podArray[$i])" -ForegroundColor Yellow
    }
    
    $choice = Read-Host "Escolha o pod para deletar (1-$($podArray.Count))"
    $podIndex = [int]$choice - 1
    
    if ($podIndex -ge 0 -and $podIndex -lt $podArray.Count) {
        $selectedPod = $podArray[$podIndex]
    Write-Host "Deletando pod: $selectedPod" -ForegroundColor Red
        kubectl delete pod $selectedPod
        
    Write-Host "Monitorando recuperação por 60 segundos..." -ForegroundColor Yellow
        for ($i = 1; $i -le 12; $i++) {
            Start-Sleep -Seconds 5
            Write-Host "Verificação $i/12:" -ForegroundColor Cyan
            kubectl get pods -l app=patocast-backend
            Write-Host ""
        }
    } else {
    Write-Host "Escolha inválida!" -ForegroundColor Red
    }
}

# Função para stress de CPU
function Stress-CPU {
    Write-Host "TESTE: Stress de CPU (HPA)" -ForegroundColor Blue
    
    $duracao = Read-Host "Duração do stress em segundos (padrão: 180)"
    if (-not $duracao) { $duracao = 180 }
    
    $pods = kubectl get pods -l app=patocast-backend --no-headers -o custom-columns=":metadata.name"
    if (-not $pods) {
    Write-Host "Nenhum pod backend encontrado!" -ForegroundColor Red
        return
    }
    
    Write-Host "Iniciando stress de CPU por $duracao segundos..." -ForegroundColor Red
    
    $podArray = $pods -split "`n" | Where-Object { $_ -ne "" }
    foreach ($pod in $podArray) {
    Write-Host "Stress no pod: $pod" -ForegroundColor Yellow
        
        # Comando Python para stress de CPU
        $stressCmd = "python3 -c `"
import time, threading
def stress(): 
    end = time.time() + $duracao
    while time.time() < end: pass
for i in range(2): threading.Thread(target=stress).start()
time.sleep($duracao)
`""
        
        Start-Job -ScriptBlock {
            param($podName, $command)
            kubectl exec $podName -- sh -c $command
        } -ArgumentList $pod, $stressCmd | Out-Null
    }
    
    Write-Host "Monitorando HPA por $([math]::Round($duracao/60, 1)) minutos..." -ForegroundColor Green
    
    $monitorTime = $duracao + 60  # stress + 1 min extra
    for ($i = 1; $i -le [math]::Ceiling($monitorTime/10); $i++) {
    Write-Host "Verificação $i - $(Get-Date -Format 'HH:mm:ss')" -ForegroundColor Cyan
        kubectl get hpa patocast-hpa
    kubectl get pods -l app=patocast-backend --no-headers | Measure-Object | ForEach-Object { Write-Host "Pods backend ativos: $($_.Count)" -ForegroundColor Yellow }
        Write-Host ""
        Start-Sleep -Seconds 10
    }
    
    # Limpar jobs
    Get-Job | Remove-Job -Force
}

# Função para mostrar status
function Show-Status {
    Write-Host "STATUS ATUAL DO CLUSTER" -ForegroundColor Green
    Write-Host ""
    
    Write-Host "Deployments:" -ForegroundColor Cyan
    kubectl get deployments -l app=patocast-backend,app=patocast-frontend
    
    Write-Host ""
    Write-Host "Pods:" -ForegroundColor Cyan
    kubectl get pods -l app=patocast-backend,app=patocast-frontend -o wide
    
    Write-Host ""
    Write-Host "HPA:" -ForegroundColor Cyan
    kubectl get hpa patocast-hpa
    
    Write-Host ""
    Write-Host "Services:" -ForegroundColor Cyan
    kubectl get services -l app=patocast-backend,app=patocast-frontend
    
    Write-Host ""
    Write-Host "Recursos:" -ForegroundColor Cyan
    kubectl top pods -l app=patocast-backend,app=patocast-frontend 2>$null || Write-Host "Metrics server pode não estar disponível" -ForegroundColor Yellow
}

# Função para escalar manualmente
function Scale-Manual {
    Write-Host "ESCALAR MANUALMENTE" -ForegroundColor Magenta
    
    $replicas = Read-Host "Número de réplicas backend desejadas (atual: $(kubectl get deployment patocast-backend -o jsonpath='{.status.replicas}'))"
    
    if ($replicas -match '^\d+$' -and [int]$replicas -ge 1 -and [int]$replicas -le 10) {
    Write-Host "Escalando para $replicas réplicas..." -ForegroundColor Yellow
        kubectl scale deployment patocast-backend --replicas=$replicas
        
    Write-Host "Aguardando escalonamento..." -ForegroundColor Yellow
        kubectl rollout status deployment patocast-backend --timeout=120s
        
    Write-Host "Escalonamento concluído!" -ForegroundColor Green
        kubectl get pods -l app=patocast-backend
    } else {
    Write-Host "Número inválido! Use 1-10" -ForegroundColor Red
    }
}

# Função para reset
function Reset-Deployment {
    Write-Host "RESET COMPLETO" -ForegroundColor Red
    $confirm = Read-Host "Tem certeza? Isso vai recriar todos os pods (s/N)"
    
    if ($confirm -eq 's' -or $confirm -eq 'S') {
    Write-Host "Fazendo rollout restart..." -ForegroundColor Yellow
        kubectl rollout restart deployment patocast-backend
        kubectl rollout restart deployment patocast-frontend
        
    Write-Host "Aguardando restart..." -ForegroundColor Yellow
        kubectl rollout status deployment patocast-backend
        kubectl rollout status deployment patocast-frontend
        
    Write-Host "Reset concluído!" -ForegroundColor Green
    } else {
    Write-Host "Reset cancelado" -ForegroundColor Yellow
    }
}

# Loop principal
while ($true) {
    Show-Menu
    $choice = Read-Host "Sua escolha"
    
    switch ($choice) {
        "1" { Delete-Pod }
        "2" { Stress-CPU }
        "3" { Show-Status }
        "4" { Scale-Manual }
        "5" { Reset-Deployment }
        "0" { 
            Write-Host "Encerrando testes!" -ForegroundColor Green
            break 
        }
        default { 
            Write-Host "Opção inválida!" -ForegroundColor Red 
        }
    }
    
    Write-Host ""
    Read-Host "Pressione Enter para continuar"
    Clear-Host
}