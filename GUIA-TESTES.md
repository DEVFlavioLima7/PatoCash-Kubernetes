# 🧪 Guia de Testes de Resiliência - PatoCash

Este documento explica como executar os testes de **Auto-Healing** e **HPA (Horizontal Pod Autoscaler)** para demonstrar os mecanismos de resiliência do Kubernetes.

## 📋 Pré-requisitos

1. ✅ Aplicação PatoCash deployada (`.\deploy-seguro.ps1`)
2. ✅ HPA configurado e funcionando
3. ✅ Metrics Server habilitado no Minikube
4. ✅ Pods backend e frontend rodando

## 🎯 Opções de Teste

### 🔥 **Opção 1: Teste Completo Automatizado**

Execute o script principal que faz tudo automaticamente:

```powershell
# Executar todos os testes (recomendado)
.\teste-estresse.ps1

# Ou testes específicos:
.\teste-estresse.ps1 -Teste "auto-healing"
.\teste-estresse.ps1 -Teste "hpa" -DuracaoStress 240
```

**Parâmetros disponíveis:**
- `-Teste`: "auto-healing", "hpa", "todos" (padrão: "todos")
- `-DuracaoStress`: Duração do stress em segundos (padrão: 300)
- `-IntervaloMonitoramento`: Intervalo entre verificações (padrão: 5)

### 🎮 **Opção 2: Testes Interativos**

Para controle manual e testes específicos:

```powershell
.\testes-rapidos.ps1
```

**Menu interativo com opções:**
- 1️⃣ Deletar Pod (Auto-Healing)
- 2️⃣ Stress CPU (HPA)  
- 3️⃣ Status Atual
- 4️⃣ Escalar Manualmente
- 5️⃣ Reset Completo

## 📊 **Teste 1: Auto-Healing (Deleção Manual de Pod)**

### O que o teste faz:
1. 🎯 Identifica um pod backend ativo
2. 💥 Deleta o pod manualmente
3. 👁️ Monitora a recuperação automática
4. 📈 Mostra métricas e eventos

### O que você vai observar:
- ✅ **Status "Terminating"**: Pod sendo removido
- ✅ **Status "ContainerCreating"**: Novo pod sendo criado
- ✅ **Status "Running"**: Novo pod operacional
- ✅ **Tempo de recuperação**: Geralmente 30-60 segundos
- ✅ **Eventos do Kubernetes**: Logs da recuperação

### Comandos para verificação manual:
```powershell
# Ver status dos pods em tempo real
kubectl get pods -l app=patocast-backend -w

# Ver eventos de recuperação
kubectl get events --sort-by='.lastTimestamp'

# Verificar deployment
kubectl describe deployment patocast-backend
```

## 🚀 **Teste 2: HPA (Escalonamento Horizontal)**

### O que o teste faz:
1. 🔥 Gera carga de CPU artificial nos pods backend
2. 📊 Monitora o aumento da utilização de CPU
3. ⚖️ Observa o HPA criando novos pods automaticamente
4. 📉 Verifica a redução após estabilização

### O que você vai observar:
- ✅ **CPU alta**: Utilização acima de 70% (threshold do HPA)
- ✅ **Criação de pods**: HPA escala de 2 para até 6 pods
- ✅ **Tempo de reação**: HPA reage em 1-3 minutos
- ✅ **Estabilização**: Redução automática após stress

### Comandos para verificação manual:
```powershell
# Monitorar HPA em tempo real
kubectl get hpa patocast-hpa -w

# Ver utilização de CPU dos pods
kubectl top pods -l app=patocast-backend

# Verificar número de réplicas
kubectl get deployment patocast-backend

# Eventos do HPA
kubectl describe hpa patocast-hpa
```

## 📈 **Métricas e Observabilidade**

### Verificações importantes durante os testes:

```powershell
# 1. Status geral
kubectl get pods -l app=patocast-backend,app=patocast-frontend

# 2. HPA detalhado
kubectl describe hpa patocast-hpa

# 3. Utilização de recursos
kubectl top pods

# 4. Eventos recentes
kubectl get events --sort-by='.lastTimestamp' | Select-Object -Last 10

# 5. Logs de um pod específico
kubectl logs -l app=patocast-backend --tail=50
```

## 🎯 **Demonstrações Específicas**

### Para demonstrar **Auto-Healing**:
```powershell
# Obter nome do pod
$pod = kubectl get pods -l app=patocast-backend -o jsonpath='{.items[0].metadata.name}'

# Deletar e monitorar
kubectl delete pod $pod; kubectl get pods -l app=patocast-backend -w
```

### Para demonstrar **HPA**:
```powershell
# Stress manual simples
kubectl exec deployment/patocast-backend -- python3 -c "
import time
end = time.time() + 300
while time.time() < end:
    x = 1000000 ** 2
"

# Monitorar em outra janela
kubectl get hpa patocast-hpa -w
```

## ⚠️ **Dicas Importantes**

### ✅ **Antes dos testes:**
- Verifique se metrics-server está rodando: `kubectl get apiservice v1beta1.metrics.k8s.io`
- Confirme que HPA está ativo: `kubectl get hpa`
- Teste conectividade: `kubectl top pods`

### ✅ **Durante os testes:**
- Use múltiplos terminais para monitoramento simultâneo
- Anote horários para correlacionar eventos
- Tire screenshots das métricas para documentação

### ✅ **Solução de problemas:**
```powershell
# Se HPA não funcionar
minikube addons enable metrics-server
kubectl rollout restart deployment patocast-backend

# Se pods não subirem
kubectl describe pod <pod-name>
kubectl logs <pod-name>

# Reset completo se necessário
kubectl rollout restart deployment patocast-backend patocast-frontend
```

## 📊 **Resultados Esperados**

### **Auto-Healing:**
- ⏱️ Recuperação: 30-90 segundos
- 🔄 Pods mantidos: Sempre 2+ ativos
- 📈 Disponibilidade: 100% (outros pods atendem)

### **HPA:**
- 📊 Threshold: 70% CPU
- ⚖️ Escala: 2 → 6 pods máximo
- ⏱️ Tempo reação: 1-3 minutos
- 📉 Redução: 5-10 minutos após stress

---

**🎯 Objetivo**: Demonstrar que o Kubernetes garante **resiliência** e **escalabilidade** automática da aplicação PatoCash!