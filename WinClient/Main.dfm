object MainForm: TMainForm
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = 'Connect'
  ClientHeight = 327
  ClientWidth = 448
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  TextHeight = 13
  object cStartTest: TButton
    Left = 8
    Top = 8
    Width = 100
    Height = 25
    Caption = 'Start Test'
    TabOrder = 0
    OnClick = cStartTestClick
  end
  object eResult: TMemo
    Left = 8
    Top = 39
    Width = 433
    Height = 242
    Lines.Strings = (
      '')
    TabOrder = 1
  end
  object cClearLog: TButton
    Left = 366
    Top = 287
    Width = 75
    Height = 25
    Caption = 'Clear Logs'
    TabOrder = 2
    OnClick = cClearLogClick
  end
  object cRefreshToken: TButton
    Left = 340
    Top = 8
    Width = 100
    Height = 25
    Caption = 'Refresh Token'
    TabOrder = 3
  end
  object cCheckToken: TButton
    Left = 234
    Top = 8
    Width = 100
    Height = 25
    Caption = 'Check Token'
    TabOrder = 4
  end
end
