object MainForm: TMainForm
  Left = 0
  Top = 0
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
    Width = 75
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
end
