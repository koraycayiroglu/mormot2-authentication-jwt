unit Main;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, mormot.core.base;

type
  TMainForm = class(TForm)
    cStartTest: TButton;
    eResult: TMemo;
    cClearLog: TButton;
    cRefreshToken: TButton;
    cCheckToken: TButton;
    procedure cStartTestClick(Sender: TObject);
    procedure cClearLogClick(Sender: TObject);
  private
    { Private declarations }
    procedure AddLog(const AText: RawUTF8);
    procedure ClearLog;
  public
    { Public declarations }
  end;

var
  MainForm: TMainForm;

implementation

uses RestServer.U_DTB, RestServer.U_JWT;

{$R *.dfm}

procedure TMainForm.AddLog(const AText: RawUTF8);
begin
  eResult.Lines.Add(AText);
end;

procedure TMainForm.cClearLogClick(Sender: TObject);
begin
  ClearLog;
end;

procedure TMainForm.ClearLog;
begin
  eResult.Clear;
end;

procedure TMainForm.cStartTestClick(Sender: TObject);
var fClient: TRestHttpClientJWT;
begin
  fClient := TRestHttpClientJWT.Create('127.0.0.1', '888', DTBModel('root'));

  if fClient.SetUser('User', 'synopse') then begin
    AddLog('User authenticate');
  end else begin
    AddLog('Authentication failed!');
    Exit;
  end;
end;

end.
