object FormCliente: TFormCliente
  Left = 0
  Top = 0
  BorderIcons = [biSystemMenu, biMinimize]
  BorderStyle = bsSingle
  Caption = 'Cliente de Integracao Horse (Static)'
  ClientHeight = 330
  ClientWidth = 520
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poScreenCenter
  TextHeight = 15
  object lblDesc: TLabel
    Left = 16
    Top = 16
    Width = 488
    Height = 30
    AutoSize = False
    Caption = 
      'Exemplo de consumo defensivo de API Horse que roda em conjunto c' +
      'om middleware de arquivos estaticos.'
    WordWrap = True
  end
  object btnGetStatus: TButton
    Left = 16
    Top = 56
    Width = 488
    Height = 35
    Caption = 'Consultar API (/api/v1/status)'
    TabOrder = 0
    OnClick = btnGetStatusClick
  end
  object mmoResponse: TMemo
    Left = 16
    Top = 104
    Width = 488
    Height = 209
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -12
    Font.Name = 'Consolas'
    Font.Style = []
    ParentFont = False
    ReadOnly = True
    ScrollBars = ssVertical
    TabOrder = 1
  end
end
