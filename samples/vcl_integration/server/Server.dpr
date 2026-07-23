program Server;

{$APPTYPE CONSOLE}

{$IF DEFINED(FPC)}
  {$MODE DELPHI}{$H+}
{$ENDIF}

uses
  {$IF DEFINED(FPC)}
  Classes, SysUtils,
  {$ELSE}
  System.Classes, System.SysUtils,
  {$ENDIF}
  Horse,
  Horse.Jhonson,
  Horse.Static;

begin
  // 1. Registra o parseador de JSON globalmente (Jhonson)
  THorse.Use(Jhonson);

  // 2. Registra o Middleware de Arquivos Estáticos (horse-static) apontando para a pasta 'public'
  // Configurado de forma a servir os arquivos estáticos e suportar SPA Fallback
  THorse.Use(THorseStatic.Middleware(
    THorseStatic.New('./public')
      .CacheControl('public, max-age=3600')
      .AcceptRanges(True)
      .UseETag(True)
      .SpaFallback('index.html')
  ));

  // 3. Rota de API (Prefixada com /api para evitar colisão com o middleware estático)
  THorse.Get('/api/v1/status',
    procedure(Req: THorseRequest; Res: THorseResponse; Next: {$IF DEFINED(FPC)}TNextProc{$ELSE}TProc{$ENDIF})
    begin
      Res.Send('{"status": "online", "timestamp": "' + DateTimeToStr(Now) + '"}')
         .ContentType('application/json');
    end);

  Writeln('Servidor Horse com arquivos estaticos rodando na porta 9000...');
  Writeln('API: http://localhost:9000/api/v1/status');
  Writeln('Web: http://localhost:9000/');

  THorse.Listen(9000);
end.
