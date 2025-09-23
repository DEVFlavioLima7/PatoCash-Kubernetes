# 📖 Documentação PatoCash Kubernetes

## 📁 Conteúdo Disponível

### **Guias de Uso**
- 🚀 [**Como Usar**](COMO-USAR.md) - Guia completo de instalação e uso
- 🧪 [**Guia de Testes**](GUIA-TESTES.md) - Testes de resiliência e HPA
- 🔒 [**Segurança**](SEGURANCA.md) - Configuração segura e boas práticas
- 📊 [**Monitoramento**](MONITORAMENTO.md) - Observabilidade e métricas

### **Documentação Técnica**
- 🏗️ [**Arquitetura**](ARQUITETURA.md) - Visão geral do sistema
- ⚙️ [**Configuração**](CONFIGURACAO.md) - Detalhes de configuração
- 🐳 [**Kubernetes**](KUBERNETES.md) - Manifests e recursos K8s
- 🔧 [**Troubleshooting**](TROUBLESHOOTING.md) - Solução de problemas

### **Arquivos de Referência**
- 📝 [**README Antigo**](README-old.md) - Documentação original
- 📓 [**Changelog**](CHANGELOG.md) - Histórico de mudanças
- 📋 [**TODO**](TODO.md) - Melhorias planejadas

## 🎯 Links Rápidos

| Quero... | Documento |
|----------|-----------|
| 🚀 Começar agora | [COMO-USAR.md](COMO-USAR.md) |
| 🧪 Testar auto-healing | [GUIA-TESTES.md](GUIA-TESTES.md) |
| 🔒 Configurar segurança | [SEGURANCA.md](SEGURANCA.md) |
| 📊 Ver métricas | [MONITORAMENTO.md](MONITORAMENTO.md) |
| 🔧 Resolver problemas | [TROUBLESHOOTING.md](TROUBLESHOOTING.md) |

## 📚 Estrutura da Documentação

```
docs/
├── COMO-USAR.md           # 🚀 Guia principal
├── GUIA-TESTES.md         # 🧪 Testes de resiliência
├── SEGURANCA.md           # 🔒 Configuração segura
├── MONITORAMENTO.md       # 📊 Métricas e observabilidade
├── ARQUITETURA.md         # 🏗️ Visão geral técnica
├── KUBERNETES.md          # ⚙️ Detalhes dos manifests
├── TROUBLESHOOTING.md     # 🔧 Solução de problemas
└── assets/                # 🖼️ Imagens e diagramas
    ├── architecture.png
    ├── hpa-flow.png
    └── auto-healing.gif
```

## 🎨 Convenções

### **Emojis Utilizados**
- 🚀 Deploy e execução
- 🧪 Testes e validação
- 🔒 Segurança
- 📊 Monitoramento e métricas
- ⚙️ Configuração
- 🔧 Troubleshooting
- 📁 Estrutura de arquivos
- ✅ Sucesso/Concluído
- ❌ Erro/Falha
- ⚠️ Atenção/Cuidado

### **Formatação de Código**
```powershell
# Scripts PowerShell
.\script.ps1 -Parameter value
```

```yaml
# Manifests Kubernetes
apiVersion: apps/v1
kind: Deployment
```

```bash
# Comandos kubectl
kubectl get pods
```

## 🤝 Contribuição

Para contribuir com a documentação:

1. **Identifique** o que precisa ser documentado
2. **Edite** o arquivo apropriado ou crie um novo
3. **Siga** as convenções de formatação
4. **Teste** os comandos documentados
5. **Faça commit** com mensagem descritiva

### **Exemplo de Commit**
```bash
git add docs/
git commit -m "📖 Adicionar guia de troubleshooting"
git push
```

## 📞 Suporte

Se a documentação não responder sua dúvida:

1. 🔍 **Verifique** se existe um documento específico
2. 📖 **Consulte** o [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
3. 🧪 **Execute** os testes para validar o ambiente
4. 🔄 **Tente** o [teste completo do zero](../scripts/deployment/teste-completo-zero.ps1)

---
**📝 Documentação sempre atualizada para PatoCash Kubernetes v1.0**