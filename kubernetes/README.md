# PatoCash - Kubernetes Deployment

Este projeto contem o deployment da aplicacao PatoCash no Kubernetes com monitoramento Prometheus.

## Estrutura do Projeto

`
kubernetes/
â”œâ”€â”€ configs/           # Arquivos de configuracao (.env, secrets)
â”œâ”€â”€ manifests/         # Manifestos Kubernetes da aplicacao
â”‚   â”œâ”€â”€ k8s-configmap.yaml
â”‚   â”œâ”€â”€ k8s-frontend.yaml
â”‚   â”œâ”€â”€ k8s-backend.yaml
â”‚   â”œâ”€â”€ k8s-postgres.yaml
â”‚   â””â”€â”€ k8s-hpa.yaml
â””â”€â”€ monitoring/        # Monitoramento com Prometheus
    â”œâ”€â”€ prometheus-configmap.yaml
    â””â”€â”€ prometheus-deployment.yaml

scripts/
â”œâ”€â”€ deployment/        # Scripts de deployment
â””â”€â”€ testing/          # Scripts de teste
    â”œâ”€â”€ teste-completo-zero.ps1
    â””â”€â”€ teste-resiliencia.ps1
`

## Como usar

1. **Executar deploy completo:**
   `powershell
   .\teste-completo.ps1
   `

2. **Acessar aplicacao:**
   `powershell
   # Via port-forward (recomendado)
   kubectl port-forward service/patocast-frontend-service 3000:3000
   
   # Abrir no navegador: http://localhost:3000
   `

3. **Monitorar aplicacao:**
   `powershell
   # Status dos pods
   kubectl get pods,svc,hpa
   
   # Metricas de CPU/Memoria
   kubectl top pods
   
   # Logs da aplicacao
   kubectl logs -l app=patocast-frontend
   `

4. **Acessar Prometheus:**
   `powershell
   kubectl port-forward -n monitoring service/prometheus-service 9090:9090
   # Abrir no navegador: http://localhost:9090
   `

## Testes de Resiliencia

Execute os testes de falhas e recuperacao:
`powershell
.\scripts\testing\teste-resiliencia.ps1
`

## Requisitos

- Docker Desktop
- Minikube
- kubectl
- PowerShell 5.1+

## URLs de Acesso

- **Frontend:** http://localhost:3000 (via port-forward)
- **Backend:** http://localhost:5000 (via port-forward)  
- **Prometheus:** http://localhost:9090 (via port-forward)
- **Postgres:** localhost:5432 (via port-forward)
