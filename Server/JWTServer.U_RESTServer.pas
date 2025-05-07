unit JWTServer.U_RESTServer;

interface

uses
  sysutils, classes,
  mormot.core.base,
  mormot.core.os,
  mormot.core.variants,
  mormot.core.datetime,
  mormot.core.text,
  mormot.core.rtti,
  mormot.core.unicode,
  mormot.core.buffers,
  mormot.orm.core,
  mormot.db.raw.sqlite3,
  mormot.db.raw.sqlite3.static,
  mormot.rest.core,
  mormot.rest.sqlite3,
  mormot.rest.server,
  mormot.rest.http.server,
  mormot.net.http,
  mormot.net.server,
  mormot.crypt.core,
  mormot.crypt.secure,
  mormot.crypt.jwt,
  RestServer.U_JWT,
  RestServer.U_Data;

type
  TRegisterServicesCallBack = reference to procedure(const aServer: TRestServerDB);
  TRegisterOrmModels = reference to function(const aRoot: RawUtf8): TOrmModel;

  TServerDTB = class(TRestServerDB)
  published
    function IsValidToken(aParams: TRestServerURIContext): Integer;
    function RefreshToken(aParams: TRestServerURIContext): Integer;
  end;

  lProtocol = (HTTP_Socket                       = 0,
               HTTPsys                           = 1,
               HTTPsys_SSL                       = 2,
               HTTPsys_AES                       = 3,
               HTTP_WebSocket                    = 4,
               WebSocketBidir_JSON               = 5,
               WebSocketBidir_Binary             = 6,
               WebSocketBidir_BinaryAES          = 7,
               NamedPipe                         = 8);

  lAuthenticationMode = (Default                 = 1,  // AES256
                         None                    = 2,
                         HttpBasic               = 3,
                         SSPI                    = 4,
                         JWT_HS256               = 5,
                         JWT_HS384               = 6,
                         JWT_HS512               = 7,
                         JWT_S3224               = 8,
                         JWT_S3256               = 9,
                         JWT_S3384               = 10,
                         JWT_S3512               = 11,
                         JWT_S3S128              = 12,
                         JWT_S3S256              = 13
                         );

const
  AUTH_ISJWT : array[lAuthenticationMode] of Boolean =
    (False, False, False, False,
     True, True, True, True,
     True, True, True, True,
     True);

  AUTH_ALGO : array[lAuthenticationMode] of TSignAlgo =
    (saSha1, saSha1, saSha1, saSha1,
     saSha256, saSha384, saSha512,
     saSha3224, saSha3256, saSha3384, saSha3512,
     saSha3S128, saSha3S128);

type
  TRestServerSettings = class
  private
    FRegisterServices   : TRegisterServicesCallBack;
    FOrmModels          : TRegisterOrmModels;
    FAuthSessionClass   : TAuthSessionClass;
    FAuthenticationJWTClass: TRestServerAuthenticationJWTClass;

    FProtocol           : lProtocol;
    FPort               : string;
    FWEBSERVER_URIROOT  : RawByteString;
    FNAMED_PIPE_NAME    : TFileName;
    FAuthenticationMode : lAuthenticationMode;
  public
    constructor Create;
    destructor Destroy; override;

    procedure DefineRegisterOrmModels(const AFunc: TRegisterOrmModels);
    function  OrmModels: TRegisterOrmModels;

    procedure DefineRegisterServices(const AFunc: TRegisterServicesCallBack);
    function  RegisterServices: TRegisterServicesCallBack;

    property AuthSessionClass: TAuthSessionClass
      read FAuthSessionClass write FAuthSessionClass;
    property AuthenticationJWTClass: TRestServerAuthenticationJWTClass
      read FAuthenticationJWTClass write fAuthenticationJWTClass;

    property Protocol: lProtocol read FProtocol write FProtocol;
    property Port: string read FPort write FPort;
    property WEBSERVER_URIROOT: RawByteString read FWEBSERVER_URIROOT
      write FWEBSERVER_URIROOT;
    property AuthenticationMode: lAuthenticationMode read FAuthenticationMode
      write FAuthenticationMode;
  end;

  TMainServer = class
  private
    FModel         : TOrmModel;
    FRestServer    : TServerDTB;
    FHTTPServer    : TRestHttpServer;
    FServerSettings: TRestServerSettings;
    FInitialized   : boolean;
  public
    constructor Create;
    destructor Destroy; override;

    function Initialize(SrvSettings: TRestServerSettings): Boolean;
    function DeInitialize: Boolean;
    function Settings: TRestServerSettings;

    property Initialized: Boolean    read FInitialized;
    property RestServer : TServerDTB read FRestServer;
  end;

var
  MainServer: TMainServer;

implementation

{ TRestServerSettings }

constructor TRestServerSettings.Create;
begin
  inherited;
  Port                := '80';
  AuthenticationMode  := lAuthenticationMode.Default;
  Protocol            := HTTP_Socket;
  FRegisterServices   := nil;
  FOrmModels          := nil;
  fAuthSessionClass   := TAuthSession;
  fAuthenticationJWTClass := TRestServerAuthenticationJWT;
end;

procedure TRestServerSettings.DefineRegisterServices(
  const aFunc: TRegisterServicesCallBack);
begin
  FRegisterServices := nil;
  FRegisterServices := aFunc;
end;

procedure TRestServerSettings.DefineRegisterOrmModels(
  const aFunc: TRegisterOrmModels);
begin
  FOrmModels := nil;
  FOrmModels := AFunc;
end;

destructor TRestServerSettings.Destroy;
begin
  FRegisterServices := nil;
  FOrmModels        := nil;
  inherited;
end;

function TRestServerSettings.RegisterServices: TRegisterServicesCallBack;
begin
  Result := FRegisterServices;
end;

function TRestServerSettings.OrmModels: TRegisterOrmModels;
begin
  Result := FOrmModels;
end;

{ TRestServer }

constructor TMainServer.Create;
begin
  inherited;
  fInitialized := False;
end;

function TMainServer.DeInitialize: boolean;
begin
  Result := True;
  try
    if Assigned(fHTTPServer) and (fHTTPServer.ClassType = TRestHttpServer) then
      THttpApiServer(fHTTPServer).RemoveUrl(fServerSettings.WEBSERVER_URIROOT, fHTTPServer.Port, fServerSettings.Protocol = HTTPsys_SSL, '+');
    if Assigned(fHTTPServer) then
      FreeAndNil(fHTTPServer);
    if Assigned(fRestServer) then
      FreeAndNil(fRestServer);
    if Assigned(fModel) then
      FreeAndNil(fModel);

    fInitialized := false;
  except
    on E: Exception do
      begin
        ConsoleWrite(E.Message, ccRed);
        Result := False;
      end;
  end;
end;

destructor TMainServer.Destroy;
begin
  DeInitialize();
  if fServerSettings <> nil then
    fServerSettings.Free;
  inherited;
end;

function TMainServer.Initialize(SrvSettings: TRestServerSettings): Boolean;
var
  vRight: TAuthGroup;
  vUser : TJwtAuthUser;
  vPath : TFileName;
  vGuid : TGUID;
begin
  Result        := False;
  fInitialized  := False;

  if not assigned(SrvSettings) then
    Exit;
  if not assigned(SrvSettings.FRegisterServices) then
  begin
    raise Exception.Create('SrvSettings.FRegisterServices is nil');
    Exit;
  end;

  if DeInitialize() then
  try
    // RestServer initialization (database)
    vPath := MakePath([Executable.ProgramFilePath, Executable.ProgramName+'.edb']);
    if Assigned(SrvSettings.FOrmModels) then
      fModel := SrvSettings.FOrmModels(SrvSettings.WEBSERVER_URIROOT)
    else
      fModel := DTBModelBase(SrvSettings.WEBSERVER_URIROOT);
    fRestServer := TServerDTB.Create(fModel, vPath, true);

    if SrvSettings.AuthSessionClass = nil then
      raise Exception.Create('AuthSessionClass Not defined');
    fRestServer.fSessionClass := SrvSettings.AuthSessionClass; // Inject Custom TAuthSession

    fRestServer.DB.Synchronous := smOff;
    fRestServer.DB.LockingMode := lmNormal;
    fRestServer.DB.UseCache    := false;
    fRestServer.Server.CreateMissingTables;

    SrvSettings.FRegisterServices(fRestServer);

    if assigned(fServerSettings) then
      FServerSettings.Free;
    FServerSettings := nil;
    FServerSettings := SrvSettings;

    if AUTH_ISJWT[fServerSettings.AuthenticationMode] then
    begin
      fRestServer.ServiceMethodByPassAuthentication('IsValidToken');
      fRestServer.ServiceMethodByPassAuthentication('RefreshToken');
    end;

    //AddToServerWrapperMethod(fRestServer, [vPathTemplate]);

    fRestServer.AuthenticationUnregisterAll;
    // Authentification initialization
    case fServerSettings.AuthenticationMode of
      Default           : fRestServer.AuthenticationRegister(TRestServerAuthenticationDefault);
      None              : fRestServer.AuthenticationRegister(TRestServerAuthenticationNone);
      HttpBasic         : fRestServer.AuthenticationRegister(TRestServerAuthenticationHttpBasic);
      JWT_HS256, JWT_HS384, JWT_HS512, JWT_S3224,
      JWT_S3256, JWT_S3384, JWT_S3512, JWT_S3S128, JWT_S3S256 :
      begin
        fRestServer.AuthenticationRegister(fServerSettings.AuthenticationJWTClass);
        fRestServer.ServicesRouting := TRestRoutingREST_JWT;
        CreateGUID(vGUID);
        fRestServer.JWTForUnauthenticatedRequest := JWT_CLASS[AUTH_ALGO[fServerSettings.AuthenticationMode]].Create(SHA256(GUIDToRawUTF8(vGUID)), 0, [jrcIssuer, jrcSubject], [], JWTDefaultTimeout);
      end;
      {$IFDEF SPPIAUTH}
      SSPI              : fRestServer.AuthenticationRegister(TSQLRestServerAuthenticationSSPI);
      {$ENDIF}
      else begin
        DeInitialize();
        raise Exception.Create('Authentification sélectionnée non disponible dans cette version.');
      end;
    end;

    // protocol initialization (HttpServer)
    case fServerSettings.Protocol of
      HTTP_Socket:
        begin
          fHTTPServer := TRestHttpServer.Create(AnsiString(fServerSettings.Port), [fRestServer], '+',
            useHttpSocket);
          //fHTTPServer.HttpServer.ServerKeepAliveTimeOut := CONNECTION_TIMEOUT;
        end;
      HTTPsys:
        begin
          fHTTPServer := TRestHttpServer.Create(AnsiString(fServerSettings.Port), [fRestServer], '+', useHttpApiRegisteringURI);
          //TRestHttpServer(fHTTPServer.HttpServer).ServerKeepAliveTimeOut := CONNECTION_TIMEOUT;
        end;
      HTTPsys_SSL:
        begin
          fHTTPServer := TRestHttpServer.Create(AnsiString(fServerSettings.Port), [fRestServer], '+', useHttpApiRegisteringURI, 32, TRestHttpServerSecurity.secTLS);
          //THttpServer(fHTTPServer.HttpServer).ServerKeepAliveTimeOut := CONNECTION_TIMEOUT;
        end;
      {$ifndef PUREMORMOT2}
      HTTPsys_AES:
        begin
          fHTTPServer := TRestHttpServer.Create(AnsiString(fServerSettings.Port), [fRestServer], '+', useHttpApiRegisteringURI, 32, TRestHttpServerSecurity.secSynShaAes);
          THttpServer(fHTTPServer.HttpServer).ServerKeepAliveTimeOut := CONNECTION_TIMEOUT;
        end;
      {$endif}
      HTTP_WebSocket:
        begin
          fHTTPServer := TRestHttpServer.Create(AnsiString(fServerSettings.Port), [fRestServer], '+', useBidirSocket);
          //TresthttWebSocketServerRest(fHTTPServer.HttpServer).ServerKeepAliveTimeOut := CONNECTION_TIMEOUT;
        end;
      WebSocketBidir_JSON:
        begin
          fHTTPServer := TRestHttpServer.Create(AnsiString(fServerSettings.Port), [fRestServer], '+', useBidirSocket);
          //TWebSocketServerRest(fHTTPServer.HttpServer).ServerKeepAliveTimeOut := CONNECTION_TIMEOUT;
          fHTTPServer.WebSocketsEnable(fRestServer, '', True);
        end;
      WebSocketBidir_Binary:
        begin
          fHTTPServer := TRestHttpServer.Create(AnsiString(fServerSettings.Port), [fRestServer], '+', useBidirSocket);
          //TWebSocketServerRest(fHTTPServer.HttpServer).ServerKeepAliveTimeOut := CONNECTION_TIMEOUT;
          fHTTPServer.WebSocketsEnable(fRestServer, '', false);
        end;
      WebSocketBidir_BinaryAES:
        begin
          fHTTPServer := TRestHttpServer.Create(AnsiString(fServerSettings.Port), [fRestServer], '+', useBidirSocket);
          //TWebSocketServerRest(fHTTPServer.HttpServer).ServerKeepAliveTimeOut := CONNECTION_TIMEOUT;
          fHTTPServer.WebSocketsEnable(fRestServer, 'meow_key', false); // #TODO1 : Revoir la clé
        end;
      {NamedPipe:
        begin
          if not fRestServer.ExportServerNamedPipe(SrvSettings.NAMED_PIPE_NAME) then
            Exception.Create('Impossible d''enregistrer le serveur sur la couche Name Pipe.');
        end;}
    else
      begin
        DeInitialize();
        raise Exception.CreateFmt('Protocol %s not available on this version', [
          GetEnumName(TypeInfo(lProtocol), ord(fServerSettings.Protocol))]);
      end;
    end;
    fHTTPServer.AccessControlAllowOrigin := '*';
    Result := True;
  except
    on E: Exception do
      begin
        ConsoleWrite(E.ToString, ccRed);
        DeInitialize;
      end;
  end;
  fInitialized := Result;
end;

function TMainServer.Settings: TRestServerSettings;
begin
  Result := fServerSettings;
end;

{ TServerDTB }

function TServerDTB.IsValidToken(aParams: TRestServerURIContext): Integer;
var
  JWTContent : TJWTContent;
  vResult : TDocVariantData;
  nowunix : TUnixTime;
  unix : Cardinal;
  _result : Boolean;
  vExpired : TDateTime;
  jWtClass : TJWTSynSignerAbstractClass;
  TokenSesID : Cardinal;
  SessionExist : Boolean;
  i : Integer;
begin
  result := HTTP_UNAVAILABLE;
  try
    if not Assigned(MainServer.RestServer) then
    begin
      aParams.Returns('Server not initialized', HTTP_NOTFOUND);
      Exit;
    end;

    if not Assigned(MainServer.RestServer.JWTForUnauthenticatedRequest) then
    begin
      aParams.Returns('TRestServerAuthenticationJWT not initialized', HTTP_NOTFOUND);
      Exit;
    end;

    jwtClass := JWT_CLASS[getAlgo(MainServer.RestServer.JWTForUnauthenticatedRequest.Algorithm)];
    _Result := ServiceRunningContext.Request.AuthenticationCheck((MainServer.RestServer.JWTForUnauthenticatedRequest as jwtClass));
    if not _result then
      aParams.Returns(ToText(ServiceRunningContext.Request.JWTContent.Result)^, HTTP_FORBIDDEN)
    else
    begin
      SessionExist := False;
      if MainServer.RestServer.Sessions <> nil then
      begin
        TokenSesID := GetCardinal(
          Pointer(ServiceRunningContext.Request.JWTContent.data.U['sessionkey']));
        if TokenSesID > 0 then
          for i := 0 to pred(MainServer.RestServer.Sessions.Count) do
          begin
            if (TAuthSession(MainServer.RestServer.Sessions[i]).ID = TokenSesID) then
            begin
              SessionExist := True;
              Break;
            end;
          end;
      end;

      if SessionExist then
      begin
        vResult.InitFast;
        if jrcExpirationTime in ServiceRunningContext.Request.JWTContent.claims then
           if ToCardinal(ServiceRunningContext.Request.
             JWTContent.reg[jrcExpirationTime], unix) then
           begin
             nowunix := UnixTimeUTC;
             vExpired := UnixTimeToDateTime(unix - nowunix);
             vResult.AddValue('ExpiredIn', FormatDateTime('hh:nn:ss', vExpired));
           end
           else
             vResult.AddValue('ExpiredIn','');
        aParams.Returns(Variant(vResult), HTTP_SUCCESS);
      end
      else
        aParams.Returns('Session unknown', HTTP_FORBIDDEN);
    end;
  Except
    on e : exception do
     aParams.Returns(StringToUTF8(e.Message), HTTP_NOTFOUND);
  end;
end;

function TServerDTB.RefreshToken(aParams: TRestServerURIContext): Integer;
var
  Token, vUserName, vPassword, signat: RawUTF8;
  vResult: TDocVariantData;
  jWtClass: TJWTSynSignerAbstractClass;
  User: TAuthUser;
  i: Integer;
  TokenSesID: Cardinal;
  SessionExist: Boolean;
  NewSession: TAuthSession;
  nowunix: TUnixTime;
  unix: Cardinal;
begin
  result := HTTP_UNAVAILABLE;
  try
    if not Assigned(MainServer.RestServer) then begin
      aParams.Returns('Server not initialized', HTTP_NOTFOUND);
      Exit;
    end;

    if not Assigned(MainServer.RestServer.JWTForUnauthenticatedRequest) then begin
      aParams.Returns('TRestServerAuthenticationJWT not initialized', HTTP_NOTFOUND);
      Exit;
    end;
    if UrlDecodeNeedParameters(aParams.Parameters,'USERNAME,PASSWORD') then
    begin
      while aParams.Parameters<>nil do
      begin
        UrlDecodeValue(aParams.Parameters,'USERNAME=',    vUserName,   @aParams.Parameters);
        UrlDecodeValue(aParams.Parameters,'PASSWORD=',    vPassword,   @aParams.Parameters);
      end;

      vResult.InitFast;

      jwtClass := JWT_CLASS[getAlgo(MainServer.RestServer.JWTForUnauthenticatedRequest.Algorithm)];
      Token := ServiceRunningContext.Request.AuthenticationBearerToken;
      ServiceRunningContext.Request.AuthenticationCheck((MainServer.RestServer.JWTForUnauthenticatedRequest as jwtClass));

      if ServiceRunningContext.Request.JWTContent.result in [jwtValid, jwtExpired] then
      begin
        User := MainServer.RestServer.fAuthUserClass.Create(MainServer.RestServer.Orm,'LogonName=?',[vUserName]);
        if Assigned(User) then
        try
          if User.ID <= 0 then
            aParams.Returns('Unknown user', HTTP_FORBIDDEN)
          else
          if SameTextU(User.PasswordHashHexa, SHA256('salt' + vPassword)) or
                  SameTextU(User.PasswordHashHexa, vPassword) then
          begin
            SessionExist := False;
            if MainServer.RestServer.Sessions <> nil then
            begin
              TokenSesID := GetCardinal(Pointer(ServiceRunningContext.Request.JWTContent.data.U['sessionkey']));
              if TokenSesID > 0 then
                for i := 0 to pred(MainServer.RestServer.Sessions.Count) do
                begin
                  if (TAuthSession(MainServer.RestServer.Sessions[i]).UserID = User.ID) and
                     (TAuthSession(MainServer.RestServer.Sessions[i]).ID = TokenSesID) then
                  begin
                    SessionExist := True;
                    Break;
                  end;
                end;
            end;

            if SessionExist and (ServiceRunningContext.Request.JWTContent.result = jwtValid) then
            begin
              // Nothing to do ! just return current Token
              vResult.AddValue('jwt', Token);
              aParams.Returns(Variant(vResult), HTTP_SUCCESS);
            end
            else
            begin
              if (ServiceRunningContext.Request.JWTContent.result = jwtExpired) then
                if jrcExpirationTime in ServiceRunningContext.Request.JWTContent.claims then
                  if ToCardinal(ServiceRunningContext.Request.JWTContent.reg[jrcExpirationTime],unix) then
                  begin
                    nowunix := UnixTimeUTC;
                    if UnixTimeToDateTime(nowunix - unix) > JWTDefaultRefreshTimeOut then
                    begin
                      aParams.Returns('jwt : expiration time to long', HTTP_FORBIDDEN);
                      Exit;
                    end;
                  end;

              jwtClass := JWT_CLASS[getAlgo(MainServer.RestServer.JWTForUnauthenticatedRequest.Algorithm)];
              if SessionExist then
                Token := (MainServer.RestServer.JWTForUnauthenticatedRequest as jwtClass)
                             .Compute(['sessionkey', Variant(ServiceRunningContext.Request.JWTContent.data.U['sessionkey'])],
                                       vUserName,
                                       'jwt.access',
                                       '',
                                       0, JWTDefaultTimeout, @Signat)
              else
              begin
                MainServer.RestServer.SessionCreate(User, ServiceRunningContext.Request, NewSession);
                if NewSession <> nil then
                  Token := (MainServer.RestServer.JWTForUnauthenticatedRequest as jwtClass)
                             .Compute(['sessionkey', ToUtf8(NewSession.ID) +
                                       '+' + NewSession.PrivateKey],
                                       vUserName,
                                       'jwt.access',
                                       '',
                                       0, JWTDefaultTimeout, @Signat)
                else
                begin
                  aParams.Returns('Invalid sessionCreate result', HTTP_FORBIDDEN);
                  Exit;
                end;
              end;
              vResult.AddValue('jwt', Token);
              aParams.Returns(Variant(vResult), HTTP_SUCCESS);
            end;
          end
          else
            aParams.Returns('Invalid password', HTTP_FORBIDDEN);
        finally
          User.Free;
        end
        else
          aParams.Returns('Unknown user', HTTP_FORBIDDEN);
      end
      else aParams.Returns(ToText(ServiceRunningContext.Request.JWTContent.result)^, HTTP_FORBIDDEN)
    end
    else
    begin
      aParams.Returns('Invalid parameters', HTTP_NOTFOUND);
      Exit;
    end;
  except
    on e : exception do
      aParams.Returns(StringToUTF8(e.Message), HTTP_NOTFOUND);
  end;
end;

initialization
  MainServer := TMainServer.Create();

finalization
  if Assigned(MainServer) then
    FreeAndNil(MainServer);

end.
