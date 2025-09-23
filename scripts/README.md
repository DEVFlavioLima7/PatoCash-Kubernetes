# 🚀 Scripts Automatizados

## 📁 Estrutura

```
scripts/
├── deployment/          # Deploy e configuração
│   ├── deploy-seguro.ps1        # Deploy completo com segurança
│   ├── create-secret.ps1        # Criar Secrets do .env
│   ├── acesso-app.ps1          # Port-forward automático
│   └── teste-completo-zero.ps1 # Teste em PC novo
├── tests/              # Testes de resiliência
│   ├── teste-estresse.ps1      # Testes automatizados
│   └── testes-rapidos.ps1      # Interface interativa
└── utils/              # Utilitários (futuro)
```

## 📦 Scripts de Deployment

### **`deploy-seguro.ps1`** - Deploy Principal
```powershell
# Deploy completo com segurança
.\deployment\deploy-seguro.ps1

# Funcionalidades:
# ✅ Cria Secrets do .env automaticamente
# ✅ Aplica todos os manifests
# ✅ Aguarda pods ficarem prontos
# ✅ Abre port-forward automático
```

### **`create-secret.ps1`** - Gerenciar Secrets
```powershell
# Criar Secret a partir do .env
.\deployment\create-secret.ps1

# Funcionalidades:
# ✅ Lê variáveis do arquivo .env
# ✅ Cria Secret no Kubernetes
# ✅ Substitui Secret existente
```

### **`acesso-app.ps1`** - Acesso Local
```powershell
# Port-forward para acesso local
.\deployment\acesso-app.ps1

# Funcionalidades:
# ✅ Verifica se aplicação está rodando
# ✅ Configura port-forward na porta 3000
# ✅ Mata processos conflitantes
```

### **`teste-completo-zero.ps1`** - Teste PC Novo
```powershell
# Teste completo do zero
.\deployment\teste-completo-zero.ps1

# Funcionalidades:
# ✅ Verifica pré-requisitos
# ✅ Limpa ambiente atual
# ✅ Inicia Minikube se necessário
# ✅ Deploy completo automatizado
```

## 🧪 Scripts de Teste

### **`teste-estresse.ps1`** - Testes Automatizados
```powershell
# Todos os testes
.\tests\teste-estresse.ps1

# Teste específico
.\tests\teste-estresse.ps1 -Teste "auto-healing"
.\tests\teste-estresse.ps1 -Teste "hpa" -DuracaoStress 180

# Funcionalidades:
# ✅ Auto-healing (deleção de pods)
# ✅ HPA (stress de CPU)
# ✅ Monitoramento em tempo real
# ✅ Relatório de resultados
```

### **`testes-rapidos.ps1`** - Interface Interativa
```powershell
# Menu interativo
.\tests\testes-rapidos.ps1

# Opções disponíveis:
# 1️⃣ Deletar Pod (Auto-Healing)
# 2️⃣ Stress CPU (HPA)
# 3️⃣ Status Atual
# 4️⃣ Escalar Manualmente
# 5️⃣ Reset Completo
```

## 🎯 Casos de Uso

### **Deploy Inicial**
```powershell
# 1. Configurar .env
Copy-Item ..\kubernetes\configs\.env-exemplo .env
notepad .env

# 2. Deploy
.\deployment\deploy-seguro.ps1
```

### **Testes de Resiliência**
```powershell
# Teste automático completo
.\tests\teste-estresse.ps1

# Teste interativo
.\tests\testes-rapidos.ps1
```

### **Troubleshooting**
```powershell
# Reset completo
.\tests\testes-rapidos.ps1
# Escolher opção 5

# Teste do zero
.\deployment\teste-completo-zero.ps1
```

## ⚙️ Parâmetros Disponíveis

### **teste-estresse.ps1**
```powershell
-Teste "auto-healing|hpa|todos"    # Tipo de teste
-DuracaoStress 300                 # Duração em segundos
-IntervaloMonitoramento 5          # Intervalo de verificação
```

### **teste-completo-zero.ps1**
```powershell
-LimparTudo                        # Força limpeza
-SemPrompt                         # Execução sem confirmação
```

## 🔧 Manutenção

### **Atualizar Scripts**
```powershell
# Após modificações
git add scripts/
git commit -m "📝 Atualizar scripts"
git push
```

### **Logs e Debug**
Todos os scripts incluem:
- ✅ **Logging colorido** para melhor visualização
- ✅ **Tratamento de erros** com mensagens claras
- ✅ **Verificação de pré-requisitos**
- ✅ **Confirmações** antes de ações destrutivas