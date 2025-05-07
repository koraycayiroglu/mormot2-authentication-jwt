unit JWTServer.U_Start;

interface

uses
  mormot.core.base,
  mormot.rest.core,
  mormot.rest.sqlite3,
  mormot.rest.http.server,
  mormot.rest.server,
  mormot.orm.core,
  mormot.soa.core,
  JWTServer.U_RESTServer,
  RestServer.U_JWT,
  RestServer.U_DTB;

procedure InitializeServer;
procedure FinalizeServer;

implementation

uses
  RestServer.I_Sample,
  RestServer.U_Sample;

procedure InitializeServer;
var
  LInitialized: Boolean;
  LParams: TRestServerSettings;
  TmpData : TSampleData;
begin
  LInitialized := MainServer.Initialized;
  if LInitialized then
    MainServer.DeInitialize();

  LParams := TRestServerSettings.Create();
  LParams.Port := '888';
  LParams.Protocol := HTTPsys;
  LParams.AuthenticationMode := lAuthenticationMode.JWT_HS256;
  LParams.AuthenticationJWTClass := TRestServerAuthenticationJWT;

  LParams.WEBSERVER_URIROOT := 'root';
  LParams.AuthSessionClass := TAuthSession;
  LParams.DefineRegisterServices(
    procedure(const AServer: TRestServerDB)
    begin
      if not Assigned(AServer) then
        Exit;
      AServer.ServiceDefine(TSample, [ISample], sicPerSession,
        SERVICE_CONTRACT_NONE_EXPECTED).
          ResultAsJsonObjectWithoutResult := true;
    end);
  LParams.DefineRegisterOrmModels(
    function(const ARoot: RawUtf8): TOrmModel
    begin
      Result := DTBModel(ARoot);
    end);

  MainServer.Initialize(LParams);

  // Make sample data
  if MainServer.RestServer.Orm.TableRowCount(TSampleData) = 0 then
  begin
    TmpData := TSampleData.Create;
    try
      TmpData.FirstName := 'Synopse';
      TmpData.LastName  := 'Mormot';
      MainServer.RestServer.Orm.Add(TmpData, true);

      TmpData.FirstName := 'Arnaud';
      TmpData.LastName  := 'Bouchez';
      MainServer.RestServer.Orm.Add(TmpData, true);

      TmpData.FirstName := 'Sample';
      TmpData.LastName  := 'Test';
      MainServer.RestServer.Orm.Add(TmpData, true);
    finally
      TmpData.Free;
    end;
  end;
end;

procedure FinalizeServer;
begin
  MainServer.DeInitialize;
end;

end.
