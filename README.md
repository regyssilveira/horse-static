# Horse Static

Middleware de serviço de arquivos estáticos de alta performance, thread-safe e abstrato para o framework web **Horse**.

Ele oferece suporte nativo a requisições de bytes parciais (HTTP 206 Range) para streaming, geração de ETags e controle de cache eficiente, fallback para aplicações de página única (SPA) e uma arquitetura baseada em provedores de armazenamento abstratos.

---

## 🚀 Recursos e Comparativo de Ecossistemas

O **Horse Static** foi desenvolvido alinhado com as melhores práticas de entrega de conteúdo estático do mercado moderno. Veja abaixo como ele se compara com as soluções de referência de outros ecossistemas:

| Funcionalidade | serve-static (Express / Node.js) | Static Files (ASP.NET Core / C#) | **Horse Static (Delphi/FPC)** |
| :--- | :---: | :---: | :---: |
| **HTTP 206 Ranges (Streaming)** | Sim | Sim | **Sim** |
| **Caching com ETags & Last-Modified** | Sim | Sim | **Sim** |
| **Roteamento SPA Fallback** | Requer pacote extra (ex: `connect-history-...`) | Requer rotas customizadas | **Sim** (Nativo via `SpaFallback`) |
| **Proteção Directory Traversal** | Sim | Sim | **Sim** |
| **Storage Abstrato (Banco, S3, RAM)** | Atrelado ao File System local | Atrelado à interface `IFileProvider` | **Sim** (Nativo e desacoplado via `IHorseStaticStorage`) |
| **Multi-instância Thread-safe** | Sim | Sim | **Sim** |

---

## ⚙️ Principais Recursos

* 🚀 **Suporte a HTTP 206 (Range):** Processamento nativo de requisições parciais para reprodução e avanço de vídeo/áudio (streaming) e downloads retomáveis.
* 📦 **Controle de Cache:** Geração de ETags fracas a partir de metadados (`FileSize + ModifiedDate`), respondendo requisições com `304 Not Modified` sem gargalos de leitura de disco.
* 🌐 **Modo SPA (Single Page Application):** Redirecionamento inteligente de rotas virtuais inexistentes no disco para um arquivo raiz (ex: `index.html`) para apps React/Vue/Angular.
* 🛡️ **Segurança:** Proteção robusta integrada contra ataques de Directory Traversal.
* 🔌 **Storage Abstrato:** Arquitetura desacoplada (via interface `IHorseStaticStorage`) pronta para extensões como AWS S3, Azure Blob ou Provedores de Memória.
* 🧵 **Thread-Safe & Multi-Instance:** Sem estado global ou singletons de unit. Mapeie múltiplos caminhos físicos diferentes em portas diferentes com total segurança concorrente.

---

## ⚙️ Instalação

A instalação é simples e feita através do gerenciador de pacotes [`boss`](https://github.com/HashLoad/boss):

```sh
boss install github.com/regyssilveira/horse-static
```

---

## ⚡️ Início Rápido

O exemplo abaixo registra o middleware mapeando a pasta física `./public` para a URL raiz da aplicação:

```delphi
uses
  Horse,
  Horse.Static;

begin
  THorse.Use(THorseStatic.Middleware(
    THorseStatic.New('./public')
  ));

  THorse.Listen(9000);
end.
```

---

## 💡 Exemplos Práticos de Uso

### 1. Hospedagem de Single Page Application (SPA) com Fallback
Para hospedar aplicações criadas com React, Vue ou Angular, onde o roteamento é controlado no lado do cliente (browser), qualquer rota virtual digitada diretamente na URL (ex: `/dashboard/relatorios`) deve carregar o `index.html` raiz. 

Configure o `SpaFallback` para habilitar este comportamento de forma transparente:

```delphi
THorse.Use(THorseStatic.Middleware(
  THorseStatic.New('./dist') // Pasta contendo a build do React/Vue
    .SpaFallback('index.html')
));
```

### 2. Streaming de Vídeo/Áudio com Suporte a HTTP Ranges (HTTP 206)
Ao servir vídeos (como arquivos `.mp4`) ou áudios para players nativos HTML5 no navegador, é essencial dar suporte a requisições de range de bytes. Isso permite que o usuário avance ou retroceda a linha do tempo sem ter que baixar o arquivo inteiro primeiro, economizando muita banda.

```delphi
THorse.Use(THorseStatic.Middleware(
  THorseStatic.New('./media')
    .AcceptRanges(True) // Habilita o suporte a streaming por range (Ativo por padrão)
));
```

### 3. Mapeando Múltiplos Caminhos de Arquivos (Multi-Instance)
Por ser thread-safe e completamente isolado, você pode registrar múltiplos middlewares em rotas diferentes. Por exemplo, servindo arquivos estáticos públicos em uma pasta e imagens de uploads de usuários em outra:

```delphi
// Arquivos da aplicação web na raiz '/'
THorse.Use(THorseStatic.Middleware(
  THorseStatic.New('./public', '/')
    .CacheControl('public, max-age=3600')
));

// Uploads de usuários na rota '/uploads'
THorse.Use(THorseStatic.Middleware(
  THorseStatic.New('./uploads', '/uploads')
    .CacheControl('private, max-age=86400')
));
```

### 4. Controle Fino de Cache do Navegador (Cache-Control & ETags)
Você pode aumentar drasticamente a velocidade de carregamento dos recursos estáticos ajustando os cabeçalhos de controle de cache.

```delphi
THorse.Use(THorseStatic.Middleware(
  THorseStatic.New('./assets')
    .CacheControl('public, max-age=31536000, immutable') // Cache por 1 ano para arquivos estáticos com hash
    .UseETag(True)                                        // ETag fraca baseada no arquivo
    .UseLastModified(True)                                // Last-Modified baseado no arquivo
));
```

---

## 🔌 Criando um Provedor de Armazenamento Customizado

Se você precisar servir arquivos que não estão diretamente gravados no disco rígido local (por exemplo, ler arquivos salvos no banco de dados, na memória RAM ou em serviços na nuvem como AWS S3), basta implementar as interfaces `IHorseStaticFile` e `IHorseStaticStorage`.

Veja abaixo um exemplo simples de provedor em memória:

```delphi
uses
  System.Classes, System.SysUtils, Horse.Static.Storage;

type
  TMemoryFile = class(TInterfacedObject, IHorseStaticFile)
  private
    FName: string;
    FContent: string;
  public
    constructor Create(const AName, AContent: string);
    function GetName: string;
    function GetSize: Int64;
    function GetLastModified: TDateTime;
    function GetContentType: string;
    function GetContentStream: TStream;
  end;

  TMemoryStorage = class(TInterfacedObject, IHorseStaticStorage)
  public
    function Exists(const APath: string): Boolean;
    function GetFile(const APath: string): IHorseStaticFile;
  end;

{ TMemoryFile }

constructor TMemoryFile.Create(const AName, AContent: string);
begin
  FName := AName;
  FContent := AContent;
end;

function TMemoryFile.GetName: string;
begin
  Result := FName;
end;

function TMemoryFile.GetSize: Int64;
begin
  Result := Length(FContent);
end;

function TMemoryFile.GetLastModified: TDateTime;
begin
  Result := Now;
end;

function TMemoryFile.GetContentType: string;
begin
  Result := 'text/plain';
end;

function TMemoryFile.GetContentStream: TStream;
begin
  Result := TStringStream.Create(FContent);
end;

{ TMemoryStorage }

function TMemoryStorage.Exists(const APath: string): Boolean;
begin
  Result := SameText(APath, 'hello.txt');
end;

function TMemoryStorage.GetFile(const APath: string): IHorseStaticFile;
begin
  if Exists(APath) then
    Result := TMemoryFile.Create('hello.txt', 'Olá Mundo da Memória!')
  else
    Result := nil;
end;
```

Para injetar seu provedor customizado, utilize o método `.Storage(...)`:

```delphi
THorse.Use(THorseStatic.Middleware(
  THorseStatic.Config
    .Storage(TMemoryStorage.Create)
));
```

---

## 📖 Opções de Configuração

A estrutura fluente `THorseStaticConfig` possui as seguintes opções para parametrização:

| Método de Configuração | Tipo do Parâmetro | Valor Padrão | Descrição |
| :--- | :---: | :---: | :--- |
| **`Storage`** | `IHorseStaticStorage` | `THorseStaticLocalStorage` | O provedor responsável por buscar e validar os arquivos. |
| **`CacheControl`** | `string` | `''` | O cabeçalho HTTP `Cache-Control` a ser injetado na resposta. |
| **`UseETag`** | `Boolean` | `True` | Se ativado, gera e valida `ETags` (retornando HTTP 304 se inalterado). |
| **`UseLastModified`** | `Boolean` | `True` | Se ativado, adiciona e valida o header de data de modificação do arquivo (`Last-Modified`). |
| **`AcceptRanges`** | `Boolean` | `True` | Se ativado, processa requisições de range de bytes parciais (HTTP 206). |
| **`SpaFallback`** | `string` | `''` | Caminho do arquivo a ser retornado caso o recurso físico original não seja localizado. |

---

## 📄 Licença

Este projeto está licenciado sob a [Apache License 2.0](LICENSE).
