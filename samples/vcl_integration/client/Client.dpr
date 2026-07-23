program Client;

uses
  Vcl.Forms,
  MainForm in 'MainForm.pas' {FormCliente};

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TFormCliente, FormCliente);
  Application.Run;
end.
