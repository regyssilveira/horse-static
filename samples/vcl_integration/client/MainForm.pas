unit MainForm;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, System.Net.HttpClient, System.Json;

type
  TFormCliente = class(TForm)
    btnGetStatus: TButton;
    mmoResponse: TMemo;
    lblDesc: TLabel;
    procedure btnGetStatusClick(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  FormCliente: TFormCliente;

implementation

{$R *.dfm}

procedure TFormCliente.btnGetStatusClick(Sender: TObject);
var
  LClient: THTTPClient;
  LResponse: IHTTPResponse;
  LJSON: TJSONObject;
begin
  LClient := THTTPClient.Create;
  try
    mmoResponse.Lines.Clear;
    mmoResponse.Lines.Add('Enviando requisicao GET para o servidor...');

    try
      // Faz o request ao endpoint da API
      LResponse := LClient.Get('http://localhost:9000/api/v1/status');
    except
      on E: Exception do
      begin
        mmoResponse.Lines.Add('Erro de Conexao: O servidor esta ativo na porta 9000?');
        mmoResponse.Lines.Add('Mensagem: ' + E.Message);
        Exit;
      end;
    end;

    mmoResponse.Lines.Add('HTTP Status: ' + LResponse.StatusCode.ToString + ' ' + LResponse.StatusText);
    mmoResponse.Lines.Add('Mime-Type retornado: ' + LResponse.MimeType);
    mmoResponse.Lines.Add('--------------------------------------------------');

    // VALIDACAO DEFENSIVA:
    // Garante que o status eh de sucesso (200 OK) e o tipo de conteudo retornado eh application/json.
    // Se o middleware estatico interceptasse ou a rota nao existisse, retornaria 'text/html'
    if (LResponse.StatusCode = 200) and LResponse.MimeType.Contains('application/json') then
    begin
      try
        LJSON := TJSONObject.ParseJSONValue(LResponse.ContentAsString) as TJSONObject;
        if Assigned(LJSON) then
        begin
          try
            mmoResponse.Lines.Add('Decodificado com sucesso:');
            mmoResponse.Lines.Add('  - Status do Servidor: ' + LJSON.GetValue<string>('status'));
            mmoResponse.Lines.Add('  - Timestamp: ' + LJSON.GetValue<string>('timestamp'));
          finally
            LJSON.Free;
          end;
        end
        else
        begin
          mmoResponse.Lines.Add('O conteudo retornado nao eh um JSON valido.');
        end;
      except
        on E: Exception do
          mmoResponse.Lines.Add('Falha ao processar o JSON: ' + E.Message);
      end;
    end
    else
    begin
      // Ocorre se houver erro ou se cair no Fallback de arquivos estáticos (HTML)
      mmoResponse.Lines.Add('ATENCAO: Resposta nao-JSON recebida do servidor!');
      mmoResponse.Lines.Add('Provavel colisao de rota ou resposta de arquivo estatico.');
      mmoResponse.Lines.Add('');
      mmoResponse.Lines.Add('Corpo bruto da resposta:');
      mmoResponse.Lines.Add(LResponse.ContentAsString);
    end;

  finally
    LClient.Free;
  end;
end;

end.
