<p align="center">
  <a href="https://github.com/regyssilveira/horse-static/blob/master/img/logo.png">
    <img alt="Horse Static" height="150" src="https://github.com/HashLoad/horse/blob/master/img/horse.png">
  </a>
</p><br>
<p align="center">
  <b>horse-static</b> is a high-performance, thread-safe, and abstract static file serving middleware for the <b>Horse</b> web framework.
</p><br>

<p align="center">
  <i>Read this in <a href="./README.md">English</a> or <a href="./README.pt-BR.md">Português (BR)</a>.</i>
</p>

## ⚙️ Key Features

* 🚀 **HTTP 206 Range Support:** Native handling of partial requests, allowing video/audio streaming and resumable downloads.
* 📦 **Caching:** Weak ETags generated via metadata (`FileSize + ModifiedDate`) returning fast `304 Not Modified` responses.
* 🌐 **SPA Fallback:** Simple routing of virtual pages to a single index file (e.g. `index.html`) for React/Vue/Angular apps.
* 🛡️ **Security:** Built-in protection against Directory Traversal attacks.
* 🔌 **Abstract Storage Provider:** Independent storage architecture (`IHorseStaticStorage` interface) ready for AWS S3, memory, or custom file providers.
* 🧵 **Thread-Safe & Multi-Instance:** No global unit states. Safely deploy multiple instances pointing to different folders.

## ⚙️ Installation

Install the package via [Boss](https://github.com/HashLoad/boss):

```sh
boss install github.com/regyssilveira/horse-static
```

## ⚡️ Quickstart

```delphi
uses
  Horse,
  Horse.Static;

begin
  // Register static middleware for './public' physical folder mapping to root URL
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

## 📖 Configuration Options

The `THorseStaticConfig` record offers a fluent API:

* `Storage(const AValue: IHorseStaticStorage)`: Set a custom storage provider. (Default is `THorseStaticLocalStorage`).
* `CacheControl(const AValue: string)`: Set HTTP `Cache-Control` header (e.g. `'public, max-age=86400'`). Pass empty string to disable.
* `UseETag(const AValue: Boolean)`: Enable/Disable ETag generation and evaluation (Default is `True`).
* `UseLastModified(const AValue: Boolean)`: Enable/Disable `Last-Modified` validation (Default is `True`).
* `AcceptRanges(const AValue: Boolean)`: Enable/Disable HTTP 206 Range request handling (Default is `True`).
* `SpaFallback(const AIndexFile: string)`: File to serve (like `'index.html'`) when a requested physical path does not exist.

## ⚠️ License

`horse-static` is free and open-source software licensed under the [MIT License](LICENSE).
