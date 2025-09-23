# 🐳 PatoCash - Sistema Financeiro Kubernetes

[![Kubernetes](https://img.shields.io/badge/kubernetes-blue?style=for-the-badge&logo=kubernetes)](https://kubernetes.io/)
[![Docker](https://img.shields.io/badge/docker-blue?style=for-the-badge&logo=docker)](https://www.docker.com/)
[![Python](https://img.shields.io/badge/python-3.9+-green?style=for-the-badge&logo=python)](https://python.org/)
[![Node.js](https://img.shields.io/badge/node.js-green?style=for-the-badge&logo=node.js)](https://nodejs.org/)
[![PostgreSQL](https://img.shields.io/badge/postgresql-blue?style=for-the-badge&logo=postgresql)](https://postgresql.org/)

> Sistema completo de gerenciamento financeiro com deploy automatizado em Kubernetes

## 🚀 **Quick Start**

```powershell
# Clone e execute em qualquer PC
git clone https://github.com/JonasCGN/PatoCash-Kubernetes.git
cd PatoCash-Kubernetes
.\scripts\deployment\teste-completo-zero.ps1
```

**🌐 Acesso**: http://localhost:3000

## ✨ **Características**

- ✅ **Auto-healing**: Recuperação automática de falhas
- ✅ **HPA**: Escalonamento baseado em CPU (70%)
- ✅ **Segurança**: Secrets dinâmicos do .env
- ✅ **Multi-pods**: Frontend (2) + Backend (2-6)
- ✅ **Testes**: Automatizados de resiliência

## 📁 **Estrutura do Projeto**

```
PatoCash-Kubernetes/
├── 📱 front/                    # Frontend Node.js + Express
├── 🔧 backend/                  # Backend Flask + Python
├── 🗄️ banco_de_dados/           # Scripts SQL PostgreSQL
├── ⚙️ kubernetes/               # Configurações K8s
│   ├── manifests/              # Deployments, Services, HPA
│   └── configs/                # ConfigMaps, Secrets
├── 🚀 scripts/                  # Scripts automatizados
│   ├── deployment/             # Deploy e configuração
│   ├── tests/                  # Testes de resiliência
│   └── utils/                  # Utilitários
├── 📖 docs/                     # Documentação
└── 🔄 .github/                  # CI/CD workflows
```

## 🎯 **Como Usar**

### **Deploy Rápido**
```powershell
# 1. Configurar credenciais
Copy-Item kubernetes\configs\.env-exemplo .env
notepad .env  # Editar com suas credenciais

# 2. Deploy completo
.\scripts\deployment\deploy-seguro.ps1

# 3. Acesso automático em http://localhost:3000
```

### **Testes de Resiliência**
```powershell
# Teste completo automatizado
.\scripts\tests\teste-estresse.ps1

# Interface interativa
.\scripts\tests\testes-rapidos.ps1

# Teste específico
.\scripts\tests\teste-estresse.ps1 -Teste "auto-healing"
```

## 🏗️ **Arquitetura Kubernetes**

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   FRONTEND      │    │    BACKEND      │    │   POSTGRESQL    │
│   (Node.js)     │    │    (Flask)      │    │   (Database)    │
│                 │    │                 │    │                 │
│ • 2 réplicas    │◄──►│ • 2-6 réplicas  │◄──►│ • 1 instância   │
│ • Port 3000     │    │ • Auto-scaling  │    │ • Volume persist│
│ • LoadBalancer  │    │ • Health checks │    │ • Init scripts  │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         ▲                       ▲                       ▲
         │                       │                       │
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   CONFIGMAP     │    │      HPA        │    │    SECRETS      │
│ • Configurações │    │ • CPU: 70%      │    │ • Credenciais   │
│ • Não sensível  │    │ • Min: 2 pods   │    │ • Criptografado │
│                 │    │ • Max: 6 pods   │    │ • .env dinâmico │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## 🧪 **Demonstrações**

### **Auto-Healing**
- 💥 Deleta pod manualmente
- 🔄 Kubernetes recria automaticamente
- ⏱️ Recuperação em ~30-60 segundos
- 📊 Observa: Terminating → ContainerCreating → Running

### **HPA (Escalonamento Horizontal)**
- 🔥 Gera stress de CPU (>70%)
- 📈 HPA cria novos pods (2 → 6)
- ⏱️ Reação em 1-3 minutos
- 📉 Redução automática após estabilização

## 📋 **Links Rápidos**

| Quero... | Link |
|----------|------|
| 🚀 **Começar agora** | [`scripts/deployment/`](scripts/deployment/) |
| 🧪 **Testar resiliência** | [`scripts/tests/`](scripts/tests/) |
| ⚙️ **Ver configurações** | [`kubernetes/`](kubernetes/) |
| 📖 **Ler documentação** | [`docs/`](docs/) |
| 🔒 **Configurar segurança** | [`docs/SEGURANCA.md`](docs/SEGURANCA.md) |

## 📊 **Monitoramento**

```powershell
# Status geral
kubectl get pods,hpa,svc

# Utilização de recursos
kubectl top pods

# Events recentes
kubectl get events --sort-by='.lastTimestamp'

# Logs específicos
kubectl logs -l app=patocast-backend
```

## 🌐 **Endpoints**

- **Frontend**: http://localhost:3000
- **API Backend**: http://localhost:3000/api/*
- **Health Check**: http://localhost:3000/health
- **Rota de Teste**: http://localhost:3000/save_conta

## 🚀 **Recursos Kubernetes**

### **Deployments**
- **Backend**: 2-6 pods (auto-scaling)
- **Frontend**: 2 pods (fixo)
- **PostgreSQL**: 1 pod (persistente)

### **Services**
- **LoadBalancer** para distribuição de carga
- **ClusterIP** para comunicação interna
- **Port-forward** para acesso local

### **HPA (Horizontal Pod Autoscaler)**
- **Threshold**: 70% CPU
- **Min Replicas**: 2
- **Max Replicas**: 6
- **Scale-up**: 1-3 minutos
- **Scale-down**: 5-10 minutos

## 🔒 **Segurança**

- ✅ **Secrets dinâmicos** do arquivo `.env`
- ✅ **Nenhuma credencial hardcoded**
- ✅ **`.env` protegido** pelo `.gitignore`
- ✅ **Template seguro** com placeholders

## 📈 **Resultados Esperados**

### **Auto-Healing**
- ⏱️ Recuperação: 30-90 segundos
- 🔄 Pods mantidos: Sempre 2+ ativos
- 📈 Disponibilidade: 100% (outros pods atendem)

### **HPA**
- 📊 Threshold: 70% CPU
- ⚖️ Escala: 2 → 6 pods máximo
- ⏱️ Tempo reação: 1-3 minutos
- 📉 Redução: 5-10 minutos após stress

## 🎉 **Início Rápido Total**

```powershell
# 1. Clone o projeto
git clone https://github.com/JonasCGN/PatoCash-Kubernetes.git
cd PatoCash-Kubernetes

# 2. Teste completo do zero (recomendado para PC novo)
.\scripts\deployment\teste-completo-zero.ps1

# 3. Acesse a aplicação
start http://localhost:3000

# 4. Teste resiliência
.\scripts\tests\teste-estresse.ps1
```

## 🤝 **Contribuição**

1. Fork o projeto
2. Crie sua feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit suas mudanças (`git commit -m 'Add some AmazingFeature'`)
4. Push para a branch (`git push origin feature/AmazingFeature`)
5. Abra um Pull Request

## 📄 **Licença**

Este projeto está sob a licença MIT. Veja o arquivo [LICENSE](LICENSE) para detalhes.

---

**🎯 Em menos de 10 minutos você terá um sistema financeiro completo rodando no Kubernetes com auto-healing e escalonamento automático!** 🚀

⭐ **Deixe uma estrela se este projeto te ajudou!**