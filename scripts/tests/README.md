# 🐍 PatoCash Python Stress Tests

Testes de stress inteligentes para Kubernetes HPA e auto-healing usando Python com threads nativas.

## 🚀 Instalação

```bash
cd scripts/tests
pip install -r requirements.txt
```

## 📋 Comandos Disponíveis

### Teste HPA (Horizontal Pod Autoscaler)
```bash
python stress_test.py --test hpa --duration 60
```

### Teste Auto-Healing 
```bash
python stress_test.py --test auto-healing
```

### Executar Todos os Testes
```bash
python stress_test.py --test all --duration 45
```

### Personalizar URL do Serviço
```bash
python stress_test.py --test hpa --url http://localhost:8080
```

## 🎯 Funcionalidades

### ✅ Teste HPA
- **12 threads HTTP** bombardeando múltiplos endpoints
- **Stress CPU direto nos pods** via kubectl exec
- **Monitoramento em tempo real** com interface atualizada
- **Detecção automática de scaling**
- **Relatório final** com métricas completas

### ✅ Teste Auto-Healing
- **Deleta pod** aleatório do backend
- **Monitora recuperação** automática
- **Cronometra tempo** de healing
- **Valida estado final**

### ✅ Interface Rica
- Status em tempo real com limpeza de tela
- Contadores de requests HTTP
- CPU usage por pod
- Progresso do HPA (2%/50%)
- Alertas visuais por estado

### ✅ Thread Safety
- Locks para contadores compartilhados
- Workers independentes
- Graceful shutdown com timeout
- Exception handling robusto

## 📊 Output Exemplo

```
============================================================
🎯 PATOCASH KUBERNETES STRESS TEST
============================================================
⏱️  Tempo: 23s / 45s
🔥 HTTP Requests: 15,847
⚡ CPU Stress: ATIVO

📊 HPA STATUS:
   CPU Atual: 67% (Target: 50%)
   Pods: 3 (Max visto: 3)
   Scaling: ✅ DETECTADO

💻 CPU por Pod (milicores):
   Pod 1: 145m 🔥 ALTO
   Pod 2: 98m 📈 SUBINDO
   Pod 3: 23m 💤 BAIXO

🚨 CPU MUITO ALTA (67%) - SCALING IMINENTE!
============================================================
```

## 🔧 Vantagens vs PowerShell

1. **Threads nativas** → Muito mais eficiente
2. **Monitoramento inteligente** → Subprocess para kubectl
3. **Interface rica** → Status visual em tempo real  
4. **Exception handling** → Robusto para ambientes instáveis
5. **Métricas detalhadas** → Contadores por thread
6. **Cross-platform** → Funciona em Windows/Linux/Mac
7. **Customização fácil** → Parâmetros via argparse

## 🎓 Para Trabalho Acadêmico

O script gera **evidências claras** para demonstrar:
- ✅ HPA funcionando (scaling automático)
- ✅ Auto-healing funcionando (recuperação de pods)
- ✅ Métricas do Prometheus (via kubectl)
- ✅ Timeline completa com timestamps

Perfeito para apresentação e relatórios! 🎯