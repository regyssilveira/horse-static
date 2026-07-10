unit Tests.Integration.Static;

interface

uses
  DUnitX.TestFramework, Horse, Horse.Commons, Horse.Static, Horse.Static.Storage,
  Horse.Core.RouterTree, Horse.Core,
  RESTRequest4D, System.SysUtils, System.Classes, System.Types, System.StrUtils,
  System.IOUtils, System.DateUtils, System.Rtti, System.Generics.Collections;

type
  [TestFixture]
  TTestIntegrationStatic = class
  private
    const TEST_PORT = 9098;
    var FTestDir: string;
    procedure ClearGlobalState;
  public
    [SetupFixture]
    procedure SetupFixture;
    [TearDownFixture]
    procedure TearDownFixture;

    [Test]
    procedure TestServeFileReturnsHTTP200AndCorrectContent;
    [Test]
    procedure TestDirectoryTraversalReturnsHTTP404Or403;
    [Test]
    procedure TestCacheETagReturnsHTTP304NotModified;
    [Test]
    procedure TestRangeRequestReturnsHTTP206AndPartialBytes;
    [Test]
    procedure TestRangeRequestInvalidReturnsHTTP416;
    [Test]
    procedure TestSPAFallbackReturnsIndexHTML;
  end;

implementation

{ TTestIntegrationStatic }

procedure TTestIntegrationStatic.ClearGlobalState;
var
  LContext: TRttiContext;
  LType: TRttiInstanceType;
  LField: TRttiField;
  LList: TList<THorseCallback>;
begin
  THorse.StopListen;
  THorse.Routes := nil;
  THorse.Routes := THorseRouterTree.Create;
  THorse.Port := 9000;
  THorse.Host := '0.0.0.0';

  LContext := TRttiContext.Create;
  try
    LType := LContext.GetType(THorseCore) as TRttiInstanceType;
    if Assigned(LType) then
    begin
      LField := LType.GetField('FCallbacks');
      if Assigned(LField) then
      begin
        LList := TList<THorseCallback>(LField.GetValue(nil).AsObject);
        if Assigned(LList) then
          LList.Clear;
      end;
    end;

    LType := LContext.FindType('Horse.THorse') as TRttiInstanceType;
    if Assigned(LType) then
    begin
      LField := LType.GetField('FCallbacks');
      if Assigned(LField) then
      begin
        LList := TList<THorseCallback>(LField.GetValue(nil).AsObject);
        if Assigned(LList) then
          LList.Clear;
      end;
    end;
  finally
    LContext.Free;
  end;
end;

procedure TTestIntegrationStatic.SetupFixture;
var
  LIndexContent, LTestContent: string;
begin
  // Cria estrutura de arquivos de teste
  FTestDir := TPath.Combine(TPath.GetTempPath, 'horse_static_tests');
  if TDirectory.Exists(FTestDir) then
    TDirectory.Delete(FTestDir, True);
  TDirectory.CreateDirectory(FTestDir);

  LIndexContent := '<h1>SPA Fallback</h1>';
  TFile.WriteAllText(TPath.Combine(FTestDir, 'index.html'), LIndexContent);

  // Arquivo de 10 bytes para testar o range de bytes de forma exata
  LTestContent := '0123456789';
  TFile.WriteAllText(TPath.Combine(FTestDir, 'test.txt'), LTestContent);

  TDirectory.CreateDirectory(TPath.Combine(FTestDir, 'sub'));
  TFile.WriteAllText(TPath.Combine(FTestDir, 'sub/another.txt'), 'nested content');

  // Configura rotas no Horse
  THorse.Use(THorseStatic.Middleware(
    THorseStatic.New(FTestDir)
      .SpaFallback('index.html')
  ));

  TThread.CreateAnonymousThread(
    procedure
    begin
      THorse.Listen(TEST_PORT);
    end).Start;

  Sleep(1500); // Aguarda inicialização do socket listener
end;

procedure TTestIntegrationStatic.TearDownFixture;
begin
  ClearGlobalState;
  Sleep(500);
  if TDirectory.Exists(FTestDir) then
    TDirectory.Delete(FTestDir, True);
end;

procedure TTestIntegrationStatic.TestServeFileReturnsHTTP200AndCorrectContent;
var
  LRes: IResponse;
begin
  LRes := TRequest.New
    .BaseURL(Format('http://localhost:%d/test.txt', [TEST_PORT]))
    .Get;

  Assert.AreEqual(200, LRes.StatusCode);
  Assert.AreEqual('0123456789', LRes.Content);
  Assert.AreEqual('text/plain', LRes.ContentType);
  Assert.AreEqual('bytes', LRes.Headers.Values['Accept-Ranges']);
  Assert.AreEqual('10', LRes.Headers.Values['Content-Length']);
end;

procedure TTestIntegrationStatic.TestDirectoryTraversalReturnsHTTP404Or403;
var
  LRes: IResponse;
begin
  // Tenta subir níveis relativos
  LRes := TRequest.New
    .BaseURL(Format('http://localhost:%d/../../etc/passwd', [TEST_PORT]))
    .Get;

  // Como o arquivo não existirá na pasta raiz nem o fallback é aplicável,
  // o request deve retornar HTTP 404 (pois o middleware chama Next e não há rotas subsequentes mapeadas).
  Assert.AreEqual(404, LRes.StatusCode);
end;

procedure TTestIntegrationStatic.TestCacheETagReturnsHTTP304NotModified;
var
  LRes: IResponse;
  LETag: string;
begin
  // Primeira requisição para pegar a ETag
  LRes := TRequest.New
    .BaseURL(Format('http://localhost:%d/test.txt', [TEST_PORT]))
    .Get;

  Assert.AreEqual(200, LRes.StatusCode);
  LETag := LRes.Headers.Values['ETag'];
  Assert.AreNotEqual('', LETag);

  // Segunda requisição simulando cache do navegador enviando o If-None-Match
  LRes := TRequest.New
    .BaseURL(Format('http://localhost:%d/test.txt', [TEST_PORT]))
    .AddHeader('If-None-Match', LETag)
    .Get;

  Assert.AreEqual(304, LRes.StatusCode);
  Assert.AreEqual('', LRes.Content); // Corpo vazio
end;

procedure TTestIntegrationStatic.TestRangeRequestReturnsHTTP206AndPartialBytes;
var
  LRes: IResponse;
begin
  // Solicita range parcial dos primeiros 5 bytes (0-4)
  LRes := TRequest.New
    .BaseURL(Format('http://localhost:%d/test.txt', [TEST_PORT]))
    .AddHeader('Range', 'bytes=0-4')
    .Get;

  Assert.AreEqual(206, LRes.StatusCode);
  Assert.AreEqual('01234', LRes.Content); // Primeiros 5 bytes de '0123456789'
  Assert.AreEqual('bytes 0-4/10', LRes.Headers.Values['Content-Range']);
  Assert.AreEqual('5', LRes.Headers.Values['Content-Length']);

  // Solicita range aberto a partir do byte 5 (5-)
  LRes := TRequest.New
    .BaseURL(Format('http://localhost:%d/test.txt', [TEST_PORT]))
    .AddHeader('Range', 'bytes=5-')
    .Get;

  Assert.AreEqual(206, LRes.StatusCode);
  Assert.AreEqual('56789', LRes.Content);
  Assert.AreEqual('bytes 5-9/10', LRes.Headers.Values['Content-Range']);
  Assert.AreEqual('5', LRes.Headers.Values['Content-Length']);
end;

procedure TTestIntegrationStatic.TestRangeRequestInvalidReturnsHTTP416;
var
  LRes: IResponse;
begin
  // Range inicial maior que o final ou extrapolado
  LRes := TRequest.New
    .BaseURL(Format('http://localhost:%d/test.txt', [TEST_PORT]))
    .AddHeader('Range', 'bytes=15-20')
    .Get;

  Assert.AreEqual(416, LRes.StatusCode);
  Assert.AreEqual('bytes */10', LRes.Headers.Values['Content-Range']);
end;

procedure TTestIntegrationStatic.TestSPAFallbackReturnsIndexHTML;
var
  LRes: IResponse;
begin
  // Solicita uma rota virtual que não existe fisicamente (ex: /dashboard/relatorios)
  LRes := TRequest.New
    .BaseURL(Format('http://localhost:%d/dashboard/relatorios', [TEST_PORT]))
    .Get;

  // Como o SPA fallback está ativo e index.html existe, deve servir index.html com HTTP 200
  Assert.AreEqual(200, LRes.StatusCode);
  Assert.AreEqual('<h1>SPA Fallback</h1>', LRes.Content);
  Assert.AreEqual('text/html', LRes.ContentType);
end;

initialization
  TDUnitX.RegisterTestFixture(TTestIntegrationStatic);

end.
