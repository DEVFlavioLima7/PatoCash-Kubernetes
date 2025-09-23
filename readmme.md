JonasCGN: pOR ALGUM MOTIVO TA DEMORANDO MUITO PRA RODAR

Workspace: Collecting workspace informationBaseado no seu projeto **Patocast** e nos requisitos, vou te dar um passo a passo **otimizado e mais rápido** para fazer o deploy no Kubernetes. O problema é que o notebook está usando muitos `time.sleep()` desnecessários.

## 📋 **Passo a Passo Otimizado - Deploy Kubernetes**

### 🚀 **1. Preparação Rápida do Ambiente**

Abra o **PowerShell como Administrador**:

```bash
# Limpar ambiente anterior (se necessário)
minikube delete

# Iniciar cluster com recursos otimizados
minikube start --cpus=2 --memory=4096 --driver=docker

# Habilitar metrics server para HPA
minikube addons enable metrics-server

# Verificar se está funcionando
kubectl get nodes
```

### 🐳 **2. Construir Imagens Docker Rapidamente**

```bash
# Ir para sua pasta do projeto
cd "C:\Users\jonas\Documents\Universadade\Codigos Curso\WEB\WEB-I-TELA_HOME-HTML"

# Configurar Docker do Minikube
minikube docker-env | Invoke-Expression

# Construir imagens em paralelo (mais rápido)
docker build -t patocast-backend:latest ./backend &
docker build -t patocast-frontend:latest ./front &

# Aguardar conclusão
Wait-Job *

# Verificar imagens
docker images | Select-String patocast
```

### 📄 **3. Criar Manifestos Kubernetes (Simples e Rápido)**

Crie estes arquivos na pasta raiz:

**`k8s-backend.yaml`:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: patocast-backend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: patocast-backend
  template:
    metadata:
      labels:
        app: patocast-backend
    spec:
      containers:
      - name: flask-app
        image: patocast-backend:latest
        imagePullPolicy: Never
        ports:
        - containerPort: 5000
        resources:
          requests:
            cpu: 50m
            memory: 128Mi
          limits:
            cpu: 200m
            memory: 256Mi
        livenessProbe:
          httpGet:
            path: /
            port: 5000
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /
            port: 5000
          initialDelaySeconds: 10
          periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: patocast-backend-service
spec:
  selector:
    app: patocast-backend
  ports:
    - port: 5000
      targetPort: 5000
```

**`k8s-frontend.yaml`:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: patocast-frontend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: patocast-frontend
  template:
    metadata:
      labels:
        app: patocast-frontend
    spec:
      containers:
      - name: nodejs-app
        image: patocast-frontend:latest
        imagePullPolicy: Never
        ports:
        - containerPort: 3000
        env:
        - name: HOST_BACKEND
          value: "patocast-backend-service"
        - name: PORT_BACKEND
          value: "5000"
        resources:
          requests:
            cpu: 50m
            memory: 128Mi
          limits:
            cpu: 200m
            memory: 256Mi
        livenessProbe:
          httpGet:
            path: /
            port: 3000
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /
            port: 3000
          initialDelaySeconds: 10
          periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: patocast-frontend-service
spec:
  selector:
    app: patocast-frontend
  ports:
    - port: 3000
      targetPort: 3000
      nodePort: 30080
  type: NodePort
```

**`k8s-hpa.yaml`:**
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: patocast-backend-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: patocast-backend
  minReplicas: 2
  maxReplicas: 5
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
---
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: patocast-frontend-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: patocast-frontend
  minReplicas: 2
  maxReplicas: 4
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
```

### 🚀 **4. Deploy Rápido (SEM ESPERAS LONGAS)**

```bash
# Deploy tudo de uma vez (mais rápido)
kubectl apply -f k8s-backend.yaml
kubectl apply -f k8s-frontend.yaml

# Aguardar pods estarem rodando (comando mais eficiente)
kubectl wait --for=condition=ready pod -l app=patocast-backend --timeout=120s
kubectl wait --for=condition=ready pod -l app=patocast-frontend --timeout=120s

# Aplicar HPA (depois que os pods estão rodando)
kubectl apply -f k8s-hpa.yaml

# Verificar tudo de uma vez
kubectl get all
```

### 🧪 **5. Testes Rápidos**

```bash
# TESTE 1: Verificar pods
kubectl get pods

# TESTE 2: Verificar HPA
kubectl get hpa

# TESTE 3: Testar auto-healing (deletar um pod)
kubectl delete pod $(kubectl get pods -l app=patocast-backend -o jsonpath='{.items[0].metadata.name}')

# Verificar se novo pod foi criado
kubectl get pods -l app=patocast-backend

# TESTE 4: Teste de carga simplificado
kubectl run load-generator --image=busybox --restart=Never -- /bin/sh -c "while true; do wget -q -O- http://patocast-backend-service:5000/ || true; done"

# Monitorar HPA por 2 minutos
for i in {1..4}; do echo "=== Minuto $i ==="; kubectl get hpa; kubectl top pods; sleep 30; done
```

### 🌐 **6. Acessar a Aplicação**

```bash
# Obter URL da aplicação
minikube service patocast-frontend-service --url

# OU obter IP e acessar manualmente
minikube ip
# Acesse: http://[IP_DO_MINIKUBE]:30080
```

## 🎯 **Por que é mais rápido?**

1. **Sem esperas desnecessárias**: Removemos os `time.sleep(90)` e `time.sleep(60)`
2. **Build paralelo**: Constrói ambas as imagens ao mesmo tempo
3. **Deploy simultâneo**: Aplica todos os manifestos de uma vez
4. **Kubectl wait**: Usa comando nativo do Kubernetes para aguardar pods
5. **Recursos otimizados**: CPU/memória menores para desenvolvimento
6. **Sem PostgreSQL**: Simplifica o teste (pode adicionar depois se necessário)

## ✅ **Resultado Esperado**

- ✅ **Cluster Minikube**: Funcionando
- ✅ **Múltiplos pods**: Backend e frontend com 2 réplicas cada
- ✅ **Auto-healing**: Health checks configurados
- ✅ **HPA**: Escalonamento automático baseado em CPU
- ✅ **Tempo total**: ~5-10 minutos (vs ~15-20 do notebook)

**🚀 Agora é só executar os comandos em sequência! Muito mais rápido que o notebook.**