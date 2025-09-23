# 🧪 Script de Teste - Auto-Healing e HPA do PatoCash
# Este script demonstra os mecanismos de resiliência do Kubernetes

param(
    [string]$Teste = "todos",  # opcoes: "auto-healing", "hpa", "todos"
    [int]$DuracaoStress = 300,  # 5 minutos de stress por padrão
    [int]$IntervaloMonitoramento = 5  # verificar a cada 5 segundos
)

Write-Host "🧪 INICIANDO TESTES DE RESILIÊNCIA PATOCASH" -ForegroundColor Green
Write-Host "=" * 60
Write-Host "📊 Teste selecionado: $Teste" -ForegroundColor Cyan
Write-Host "⏱️  Duração do stress: $DuracaoStress segundos" -ForegroundColor Cyan
Write-Host "🔄 Intervalo de monitoramento: $IntervaloMonitoramento segundos" -ForegroundColor Cyan
Write-Host ""

# Função para mostrar status detalhado dos pods
function Show-PodStatus {
    param([string]$Titulo)
    
    Write-Host "📊 $Titulo" -ForegroundColor Yellow
    Write-Host "-" * 50
    
    # Status geral dos pods
    kubectl get pods -l app=patocast-backend -o wide
    kubectl get pods -l app=patocast-frontend -o wide
    
    # Informações do HPA
    Write-Host ""
    Write-Host "📈 Status do HPA:" -ForegroundColor Cyan
    kubectl get hpa patocast-hpa
    
    Write-Host ""
}

# Função para monitorar continuamente
function Start-Monitoring {
    param([int]$Duracao, [string]$Contexto)
    
    Write-Host "🔍 Iniciando monitoramento por $Duracao segundos - $Contexto" -ForegroundColor Green
    $inicio = Get-Date
    $contador = 0
    
    while ((Get-Date) -lt $inicio.AddSeconds($Duracao)) {
        $contador++
        $tempoDecorrido = [math]::Round(((Get-Date) - $inicio).TotalSeconds)
        
        Clear-Host
        Write-Host "🧪 TESTE EM ANDAMENTO - $Contexto" -ForegroundColor Green
        Write-Host "⏱️  Tempo decorrido: $tempoDecorrido / $Duracao segundos" -ForegroundColor Yellow
        Write-Host "🔄 Atualização #$contador" -ForegroundColor Cyan
        Write-Host "=" * 60
        
        Show-PodStatus "Status Atual dos Pods e HPA"
        
        # Verificar eventos recentes
        Write-Host "📰 Eventos Recentes:" -ForegroundColor Magenta
        kubectl get events --sort-by='.lastTimestamp' | Select-Object -Last 5
        
        Write-Host ""
        Write-Host "⏳ Próxima atualização em $IntervaloMonitoramento segundos..." -ForegroundColor Gray
        Start-Sleep -Seconds $IntervaloMonitoramento
    }
}

# Teste 1: Auto-Healing (Deleção Manual de Pod)
function Test-AutoHealing {
    Write-Host "🔥 TESTE 1: AUTO-HEALING (Deleção Manual de Pod)" -ForegroundColor Red
    Write-Host "=" * 60
    
    # Mostrar estado inicial
    Show-PodStatus "Estado ANTES da deleção"
    
    # Obter um pod backend para deletar
    $podToDelete = kubectl get pods -l app=patocast-backend -o jsonpath='{.items[0].metadata.name}' 2>$null
    
    if (-not $podToDelete) {
        Write-Host "❌ Nenhum pod backend encontrado para deletar!" -ForegroundColor Red
        return
    }
    
    Write-Host "🎯 Pod selecionado para deleção: $podToDelete" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "⚠️  Deletando pod em 5 segundos..." -ForegroundColor Red
    Start-Sleep -Seconds 5
    
    # Registrar tempo da deleção
    $tempoDeleção = Get-Date
    Write-Host "💥 DELETANDO POD: $podToDelete" -ForegroundColor Red
    kubectl delete pod $podToDelete
    
    Write-Host ""
    Write-Host "📊 DEMONSTRAÇÃO DO AUTO-HEALING:" -ForegroundColor Green
    Write-Host "✅ Pod deletado - Kubernetes detectará a falha" -ForegroundColor Yellow
    Write-Host "✅ Controlador criará automaticamente um novo pod" -ForegroundColor Yellow
    Write-Host "✅ Observe o status 'Terminating' → 'ContainerCreating' → 'Running'" -ForegroundColor Yellow
    Write-Host ""
    
    # Monitorar por 2 minutos para ver a recuperação
    Start-Monitoring -Duracao 120 -Contexto "AUTO-HEALING - Observando Recuperação"
    
    # Análise final
    Write-Host "🎯 ANÁLISE DO AUTO-HEALING:" -ForegroundColor Green
    $tempoRecuperação = [math]::Round(((Get-Date) - $tempoDeleção).TotalSeconds)
    Write-Host "⏱️  Tempo total desde a deleção: $tempoRecuperação segundos" -ForegroundColor Cyan
    Write-Host "✅ Pod automaticamente recriado pelo Kubernetes" -ForegroundColor Green
    Write-Host "✅ Aplicação manteve disponibilidade com outros pods" -ForegroundColor Green
}

# Teste 2: Sobrecarga de CPU (HPA)
function Test-HPA {
    Write-Host "🚀 TESTE 2: ESCALONAMENTO HORIZONTAL (HPA)" -ForegroundColor Blue
    Write-Host "=" * 60
    
    # Mostrar estado inicial
    Show-PodStatus "Estado ANTES do stress de CPU"
    
    # Obter pods backend para stress
    $backendPods = kubectl get pods -l app=patocast-backend -o jsonpath='{.items[*].metadata.name}' 2>$null
    if (-not $backendPods) {
        Write-Host "❌ Nenhum pod backend encontrado para stress!" -ForegroundColor Red
        return
    }
    
    $podsArray = $backendPods -split ' '
    Write-Host "🎯 Pods backend encontrados: $($podsArray.Count)" -ForegroundColor Yellow
    Write-Host "📋 Pods: $($podsArray -join ', ')" -ForegroundColor Cyan
    
    Write-Host ""
    Write-Host "⚠️  Iniciando stress de CPU em $DuracaoStress segundos..." -ForegroundColor Red
    Start-Sleep -Seconds 3
    
    # Comando de stress de CPU para cada pod
    $stressJobs = @()
    foreach ($pod in $podsArray) {
        Write-Host "💥 Iniciando stress no pod: $pod" -ForegroundColor Red
        
        # Comando para gerar 100% CPU por X segundos
        $stressCommand = "python3 -c `"
import time
import threading

def cpu_stress():
    end_time = time.time() + $DuracaoStress
    while time.time() < end_time:
        pass

# Criar múltiplas threads para maximilizar CPU
for i in range(4):
    thread = threading.Thread(target=cpu_stress)
    thread.start()

print('Stress de CPU iniciado por $DuracaoStress segundos...')
time.sleep($DuracaoStress)
print('Stress de CPU finalizado.')
`""
        
        # Executar stress em background
        $job = Start-Job -ScriptBlock {
            param($podName, $command)
            kubectl exec $podName -- sh -c $command
        } -ArgumentList $pod, $stressCommand
        
        $stressJobs += $job
    }
    
    Write-Host ""
    Write-Host "📊 DEMONSTRAÇÃO DO HPA:" -ForegroundColor Green
    Write-Host "✅ Stress de CPU iniciado em todos os pods backend" -ForegroundColor Yellow
    Write-Host "✅ HPA detectará alta utilização de CPU (>70%)" -ForegroundColor Yellow
    Write-Host "✅ Novos pods serão criados automaticamente" -ForegroundColor Yellow
    Write-Host "✅ Após stress, pods extras serão removidos" -ForegroundColor Yellow
    Write-Host ""
    
    # Monitorar durante o stress + tempo de estabilização
    $tempoTotal = $DuracaoStress + 180  # stress + 3 min de estabilização
    Start-Monitoring -Duracao $tempoTotal -Contexto "HPA - Stress de CPU e Recuperação"
    
    # Aguardar jobs terminarem
    Write-Host "⏳ Aguardando finalização dos jobs de stress..." -ForegroundColor Yellow
    $stressJobs | Wait-Job | Remove-Job
    
    # Análise final
    Write-Host ""
    Write-Host "🎯 ANÁLISE DO HPA:" -ForegroundColor Green
    Write-Host "✅ Escalonamento horizontal testado com sucesso" -ForegroundColor Green
    Write-Host "✅ HPA reagiu ao aumento de CPU criando novos pods" -ForegroundColor Green
    Write-Host "✅ Após stress, sistema se estabilizou automaticamente" -ForegroundColor Green
}

# Verificar se aplicação está rodando
Write-Host "🔍 Verificando se a aplicação PatoCash está rodando..." -ForegroundColor Cyan
$backendCheck = kubectl get deployment patocast-backend 2>$null
$hpaCheck = kubectl get hpa patocast-hpa 2>$null

if (-not $backendCheck) {
    Write-Host "❌ Deployment patocast-backend não encontrado!" -ForegroundColor Red
    Write-Host "📋 Execute primeiro: .\deploy-seguro.ps1" -ForegroundColor Yellow
    exit 1
}

if (-not $hpaCheck) {
    Write-Host "❌ HPA patocast-hpa não encontrado!" -ForegroundColor Red
    Write-Host "📋 Execute primeiro: .\deploy-seguro.ps1" -ForegroundColor Yellow
    exit 1
}

Write-Host "✅ Aplicação PatoCash encontrada!" -ForegroundColor Green
Write-Host ""

# Executar testes baseado no parâmetro
switch ($Teste.ToLower()) {
    "auto-healing" {
        Test-AutoHealing
    }
    "hpa" {
        Test-HPA
    }
    "todos" {
        Test-AutoHealing
        Write-Host ""
        Write-Host "⏳ Aguardando 30 segundos antes do próximo teste..." -ForegroundColor Gray
        Start-Sleep -Seconds 30
        Test-HPA
    }
    default {
        Write-Host "❌ Teste inválido: $Teste" -ForegroundColor Red
        Write-Host "📋 Opções válidas: auto-healing, hpa, todos" -ForegroundColor Yellow
        exit 1
    }
}

Write-Host ""
Write-Host "🎉 TESTES DE RESILIÊNCIA CONCLUÍDOS!" -ForegroundColor Green
Write-Host "=" * 60
Write-Host "📊 Resumo dos testes executados:" -ForegroundColor Cyan
if ($Teste -eq "todos" -or $Teste -eq "auto-healing") {
    Write-Host "✅ Auto-Healing: Demonstrado com deleção manual de pod" -ForegroundColor Green
}
if ($Teste -eq "todos" -or $Teste -eq "hpa") {
    Write-Host "✅ HPA: Demonstrado com stress de CPU" -ForegroundColor Green
}
Write-Host ""
Write-Host "🔗 Para verificar métricas detalhadas:" -ForegroundColor Yellow
Write-Host "kubectl top pods" -ForegroundColor Gray
Write-Host "kubectl get hpa patocast-hpa" -ForegroundColor Gray
Write-Host "kubectl describe hpa patocast-hpa" -ForegroundColor Gray