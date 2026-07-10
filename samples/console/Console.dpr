program Console;

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
  Horse.Static;

begin
  // Configura o middleware de arquivos estáticos apontando para a pasta local 'public'
  // com suporte a SPA fallback redirecionando para 'index.html' se necessário
  THorse.Use(THorseStatic.Middleware(
    THorseStatic.New('./public')
      .CacheControl('public, max-age=3600')
      .AcceptRanges(True)
      .UseETag(True)
      .SpaFallback('index.html')
  ));

  // Rotas normais de API continuam funcionando normalmente
  THorse.Get('/ping',
    procedure(Req: THorseRequest; Res: THorseResponse; Next: {$IF DEFINED(FPC)}TNextProc{$ELSE}TProc{$ENDIF})
    begin
      Res.Send('pong');
    end);

  Writeln('Servidor de Arquivos Estáticos rodando na porta 9000...');
  Writeln('Acesse: http://localhost:9000/ping para rota de API');
  Writeln('Acesse: http://localhost:9000/ para os arquivos estaticos');
  
  THorse.Listen(9000);
end.
