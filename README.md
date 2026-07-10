# Horse Static

Middleware de serviço de arquivos estáticos de alta performance, thread-safe e abstrato para o framework web **Horse**.

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

```delphi
uses
  Horse,
  Horse.Static;

begin
  // Registra o middleware mapeando a pasta física './public' para a URL raiz
  THorse.Use(THorseStatic.Middleware(
    THorseStatic.New('./public')
      .CacheControl('public, max-age=3600')
      .AcceptRanges(True)
      .UseETag(True)
      .SpaFallback('index.html')
  ));

  THorse.Listen(9000);
end.
```

---

## 📖 Opções de Configuração

O record `THorseStaticConfig` possui uma API fluente (*Fluent API*):

* `Storage(const AValue: IHorseStaticStorage)`: Define um provedor de armazenamento customizado (Padrão: `THorseStaticLocalStorage`).
* `CacheControl(const AValue: string)`: Injeta o cabeçalho HTTP `Cache-Control` (ex: `'public, max-age=86400'`). Passe string vazia para desabilitar.
* `UseETag(const AValue: Boolean)`: Habilita ou desabilita a geração e validação de ETags (Padrão: `True`).
* `UseLastModified(const AValue: Boolean)`: Habilita ou desabilita a validação de data de última modificação (Padrão: `True`).
* `AcceptRanges(const AValue: Boolean)`: Habilita ou desabilita o processamento de HTTP 206 Range (Padrão: `True`).
* `SpaFallback(const AIndexFile: string)`: Define o arquivo padrão (ex: `'index.html'`) para servir quando uma pasta ou arquivo virtual solicitado não existir fisicamente.

---

## 📄 Licença

Licenciado sob a licença [MIT](LICENSE).
