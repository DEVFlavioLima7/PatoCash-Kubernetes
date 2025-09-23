# ⚙️ Configurações Kubernetes

## 📁 Estrutura

```
kubernetes/
├── manifests/           # Deployments, Services, HPA
│   ├── k8s-backend.yaml      # Backend Flask (2-6 pods)
│   ├── k8s-frontend.yaml     # Frontend Node.js (2 pods)
│   ├── k8s-postgres.yaml     # PostgreSQL + scripts
│   ├── k8s-configmap.yaml    # Configurações não sensíveis
│   └── k8s-hpa.yaml         # Auto-scaling rules
└── configs/             # Configurações e exemplos
    └── .env-exemplo          # Template de configuração
```

## 🚀 Deploy Rápido

```powershell
# Deploy completo
..\scripts\deployment\deploy-seguro.ps1

# Apenas manifests
kubectl apply -f manifests/

# Aplicar específico
kubectl apply -f manifests/k8s-backend.yaml
```

## 📋 Manifests Disponíveis

| Arquivo | Descrição | Réplicas | Porta |
|---------|-----------|----------|-------|
| `k8s-backend.yaml` | API Flask + Python | 2-6 (HPA) | 5000 |
| `k8s-frontend.yaml` | Node.js + Express | 2 fixas | 3000 |
| `k8s-postgres.yaml` | PostgreSQL + Scripts SQL | 1 | 5432 |
| `k8s-configmap.yaml` | Configurações não sensíveis | - | - |
| `k8s-hpa.yaml` | Auto-scaling (CPU 70%) | - | - |

## 🔧 Comandos Úteis

```powershell
# Ver status dos pods
kubectl get pods -l app=patocast-backend,app=patocast-frontend

# Verificar HPA
kubectl get hpa patocast-hpa

# Logs dos pods
kubectl logs -l app=patocast-backend --tail=50

# Escalar manualmente
kubectl scale deployment patocast-backend --replicas=4

# Aplicar mudanças
kubectl apply -f manifests/
```

## 🛡️ Segurança

- ✅ **Secrets**: Criados dinamicamente do arquivo `.env`
- ✅ **ConfigMaps**: Apenas dados não sensíveis
- ✅ **RBAC**: Permissões mínimas necessárias
- ✅ **Health Checks**: Liveness e readiness probes

## 📊 Monitoramento

```powershell
# Recursos em tempo real
kubectl top pods

# Eventos recentes
kubectl get events --sort-by='.lastTimestamp'

# Descrição detalhada
kubectl describe deployment patocast-backend
kubectl describe hpa patocast-hpa
```