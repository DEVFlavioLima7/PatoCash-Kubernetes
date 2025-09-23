# PatoCash - Sistema Financeiro Kubernetes 🐳

![Kubernetes](https://img.shields.io/badge/kubernetes-blue?style=for-the-badge&logo=kubernetes)
![Docker](https://img.shields.io/badge/docker-blue?style=for-the-badge&logo=docker)
![Python](https://img.shields.io/badge/python-3.9+-green?style=for-the-badge&logo=python)
![Node.js](https://img.shields.io/badge/node.js-green?style=for-the-badge&logo=node.js)
![PostgreSQL](https://img.shields.io/badge/postgresql-blue?style=for-the-badge&logo=postgresql)

Sistema completo de gerenciamento financeiro deployado em **Kubernetes** com **auto-healing**, **escalonamento horizontal (HPA)** e **segurança avançada**.

## 🚀 **Deploy Rápido (PC Novo)**

Para testar em qualquer PC do zero:

```powershell
# Clone o repositório
git clone https://github.com/JonasCGN/WEB-I-TELA_HOME-HTML.git
cd WEB-I-TELA_HOME-HTML

# Execute o teste completo
.\teste-completo-zero.ps1
```

**Pronto!** 🎉 Em ~5 minutos você terá:
- ✅ Cluster Kubernetes (Minikube)
- ✅ Aplicação com múltiplos pods
- ✅ Auto-healing configurado
- ✅ HPA baseado em CPU
- ✅ Acesso em http://localhost:3000

## 📋 **Pré-requisitos**

- 🐳 **Docker Desktop** (com Kubernetes habilitado)
- ⚙️ **Minikube** 
- 🔧 **kubectl**
- 💻 **PowerShell** (Windows)

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

## 🛠️ **Scripts Disponíveis**

### **Deploy e Configuração:**
- `📦 deploy-seguro.ps1` - Deploy completo com segurança
- `🔐 create-secret.ps1` - Criar Secrets do .env
- `🌐 acesso-app.ps1` - Port-forward para acesso
- `🧪 teste-completo-zero.ps1` - Teste do zero (PC novo)

### **Testes de Resiliência:**
- `🧪 teste-estresse.ps1` - Testes automatizados (auto-healing + HPA)
- `🎮 testes-rapidos.ps1` - Interface interativa
- `📖 GUIA-TESTES.md` - Documentação completa

### **Segurança:**
- `🔒 SEGURANCA.md` - Guia de segurança
- `📝 .env-exemplo-seguro` - Template de configuração

## 🎯 **Como Usar**

### 1. **Setup Inicial (PC Novo)**
```powershell
# Clonar e testar tudo do zero
git clone https://github.com/JonasCGN/WEB-I-TELA_HOME-HTML.git
cd WEB-I-TELA_HOME-HTML
.\teste-completo-zero.ps1
```

### 2. **Deploy Normal (PC Configurado)**
```powershell
# Configurar credenciais
Copy-Item .env-exemplo-seguro .env
notepad .env  # Editar com suas credenciais

# Deploy
.\deploy-seguro.ps1

# Acessar aplicação
# Vai abrir automaticamente http://localhost:3000
```

### 3. **Testes de Resiliência**
```powershell
# Teste completo automatizado
.\teste-estresse.ps1

# Ou testes interativos
.\testes-rapidos.ps1

# Teste específico
.\teste-estresse.ps1 -Teste "auto-healing"
.\teste-estresse.ps1 -Teste "hpa" -DuracaoStress 180
```

## 🔒 **Segurança**

### **Proteção de Credenciais:**
- ✅ Secrets dinâmicos do arquivo `.env`
- ✅ Nenhuma credencial hardcoded
- ✅ `.env` protegido pelo `.gitignore`
- ✅ Template seguro com placeholders

### **Configuração Segura:**
```powershell
# Criar .env com suas credenciais
Copy-Item .env-exemplo-seguro .env
notepad .env

# O script automaticamente cria os Secrets
.\deploy-seguro.ps1
```

## 🧪 **Demonstrações**

### **Auto-Healing:**
- 💥 Deleta pod manualmente
- 🔄 Kubernetes recria automaticamente
- ⏱️ Recuperação em ~30-60 segundos
- 📊 Observa status: Terminating → ContainerCreating → Running

### **HPA (Escalonamento Horizontal):**
- 🔥 Gera stress de CPU (>70%)
- 📈 HPA cria novos pods (2 → 6)
- ⏱️ Reação em 1-3 minutos
- 📉 Redução automática após estabilização

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

## 🌐 **Acesso**

- **Frontend**: http://localhost:3000
- **API Backend**: http://localhost:3000/api/*
- **Rota de Teste**: http://localhost:3000/save_conta

## 📁 **Estrutura do Projeto**

```
├── 📦 Scripts de Deploy
│   ├── deploy-seguro.ps1          # Deploy principal
│   ├── create-secret.ps1          # Criação de Secrets
│   ├── acesso-app.ps1            # Port-forward
│   └── teste-completo-zero.ps1   # Teste do zero
├── 🧪 Scripts de Teste
│   ├── teste-estresse.ps1        # Testes automatizados
│   ├── testes-rapidos.ps1        # Interface interativa
│   └── GUIA-TESTES.md           # Documentação
├── ⚙️ Manifests Kubernetes
│   ├── k8s-backend.yaml         # Backend deployment
│   ├── k8s-frontend.yaml        # Frontend deployment
│   ├── k8s-postgres.yaml        # Database
│   ├── k8s-configmap.yaml       # Configurações
│   └── k8s-hpa.yaml            # Auto-scaling
├── 🔒 Segurança
│   ├── .env-exemplo-seguro      # Template
│   └── SEGURANCA.md            # Guia
├── 🐳 Aplicação
│   ├── backend/                # API Flask
│   ├── front/                  # Frontend Node.js
│   └── banco_de_dados/         # Scripts SQL
└── 📖 Documentação
    ├── README.md               # Este arquivo
    └── cluster-kubernetes-notebook.ipynb
```

## 🚀 **Recursos Kubernetes**

### **Deployments:**
- **Backend**: 2-6 pods (auto-scaling)
- **Frontend**: 2 pods (fixo)
- **PostgreSQL**: 1 pod (persistente)

### **Services:**
- **LoadBalancer** para distribuição de carga
- **ClusterIP** para comunicação interna
- **Port-forward** para acesso local

### **Auto-Healing:**
- **Health Checks**: liveness e readiness probes
- **Restart Policy**: Always
- **Automatic Recovery**: <60 segundos

### **HPA (Horizontal Pod Autoscaler):**
- **Threshold**: 70% CPU
- **Min Replicas**: 2
- **Max Replicas**: 6
- **Scale-up**: 1-3 minutos
- **Scale-down**: 5-10 minutos

## 🎉 **Início Rápido**

```powershell
# 1. Clone o projeto
git clone https://github.com/JonasCGN/WEB-I-TELA_HOME-HTML.git
cd WEB-I-TELA_HOME-HTML

# 2. Teste completo do zero
.\teste-completo-zero.ps1

# 3. Acesse a aplicação
# http://localhost:3000

# 4. Teste resiliência
.\teste-estresse.ps1
```

**🎯 Em menos de 10 minutos você terá um sistema financeiro completo rodando no Kubernetes com auto-healing e escalonamento automático!** 🚀
* `/frontend`: Contém o código-fonte da aplicação frontend (Node.js/Express).
  * `server.js`: Ponto de entrada da aplicação frontend.
  * `package.json`: Define as dependências Node.js e scripts.
  * `public/`: Arquivos estáticos (CSS, JavaScript do lado do cliente, imagens, assets).
  * `src/views/`: Templates Nunjucks para as páginas HTML.
  * `dockerfile`: Instruções para construir a imagem Docker do frontend.
* `/banco_de_dados`: Contém os scripts SQL para inicialização do banco.
  * `init.sql`: Script para criação de tabelas.
  * `insersao_user.sql`: Script para inserção de dados iniciais (possivelmente usuários de teste).
* `docker-compose.yml`: Arquivo de orquestração para iniciar todos os serviços (frontend, backend, postgres) com Docker Compose.
* `makefile`: Contém comandos de atalho para facilitar a execução e gerenciamento do ambiente Docker.
* `.env` (Necessário criar): Arquivo para armazenar as variáveis de ambiente do backend ao rodar com Docker (veja a seção de Configuração).

## Pré-requisitos

Existem duas maneiras principais de executar o projeto: utilizando Docker (recomendado) ou manualmente.

**Para execução com Docker (Recomendado):**

* **Docker:** Instale o Docker Engine em seu sistema.
* **Docker Compose:** Instale o Docker Compose (geralmente incluído nas instalações mais recentes do Docker Desktop).

**Para execução Manual:**

* **Node.js e npm:** Necessários para o frontend (verifique a versão no `package.json` se necessário).
* **Python e pip:** Necessários para o backend (verifique a versão se houver problemas, mas Python 3+ é geralmente esperado).
* **PostgreSQL:** Instância do PostgreSQL rodando localmente ou acessível pela rede.
* **Make:** Ferramenta opcional para facilitar a execução de comandos.

## Configuração

**Variáveis de Ambiente (Backend):**

O backend requer variáveis de ambiente para se conectar ao banco de dados. Ao usar Docker Compose, essas variáveis são definidas no arquivo `.env-docker` (que você precisa criar na raiz do projeto) e passadas para o contêiner do backend. Crie um arquivo chamado `.env-docker` na raiz do projeto com o seguinte conteúdo, baseado nas configurações do serviço `postgres` no `docker-compose.yml`:

```dotenv
DATABASE_URL=postgresql://root:root@postgres:5432/patocash
# Adicione outras variáveis de ambiente que o backend possa necessitar aqui
```

Se estiver executando o backend manualmente, você precisará definir essas variáveis de ambiente diretamente no seu terminal ou através de um arquivo `.env` na pasta `backend/`.

**Variáveis de Ambiente (Frontend):**

O frontend também utiliza variáveis de ambiente, definidas diretamente no `docker-compose.yml` para a execução com Docker:

* `PORT`: Porta em que o servidor frontend escutará (padrão 3000).
* `HOST_BACKEND`: Endereço do serviço backend (usado `backend` no Docker Compose).
* `PORT_BACKEND`: Porta do serviço backend (usado `5000` no Docker Compose).

Ao executar manualmente, certifique-se de que o frontend possa acessar o backend no endereço e porta corretos.

## Banco de Dados

**Com Docker Compose:**

O `docker-compose.yml` está configurado para iniciar um contêiner PostgreSQL. O volume mapeado de `./banco_de_dados/` para `/docker-entrypoint-initdb.d/` garante que os scripts `init.sql` e `insersao_user.sql` sejam executados automaticamente na primeira vez que o contêiner do banco de dados é criado, configurando as tabelas e dados iniciais.

**Manualmente:**

1. Inicie seu servidor PostgreSQL.
2. Crie um banco de dados (ex: `patocash`), um usuário (ex: `root`) e defina uma senha (ex: `root`).
3. Conecte-se ao banco de dados recém-criado.
4. Execute manualmente os scripts SQL localizados na pasta `/banco_de_dados/` para criar as tabelas (`init.sql`) e inserir dados iniciais (`insersao_user.sql`).

## Como Executar o Projeto

**Método 1: Usando Docker Compose (Recomendado)**

Esta é a forma mais simples de colocar toda a aplicação no ar, gerenciando os três serviços (frontend, backend, postgres) de forma integrada.

1. **Crie o arquivo `.env`:** Conforme descrito na seção de Configuração.
2. **Navegue até o diretório raiz do projeto** no seu terminal.
3. **Execute o comando `make` ou `docker-compose up --build`:**

   ```bash
   # Usando o makefile
   make

   # Ou diretamente com docker-compose
   docker-compose up --build
   ```

   Este comando irá construir as imagens Docker para o frontend e backend (se ainda não existirem ou se houverem alterações), iniciar os contêineres para frontend, backend e postgres, e executar os scripts de inicialização do banco de dados.

**Método 2: Execução Manual**

Este método requer a configuração manual de cada componente.

Antes de iniciar o frontend manualmente, certifique-se de que o Node.js (e o npm) estejam instalados em sua máquina. Você pode baixá-los em [https://nodejs.org/](https://nodejs.org/). Verifique a instalação executando `node -v` e `npm -v` no terminal.

1. **Backend:**

   ```bash
    docker-compose up -d postgres
	pip install -r backend/requirements.txt
	python backend/app.py
   ```
2. **Frontend:**

   ```bash
   cd front && npm install && npm start
   ```

**Método 3: Execução Manual(Makefile)**

Este método utiliza o `makefile` para simplificar a execução dos serviços, mas ainda requer que o banco de dados esteja configurado manualmente.

1. **Backend:**

   ```bash
    make back
   ```
2. **Frontend:**

   ```bash
   make frontend
   ```

## Acessando a Aplicação

**Acesse a aplicação:** Abra seu navegador e acesse `http://localhost:3000` (ou a porta configurada para o frontend).

## Funcionalidades Principais

Com base na estrutura de arquivos e nomes, o sistema Patocast parece oferecer funcionalidades como:

* Autenticação de usuários (Login, Cadastro, Recuperação de Senha).
* Gerenciamento de Contas/Cartões.
* Registro e listagem de Transações Financeiras (Receitas/Despesas).
* Definição e acompanhamento de Metas Financeiras.
* Geração de Relatórios Financeiros (possivelmente em PDF).
* Visualização de gráficos financeiros.
* Seção de Ajuda/FAQ.
* Gerenciamento de Perfil de Usuário.

Explore a aplicação para descobrir todas as suas capacidades!
