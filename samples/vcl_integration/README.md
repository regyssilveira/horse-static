# Exemplo de Integração: Servidor Horse (Static) e Cliente VCL Delphi

Este exemplo demonstra como utilizar o middleware **`horse-static`** em conjunto com uma API REST JSON de forma harmoniosa, prevenindo os problemas comuns de conflitos de rotas enfrentados em aplicações cliente-servidor (como clientes VCL Delphi).

---

## 🛠️ O Problema: Conflitos de Roteamento com Arquivos Estáticos

Ao ativar middlewares de arquivos estáticos em uma API Horse (como `horse-staticfiles` ou `horse-server-static`), é comum que requisições destinadas à API sejam indevidamente interceptadas pelo middleware de arquivos estáticos. 

Isso ocorre porque esses middlewares costumam atuar como um *fallback*: se o servidor não encontra uma rota física correspondente no código, ele assume que a requisição é para um arquivo estático (ou cai no roteamento de uma Single Page Application - SPA) e retorna um HTML (como `index.html` ou uma página de erro 404 estática) com o cabeçalho `Content-Type: text/html`.

Se o cliente VCL (que esperava um JSON) receber esse HTML devido a uma rota errada ou conflito de prioridade de middleware, a decodificação do JSON irá falhar (gerando exceções na aplicação cliente).

---

## 🚀 A Solução

Este exemplo demonstra as três melhores práticas para evitar esse conflito:

1. **Separação de Contexto por Prefixo:** Todas as rotas de API do servidor são isoladas sob o prefixo `/api/...` (ex: `/api/v1/status`). Assim, qualquer requisição que comece com `/api` será tratada estritamente pelas rotas da API, e o middleware de arquivos estáticos não interferirá.
2. **Priorização e Filtro do Middleware:** O middleware estático está configurado com regras específicas (SPA Fallback, cache-control e ETag) operando apenas nas requisições que não pertencem ao contexto da API.
3. **Consumo Seguro no Cliente VCL:** O cliente VCL implementa uma validação defensiva que verifica se a resposta HTTP retornou o status de sucesso (`200 OK`) e o `Content-Type: application/json` antes de realizar o parsing dos dados. Se o servidor retornar HTML (devido a um erro de rota), o cliente trata o problema sem estourar exceções de leitura de JSON.

---

## 📁 Estrutura do Exemplo

*   **`server/`**: Código do servidor Horse em console.
    *   `Server.dpr`: Arquivo principal do servidor.
    *   `public/index.html`: Arquivo estático servido na raiz.
*   **`client/`**: Código da aplicação cliente Delphi VCL.
    *   `Client.dpr`: Arquivo do projeto VCL.
    *   `MainForm.pas` / `MainForm.dfm`: Formulário que demonstra a requisição segura à API.

---

## 🏁 Como Executar e Testar

### 1. Iniciar o Servidor
1. Abra o projeto `server/Server.dpr` no Delphi.
2. Certifique-se de que o middleware `horse-static` esteja instalado (`boss install`).
3. Compile e execute o servidor.
4. Acesse no navegador:
    *   `http://localhost:9000/` -> Deverá abrir a página HTML estática.
    *   `http://localhost:9000/api/v1/status` -> Deverá retornar o JSON de status.

### 2. Executar o Cliente VCL
1. Abra o projeto `client/Client.dpr` no Delphi.
2. Compile e execute.
3. Clique no botão de consulta e veja a resposta da API JSON sendo processada perfeitamente.
