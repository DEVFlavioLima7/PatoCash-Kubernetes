const express = require('express')
const cookieParser = require('cookie-parser');
const { chromium } = require('playwright');
const promClient = require('prom-client');

const server = express()
const port = process.env.PORT || 3000
const host_backend = process.env.HOST_BACKEND || 'localhost'
const port_backend = process.env.PORT_BACKEND || 5000

// Configurar métricas do Prometheus
const register = promClient.register;
promClient.collectDefaultMetrics({ register });

// Métricas customizadas
const httpRequestsTotal = new promClient.Counter({
  name: 'http_requests_total',
  help: 'Total number of HTTP requests',
  labelNames: ['method', 'route', 'status_code'],
});

const httpRequestDuration = new promClient.Histogram({
  name: 'http_request_duration_seconds',
  help: 'HTTP request duration in seconds',
  labelNames: ['method', 'route'],
});

// Middleware para coletar métricas
server.use((req, res, next) => {
  const start = Date.now();
  
  res.on('finish', () => {
    const duration = (Date.now() - start) / 1000;
    const route = req.route ? req.route.path : req.path;
    
    httpRequestsTotal.inc({
      method: req.method,
      route: route,
      status_code: res.statusCode,
    });
    
    httpRequestDuration.observe(
      { method: req.method, route: route },
      duration
    );
  });
  
  next();
});

console.log(`Frontend rodando na porta ${port}`)
console.log(`Backend rodando na porta ${port_backend}`)
console.log(`Host do backend: ${host_backend}`)

server.use(express.static("public"))
server.use(express.urlencoded({extended: true}))
server.use(cookieParser())

// Endpoint para métricas do Prometheus
server.get('/metrics', async (req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});

const nunjucks = require('nunjucks')
nunjucks.configure(
  "src/views",{
    express: server,
    noCache: true,
    autoescape: true
  }
)

server.post('/login', express.urlencoded({ extended: true }), async (req,res) => {
  const data = req.body

  const response = await fetch(
    `http://${host_backend}:${port_backend}/login`,{
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        email: data.email,
        senha: data.senha,
      })
  })

  if(response.status !== 200) {
    return res.redirect('/?login=false')
  }
  else{
    const responseData = await response.json();
    res.cookie('username', responseData.username);
    res.cookie('idUser', responseData.idUser);
    return res.redirect('/inicio')
  }
})

server.get('/', async (req,res) => {

  const login = req.query.login ? req.query.login == 'true' : true;

  return res.render('./auth/login.htm',
    { 
      saved: login,
      mensagem: "Email ou senha incorretos!"
    }
  )
})

server.get('/cadastrar', async (req,res) => {
  const saved = req.query.cadastro == 'true' ? true : false
  return res.render('./auth/cadastrar.htm', {
    saved: saved,
    mensagem: "Cadastro realizado com sucesso!",
  })
})

server.post('/save_conta', express.urlencoded({ extended: true }), async (req,res) => {
  const data = req.body

  const response = await fetch(
    `http://${host_backend}:${port_backend}/cadastro`,{
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        nome: data.nome,
        sobrenome: data.sobrenome,
        email: data.email,
        senha: data.senha,
        confirmar_senha: data.confirmar_senha,
        checkbox: data.checkbox,
      })
  })

  if(response.status !== 201) {
    return res.status(500).send(response.statusText);
  }else{
    res.cookie('username', data.nome);
    const responseData = await response.json();
    res.cookie('idUser', responseData.idUser);
    return res.redirect('/cadastrar?cadastro=true')
  }
})

server.get('/perguntas', async (req,res) => {
  return res.render('./auth/perguntas.htm')
})

server.post('/enviar_respostas', express.urlencoded({ extended: true }), async (req,res) => {
  const idUser = req.cookies.idUser
  const data = req.body
  const respostas = Object.keys(data).map((key, index) => ({
    pergunta: index + 1,
    resposta: data[key]
  }))

  const response = await fetch(
    `http://${host_backend}:${port_backend}/respostas/id=${idUser}`,{
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(respostas)
  })
  if(response.status !== 200) {
    return res.status(500).send('Erro ao salvar as respostas');
  }else{
    return res.redirect('/inicio')
  }
})

server.post('/send_email', express.urlencoded({ extended: true }), async (req,res) => {
  const data = req.body

  const response = await fetch(
    `http://${host_backend}:${port_backend}/email/recuperar_senha/`,{
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        email: data.email,
      })
    }
  );

  if(response.status === 404) {
    // Email não cadastrado
    return res.redirect('/recuperar_conta?send_email=true&mensagem=Email%20não%20cadastrado!');
  } else if(response.status !== 200) {
    return res.redirect('/recuperar_conta?send_email=true&mensagem=Erro%20ao%20enviar%20email.%20Tente%20novamente.');
  } else {
    return res.redirect('/recuperar_conta?send_email=true&mensagem=Um%20email%20foi%20enviado%20para%20você%20com%20as%20instruções%20para%20recuperação%20de%20senha.');
  }
})

server.get('/recuperar_conta', express.urlencoded({ extended: true }), async (req,res) => {
  const saved = req.query.send_email == 'true' ? true : false
  const mensagem = req.query.mensagem || "Por favor, insira seu email para recuperação de senha."

  return res.render('./auth/esqueci-senha.htm',
    {
      saved: saved,
      mensagem: mensagem
    }
  );
})

server.post('/alterar_senha', express.urlencoded({ extended: true }), async (req,res) => {
  const data = req.body
  const email = req.query.email

  const response = await fetch(
    `http://${host_backend}:${port_backend}/email/alteracao-senha/email=${email}`,{
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        senha: data.senha,
        confirmar_senha: data.confirmar_senha,
      })
  })

  if(response.status !== 200) {
    return res.status(500).send('Erro ao alterar a senha');
  }else{
    return res.redirect('/alterar-senha?alterar=true')
  }
})

server.get('/alterar-senha', express.urlencoded({ extended: true }),async (req,res) => {
  const saved = req.query.alterar == 'true' ? true : false
  const email = req.query.email
  return res.render('./auth/recuperacao-senha.htm', 
    {
      saved: saved,
      mensagem: "Senha alterada com sucesso!", 
      email: email 
    }
  );
})

server.get('/inicio', async (req,res) => {
  let idUser = req.cookies.idUser
  const response = await fetch(
    `http://${host_backend}:${port_backend}/transacao?id=${idUser}`
  );

  const response_cartao = await fetch(
    `http://${host_backend}:${port_backend}/cards/id=${idUser}`
  );

  dados = await response.json()
  const cartao_data = await response_cartao.json()

  const response_perguntas = await fetch(
    `http://${host_backend}:${port_backend}/respostas/id=${idUser}`
  );
  const perguntas = await response_perguntas.json()
  const resposta = perguntas[0].resposta.length - 1;
  
  var meta = perguntas[0].resposta[resposta].resposta;

  if(cartao_data.length > 0){
    const ultimo_cartao = cartao_data.length - 1;
    var meta = cartao_data[ultimo_cartao].meta;
  }

  gasto = parseFloat(dados.reduce((acc, curr) => acc + parseFloat(curr.valor), 0)).toFixed(2)
  porcentagem = (gasto / meta) * 100;
  
  return res.render('./navigation/inicio.htm', {
    transacoes: dados,
    gasto_total: gasto,
    limite: parseFloat(meta) - gasto,
    porcentagem: porcentagem > 100 ? 100 : porcentagem,
    quantidade_cartao: cartao_data.length,
    cartoes: cartao_data.slice(0, 2),
  })
})

server.get('/contas', express.urlencoded({ extended: true }), async (req,res) => {
  
  const response = await fetch(
    `http://${host_backend}:${port_backend}/cards/id=${req.cookies.idUser}`
  );

  const cartoes = await response.json()

  const saved = req.query.cadastro == 'true' ? true : false
  if(saved){
    res.clearCookie('cadastro')
  }

  return res.render('./navigation/contas.htm', {
    idUser: req.cookies.idUser,
    cartoes: cartoes,
    saved:  saved,
    mensagem: "Cartão cadastrado com sucesso!",
    cadastro: "Cartao"
  })
})

server.post('/save_cartao', express.urlencoded({ extended: true }), async (req,res) => {
  let idUser = req.cookies.idUser;
  const data = req.body

  const response = await fetch(
    `http://${host_backend}:${port_backend}/cards/id=${idUser}`,{
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({ 
        tipo: data.tipo, 
        numero: data.numero, 
        nome: data.nome, 
        meta: data.meta, 
      })
    }
  );

  if(response.status !== 201) {
    return res.status(500).send('Erro ao salvar o cartão');
  }else{
    return res.redirect('/contas?cadastro=true')
  }
})

server.post('/update_cartao', express.urlencoded({ extended: true }), async (req,res) => {
  const data = req.body
  let idUser = req.cookies.idUser

  try {
      const response_card = await fetch(
        `http://${host_backend}:${port_backend}/cards/id=${idUser}`
      );
      if (!response_card.ok) throw new Error('Erro ao buscar cartões');
      const cartao_data = await response_card.json();

      const ultimo_cartao = cartao_data.length - 1;
      let response;
      if(ultimo_cartao < 0){
        response = await fetch(
          `http://${host_backend}:${port_backend}/respostas/update_meta/id=${idUser}`,{
            method: 'PUT',
            headers: {
              'Content-Type': 'application/json'
            },
            body: JSON.stringify({ 
              meta: data.meta, 
            })
          }
        );
      }else{
        let idCartao = cartao_data[ultimo_cartao].idCartao;
        
        response = await fetch(
          `http://${host_backend}:${port_backend}/cards/update_meta`,{
            method: 'PUT',
            headers: {
              'Content-Type': 'application/json'
            },
            body: JSON.stringify({ 
              idCartao: idCartao, 
              meta: data.meta, 
            })
          }
        );
      }

    if(response.status !== 200) {
      return res.status(500).send('Erro ao atualizar o cartão');
    }else{
      return res.redirect('/metas')
    }
  } catch (err) {
    return res.status(500).send('Erro ao atualizar o cartão: ' + err.message);
  }
})

server.get('/metas', async (req,res) => {
  let idUser = req.cookies.idUser
  try {
    const response_card = await fetch(
      `http://${host_backend}:${port_backend}/cards/id=${idUser}`
    );
    if (!response_card.ok) throw new Error('Erro ao buscar cartões');
    const cartao_data = await response_card.json();

    const ultimo_cartao = cartao_data.length - 1;
    
    var meta = 0;
    if(ultimo_cartao < 0){
      const response_form = await fetch(
        `http://${host_backend}:${port_backend}/respostas/id=${idUser}`
      );
      if (!response_form.ok) throw new Error('Erro ao buscar respostas');
      const form_data = await response_form.json();
      const resposta = form_data[0].resposta.length - 1;
      meta = form_data[0].resposta[resposta].resposta;
    }else{
      meta = cartao_data[ultimo_cartao].meta;
    }

    const response_transacao = await fetch(
      `http://${host_backend}:${port_backend}/transacao_categoria/id=${idUser}`
    );
    if (!response_transacao.ok) throw new Error('Erro ao buscar transações');
    const dados = await response_transacao.json();

    const gasto = Object.values(dados).reduce((acc, categoria) => acc + categoria.total_gasto, 0);
    const porcentagem = (gasto / meta) * 100;

    return res.render('./navigation/metas.htm', {
      categorias: dados,
      limite: meta,
      gasto_limite: (meta - gasto).toFixed(2),
      gasto_total: gasto.toFixed(2),
      porcentagem: porcentagem > 100 ? 100 : porcentagem,
    });
  } catch (err) {
    return res.status(500).send('Erro ao carregar metas: ' + err.message);
  }
})

server.get('/financas', async (req,res) => {
  let idUser = req.cookies.idUser

  const response_transacao = await fetch(
    `http://${host_backend}:${port_backend}/transacao?id=${idUser}`
  );
  dados = await response_transacao.json()

  const response_pendente = await fetch(
    `http://${host_backend}:${port_backend}/transacao_next_transactions/id=${idUser}`
  );
  gasto_pendente = await response_pendente.json()

  const response_categorias = await fetch(
    `http://${host_backend}:${port_backend}/get_categorias/id=${idUser}`
  );
  categorias = await response_categorias.json()

  const response_meses = await fetch(
    `http://${host_backend}:${port_backend}/transacao_mes/id=${idUser}`
  );
  meses = await response_meses.json()

  return res.render('./navigation/financas.htm', {
    idUser: idUser,
    transacoes: dados,
    gasto_total: parseFloat(dados.reduce((acc, curr) => acc + parseFloat(curr.valor), 0)).toFixed(2),
    pendente: parseFloat(gasto_pendente.pendente).toFixed(2),
    categorias: categorias,
    meses: meses,
  })
})

server.post('/transactions/save_transacao', express.urlencoded({ extended: true }), async (req,res) => {
  let idUser = req.cookies.idUser
  const data = req.body

  const response = await fetch(
    `http://${host_backend}:${port_backend}/transacao/id=${idUser}`,{
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        estabelecimento: data.estabelecimento,
        categoria: data.categoria,
        valor: data.valor,
        data: data.data,
      })
    }
  );

  if(response.status !== 201) {
    return res.status(500).send('Erro ao salvar a transação');
  }else{
    return res.redirect('/financas')
  }
})

server.get('/ajuda', async (req,res) => {
  const idUser = req.cookies.idUser
  
  const response_posso_ajudar = await fetch(
    `http://${host_backend}:${port_backend}/posso_ajudar_recomendado/id=${idUser}`
  );
  dados = await response_posso_ajudar.json()
  return res.render('./navigation/ajuda.htm',{
      dados:dados
    }
  )
})

server.get('/ajuda_selecionado', async (req,res) => {
  const id = req.query.id

  const response_posso_ajudar = await fetch(
    `http://${host_backend}:${port_backend}/posso_ajudar_content/id=${id}`
  );
  dados = await response_posso_ajudar.json()

  headers_text = dados[0]['header_text']
  modal_cards = dados[0]['modal_cards']

  return res.render('./navigation/ajuda_selecionado.htm',{
      headers_text: headers_text,
      modal_cards:modal_cards
    }
  )
})

server.get('/perfil', async (req,res) => {
  let username = req.cookies.username
  let idUser = req.cookies.idUser

  const saved = req.query.atualizado == 'true' ? true : false
  
  return res.render('./navigation/perfil.htm', 
    {
      nome: username,
      idUser: idUser,
      saved: saved,
      mensagem: "Perfil atualizado com sucesso!",
    }
  )
})

server.post('/update_perfil', express.urlencoded({ extended: true }), async (req,res) => {
  let idUser = req.cookies.idUser
  const data = req.body

  const response = await fetch(
    `http://${host_backend}:${port_backend}/perfil/id=${idUser}`,{
      method: 'PUT',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        nome: data.nome,
        sobrenome: data.sobrenome,
        email: data.email,
        senha: data.senha,
      })
    });

  if(response.status !== 200) {
    return res.status(500).send('Erro ao salvar o perfil');
  }else{
    res.cookie('username', data.nome);
    return res.redirect('/perfil?atualizado=true')
  }
})

server.get('/historico', async (req,res) => {
  let idUser = req.cookies.idUser

  const response = await fetch(
    `http://${host_backend}:${port_backend}/transacao?id=${idUser}`
  );
  dados = await response.json()
  return res.render('./navigation/operacoes.htm',{transacoes: dados})
})

const somenteExportarPdf = (req, res, next) => {
  const token = req.query.token;
  if (token !== 'SECRETO_123') { // Substitua por um token complexo
    return res.status(403).send('Acesso negado: token inválido');
  }
  next();
};

server.get('/relatorio',somenteExportarPdf,async (req, res) => {
  const { id, mes, categoria } = req.query;
  
  const response_user = await fetch(
    `http://${host_backend}:${port_backend}/users/id=${id}`
  );
  const user = await response_user.json()

  const response_transacao = await fetch(
    `http://${host_backend}:${port_backend}/transacao?id=${id}&mes=${mes}&categoria=${categoria}`
  );
  const transacoes = await response_transacao.json()
  
  const transacoesComDatas = transacoes.map(transacao => {
    const [dia, mes, ano] = transacao.data.split('/').map(Number);
    return {
      ...transacao,
      dataObj: new Date(ano, mes - 1, dia)
    };
  });

  const datas = transacoesComDatas.map(t => t.dataObj);

  const data_min = new Date(Math.min(...datas));
  const data_max = new Date(Math.max(...datas));

  const data_inicio = data_min.toLocaleDateString('pt-BR');
  const data_fim = data_max.toLocaleDateString('pt-BR');

  const gastos_maiores = transacoes.sort((a, b) => b.valor - a.valor).slice(0, 3);
  const gasto = parseFloat(transacoes.reduce((acc, curr) => acc + parseFloat(curr.valor), 0)).toFixed(2)

  const dados = {
    nome: user.nome,
    sobrenome: user.sobrenome,
    data_inicio: data_inicio,
    data_fim: data_fim,
    gasto_total: gasto,
    gastos_maiores: gastos_maiores,
    gastos: transacoes,
  }

  return res.render('./pdf/relatorio.htm',{ dados:dados})
});

server.get('/exportar-pdf', express.urlencoded({ extended: true }), async (req, res) => {
  const { id, mes, categoria } = req.query;
  
  let browser;
  try {
    browser = await chromium.launch({
      headless: true,
      args: ['--disable-web-security', '--no-sandbox']
    });

    const page = await browser.newPage();
    
    await page.setViewportSize({ width: 1200, height: 5000 });
    
    await page.goto(`http://localhost:3000/relatorio?token=SECRETO_123&id=${id}&mes=${mes}&categoria=${categoria}`, {
      waitUntil: 'networkidle0',
      timeout: 60000
    });

    await page.waitForFunction(() => {
      const bodyHeight = document.body.scrollHeight;
      return bodyHeight > 1000;
    });

    const pdfBuffer = await page.pdf({
      format: 'A4',
      printBackground: true,
      displayHeaderFooter: false,
      preferCSSPageSize: false
    });

    res.setHeader('Content-Type', 'application/pdf');
    res.send(pdfBuffer);

  } catch (error) {
    console.error('Erro ao gerar PDF:', error);
    res.status(500).send('Erro na geração do PDF: ' + error.message);
  } finally {
    if (browser) await browser.close();
  }
});

server.listen(port)