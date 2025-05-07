program JWTServer;

{$I mormot.defines.inc}

{$ifdef OSWINDOWS}
  {$APPTYPE CONSOLE}
{$endif}

{$R *.res}

uses
  sysutils,
  mormot.core.base,
  mormot.core.log,
  mormot.db.raw.sqlite3,
  mormot.db.raw.sqlite3.static,
  mormot.core.data,
  mormot.core.os,
  mormot.core.text,
  mormot.core.json,
  mormot.core.search,
  mormot.core.buffers,
  mormot.core.unicode,
  mormot.rest.core,
  mormot.rest.server,
  mormot.rest.sqlite3,
  mormot.rest.http.server,
  JWTServer.U_RESTServer in 'JWTServer.U_RESTServer.pas',
  RestServer.U_JWT in '..\Common\RestServer.U_JWT.pas',
  RestServer.U_Data in '..\Common\RestServer.U_Data.pas',
  RestServer.U_Const in '..\Common\RestServer.U_Const.pas',
  JWTServer.U_Start in 'JWTServer.U_Start.pas',
  RestServer.U_DTB in '..\Common\RestServer.U_DTB.pas',
  RestServer.I_Sample in '..\Common\RestServer.I_Sample.pas',
  RestServer.U_Sample in '..\Common\RestServer.U_Sample.pas';

begin
  try
    with TSynLog.Family do
    begin
      Level := LOG_VERBOSE;
      EchoToConsole := LOG_VERBOSE;
      NoFile := True;
      LocalTimestamp := true;
    end;

    InitializeServer;
    try
      Writeln('Press [Enter] to close server and exit.'#10);
      ConsoleWaitForEnterKey;
    finally
      if Assigned(MainServer) then
        FreeAndNil(MainServer);
    end;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
