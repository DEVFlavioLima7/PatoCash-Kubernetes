# Patocast - Sistema de Gerenciamento Financeiro Web

Bem-vindo ao Patocast, uma aplicação web completa projetada para auxiliar no gerenciamento financeiro pessoal. Este sistema permite aos usuários controlar suas transações, definir metas financeiras, visualizar relatórios e muito mais, tudo através de uma interface web interativa.

## Visão Geral da Arquitetura

O Patocast é construído sobre uma arquitetura de microsserviços, utilizando tecnologias modernas para garantir escalabilidade e manutenibilidade. A aplicação é dividida em três componentes principais:

1.  **Frontend:** Desenvolvido com Node.js e o framework Express, utilizando Nunjucks como template engine para renderização dinâmica das páginas HTML. O frontend é responsável por toda a interface do usuário, interações e comunicação com o backend via API REST. Ele também utiliza bibliotecas como Chart.js para visualização de dados e Playwright para geração de PDFs (provavelmente para relatórios).
2.  **Backend:** Uma API RESTful construída em Python utilizando o microframework Flask. O backend gerencia a lógica de negócios, autenticação de usuários, processamento de dados financeiros e a comunicação com o banco de dados. Utiliza bibliotecas como `psycopg2-binary` para interagir com o PostgreSQL e `Flask-CORS` para permitir requisições do frontend.
3.  **Banco de Dados:** Utiliza PostgreSQL como sistema de gerenciamento de banco de dados relacional para armazenar todos os dados da aplicação, incluindo informações de usuários, transações, metas, etc. A inicialização do banco de dados, incluindo a criação de tabelas e inserção de dados iniciais, é automatizada através de scripts SQL.

## Estrutura do Projeto

O repositório está organizado da seguinte forma:

*   `/backend`: Contém o código-fonte da API Flask (Python).
    *   `app.py`: Ponto de entrada da aplicação backend.
    *   `requirements.txt`: Lista as dependências Python.
    *   `src/`: Módulos contendo rotas, lógica de banco de dados, envio de email, etc.
    *   `dockerfile`: Instruções para construir a imagem Docker do backend.
*   `/frontend`: Contém o código-fonte da aplicação frontend (Node.js/Express).
    *   `server.js`: Ponto de entrada da aplicação frontend.
    *   `package.json`: Define as dependências Node.js e scripts.
    *   `public/`: Arquivos estáticos (CSS, JavaScript do lado do cliente, imagens, assets).
    *   `src/views/`: Templates Nunjucks para as páginas HTML.
    *   `dockerfile`: Instruções para construir a imagem Docker do frontend.
*   `/banco_de_dados`: Contém os scripts SQL para inicialização do banco.
    *   `init.sql`: Script para criação de tabelas.
    *   `insersao_user.sql`: Script para inserção de dados iniciais (possivelmente usuários de teste).
*   `docker-compose.yml`: Arquivo de orquestração para iniciar todos os serviços (frontend, backend, postgres) com Docker Compose.
*   `makefile`: Contém comandos de atalho para facilitar a execução e gerenciamento do ambiente Docker.
*   `.env-docker` (Necessário criar): Arquivo para armazenar as variáveis de ambiente do backend ao rodar com Docker (veja a seção de Configuração).

## Pré-requisitos

Existem duas maneiras principais de executar o projeto: utilizando Docker (recomendado) ou manualmente.

**Para execução com Docker (Recomendado):**

*   **Docker:** Instale o Docker Engine em seu sistema.
*   **Docker Compose:** Instale o Docker Compose (geralmente incluído nas instalações mais recentes do Docker Desktop).

**Para execução Manual:**

*   **Node.js e npm:** Necessários para o frontend (verifique a versão no `package.json` se necessário).
*   **Python e pip:** Necessários para o backend (verifique a versão se houver problemas, mas Python 3+ é geralmente esperado).
*   **PostgreSQL:** Instância do PostgreSQL rodando localmente ou acessível pela rede.

## Configuração

**Variáveis de Ambiente (Backend):**

O backend requer variáveis de ambiente para se conectar ao banco de dados. Ao usar Docker Compose, essas variáveis são definidas no arquivo `.env-docker` (que você precisa criar na raiz do projeto) e passadas para o contêiner do backend. Crie um arquivo chamado `.env-docker` na raiz do projeto com o seguinte conteúdo, baseado nas configurações do serviço `postgres` no `docker-compose.yml`:

```dotenv
DATABASE_URL=postgresql://root:root@postgres:5432/patocash
# Adicione outras variáveis de ambiente que o backend possa necessitar aqui
```

Se estiver executando o backend manualmente, você precisará definir essas variáveis de ambiente diretamente no seu terminal ou através de um arquivo `.env` na pasta `backend/` (o backend parece usar `dotenv` baseado no `requirements.txt`, então um arquivo `.env` deve funcionar).

**Variáveis de Ambiente (Frontend):**

O frontend também utiliza variáveis de ambiente, definidas diretamente no `docker-compose.yml` para a execução com Docker:

*   `PORT`: Porta em que o servidor frontend escutará (padrão 3000).
*   `HOST_BACKEND`: Endereço do serviço backend (usado `backend` no Docker Compose).
*   `PORT_BACKEND`: Porta do serviço backend (usado `5000` no Docker Compose).

Ao executar manualmente, certifique-se de que o frontend possa acessar o backend no endereço e porta corretos.

## Banco de Dados

**Com Docker Compose:**

O `docker-compose.yml` está configurado para iniciar um contêiner PostgreSQL. O volume mapeado de `./banco_de_dados/` para `/docker-entrypoint-initdb.d/` garante que os scripts `init.sql` e `insersao_user.sql` sejam executados automaticamente na primeira vez que o contêiner do banco de dados é criado, configurando as tabelas e dados iniciais.

**Manualmente:**

1.  Inicie seu servidor PostgreSQL.
2.  Crie um banco de dados (ex: `patocash`), um usuário (ex: `root`) e defina uma senha (ex: `root`).
3.  Conecte-se ao banco de dados recém-criado.
4.  Execute manualmente os scripts SQL localizados na pasta `/banco_de_dados/` para criar as tabelas (`init.sql`) e inserir dados iniciais (`insersao_user.sql`).

## Como Executar o Projeto

**Método 1: Usando Docker Compose (Recomendado)**

Esta é a forma mais simples de colocar toda a aplicação no ar, gerenciando os três serviços (frontend, backend, postgres) de forma integrada.

1.  **Crie o arquivo `.env-docker`:** Conforme descrito na seção de Configuração.
2.  **Navegue até o diretório raiz do projeto** no seu terminal.
3.  **Execute o comando `make all` ou `docker-compose up --build`:**

    ```bash
    # Usando o makefile
    make all
    
    # Ou diretamente com docker-compose
    docker-compose up --build
    ```

    Este comando irá construir as imagens Docker para o frontend e backend (se ainda não existirem ou se houverem alterações), iniciar os contêineres para frontend, backend e postgres, e executar os scripts de inicialização do banco de dados.

4.  **Acesse a aplicação:** Abra seu navegador e acesse `http://localhost:3000`.

O frontend estará acessível na porta 3000, o backend na porta 5000 e o banco de dados na porta 5432 (mapeada para o host).

**Método 2: Execução Manual**

Este método requer a configuração manual de cada componente.

1.  **Banco de Dados:** Configure e inicie o PostgreSQL conforme descrito na seção Banco de Dados (Manualmente).
2.  **Backend:**
    *   Navegue até a pasta `/backend`.
    *   (Opcional, mas recomendado) Crie e ative um ambiente virtual Python: `python -m venv venv && source venv/bin/activate` (ou `venv\Scripts\activate` no Windows).
    *   Instale as dependências: `pip install -r requirements.txt`.
    *   Defina as variáveis de ambiente necessárias (ex: `export DATABASE_URL=postgresql://user:password@host:port/database`).
    *   Inicie o servidor Flask: `python app.py`.
3.  **Frontend:**
    *   Navegue até a pasta `/frontend`.
    *   Instale as dependências: `npm install`.
    *   Inicie o servidor Node.js: `npm start`.
    *   Certifique-se de que as variáveis de ambiente ou configurações no código do frontend apontem corretamente para o endereço e porta onde o backend está rodando.

4.  **Acesse a aplicação:** Abra seu navegador e acesse `http://localhost:3000` (ou a porta configurada para o frontend).

## Funcionalidades Principais

Com base na estrutura de arquivos e nomes, o sistema Patocast parece oferecer funcionalidades como:

*   Autenticação de usuários (Login, Cadastro, Recuperação de Senha).
*   Gerenciamento de Contas/Cartões.
*   Registro e listagem de Transações Financeiras (Receitas/Despesas).
*   Definição e acompanhamento de Metas Financeiras.
*   Geração de Relatórios Financeiros (possivelmente em PDF).
*   Visualização de gráficos financeiros.
*   Seção de Ajuda/FAQ.
*   Gerenciamento de Perfil de Usuário.

Explore a aplicação para descobrir todas as suas capacidades!
