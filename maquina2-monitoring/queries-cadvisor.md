# 📊 Queries cAdvisor TESTADAS e FUNCIONANDO - Máquina 2

## ✅ Queries de CPU (FUNCIONAM)

### 1. CPU por Pod patocast-backend (porcentagem)
```promql
sum by (pod, namespace) (rate(container_cpu_usage_seconds_total{pod=~"patocast-backend.*", container!="POD", container!=""}[1m])) * 100
```

### 2. CPU TOTAL patocast-backend (porcentagem)
```promql
sum(rate(container_cpu_usage_seconds_total{pod=~"patocast-backend.*", container!="POD", container!=""}[1m])) * 100
```

### 3. CPU por Pod patocast-frontend (porcentagem)
```promql
sum by (pod, namespace) (rate(container_cpu_usage_seconds_total{pod=~"patocast-frontend.*", container!="POD", container!=""}[1m])) * 100
```

### 4. CPU TOTAL patocast-frontend (porcentagem)
```promql
sum(rate(container_cpu_usage_seconds_total{pod=~"patocast-frontend.*", container!="POD", container!=""}[1m])) * 100
```

## ✅ Queries de Memória (FUNCIONAM)

### 5. Memória por Pod patocast-backend (MB)
```promql
sum by (pod, namespace) (container_memory_usage_bytes{pod=~"patocast-backend.*", container!="POD", container!=""}) / 1024 / 1024
```

### 6. Memória TOTAL patocast-backend (MB)
```promql
sum(container_memory_usage_bytes{pod=~"patocast-backend.*", container!="POD", container!=""}) / 1024 / 1024
```

### 7. Memória por Pod patocast-frontend (MB)
```promql
sum by (pod, namespace) (container_memory_usage_bytes{pod=~"patocast-frontend.*", container!="POD", container!=""}) / 1024 / 1024
```

## ✅ Queries de Contagem (FUNCIONAM)

### 8. Número de Replicas patocast-backend
```promql
count(count by (pod) (container_cpu_usage_seconds_total{pod=~"patocast-backend.*", container!="POD", container!=""}))
```

### 9. Número de Replicas patocast-frontend
```promql
count(count by (pod) (container_cpu_usage_seconds_total{pod=~"patocast-frontend.*", container!="POD", container!=""}))
```

## ✅ Queries Agregadas (FUNCIONAM)

### 10. Top 5 Pods com Maior CPU
```promql
topk(5, sum by (pod, namespace) (rate(container_cpu_usage_seconds_total{pod!="", container!="POD", container!=""}[1m])) * 100)
```

### 11. Top 5 Pods com Maior Memória
```promql
topk(5, sum by (pod, namespace) (container_memory_usage_bytes{pod!="", container!="POD", container!=""}) / 1024 / 1024)
```

### 12. CPU por Namespace
```promql
sum by (namespace) (rate(container_cpu_usage_seconds_total{pod!="", container!="POD", container!=""}[1m])) * 100
```

## 🚀 Recording Rules Simplificadas (USE ESTAS!)

### 13. CPU Backend (via recording rule)
```promql
patocash:backend_cpu_usage_percent
```

### 14. CPU Total Backend (via recording rule)
```promql
patocash:backend_total_cpu_percent
```

### 15. Memória Backend (via recording rule)
```promql
patocash:backend_memory_usage_mb
```

### 16. Memória Total Backend (via recording rule)
```promql
patocash:backend_total_memory_mb
```

### 17. Contagem de Replicas (via recording rule)
```promql
patocash:backend_replica_count
```

### 18. HPA Replicas Atuais (via recording rule)
```promql
patocash:hpa_current_replicas
```

### 19. HPA Replicas Desejadas (via recording rule)
```promql
patocash:hpa_desired_replicas
```

## 🎯 Queries Dashboard - Copy & Paste

### Dashboard: CPU por Pod (formato table)
```promql
sort_desc(sum by (pod, namespace) (rate(container_cpu_usage_seconds_total{pod=~"patocast-backend.*", container!="POD", container!=""}[1m])) * 100)
```

### Dashboard: Memória por Pod (formato table)
```promql
sort_desc(sum by (pod, namespace) (container_memory_usage_bytes{pod=~"patocast-backend.*", container!="POD", container!=""}) / 1024 / 1024)
```

### Dashboard: Overview PatoCash
```promql
# CPU Total Backend
patocash:backend_total_cpu_percent

# Memória Total Backend  
patocash:backend_total_memory_mb

# Replicas Ativas
patocash:backend_replica_count

# HPA Status
patocash:hpa_current_replicas
```

## 📋 Como Usar

1. **Prometheus UI**: http://localhost:9090
2. **Cole a query** no campo de consulta
3. **Execute** para ver resultados
4. **Graph tab** para gráficos

## ⚠️ Filtros Essenciais (NÃO REMOVA!)

- `container!="POD"` → Remove containers de infraestrutura
- `container!=""` → Remove containers sem nome  
- `pod=~"patocast-backend.*"` → Filtra pods do backend
- `[1m]` → Janela de tempo para rate()

## 🔥 Queries Mais Usadas (Top 5)

1. **CPU Backend por Pod**: `patocash:backend_cpu_usage_percent`
2. **CPU Total Backend**: `patocash:backend_total_cpu_percent`
3. **Memória Backend**: `patocash:backend_memory_usage_mb`
4. **Replicas Backend**: `patocash:backend_replica_count`
5. **HPA Status**: `patocash:hpa_current_replicas`

**💡 DICA**: Use as recording rules (patocash:*) - são mais rápidas e confiáveis!