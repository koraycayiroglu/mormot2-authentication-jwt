unit server;

interface

{$I mormot.defines.inc}
uses
  SysUtils,
  mormot.core.base,
  mormot.core.os,
  mormot.core.data,
  mormot.core.datetime,
  mormot.core.unicode,
  mormot.core.text,
  mormot.core.interfaces,
  mormot.core.rtti,
  mormot.core.json,
  mormot.core.buffers,
  mormot.core.variants,
  mormot.crypt.secure,
  mormot.crypt.jwt,
  mormot.crypt.core,
  mormot.db.raw.sqlite3.static,
  mormot.orm.core,
  mormot.orm.base,
  mormot.orm.rest,
  mormot.rest.core,
  mormot.rest.server,
  mormot.rest.sqlite3,
  mormot.soa.core,
  mormot.soa.server,
  mormot.net.http,
  mormot.net.server,
  RestServer.U_JWT,
  data;

type
  TExampleService = class(TInjectableObjectRest, IExample)
  private
    FSafe: IAutoLocker;
  public
    constructor Create; override;
    function Add(var ASample: TSample): Integer;
    function Find(var ASample: TSample): Integer;
  end;

  TSampleServer = class(TRestServerDB)
  public
    constructor Create(aModel: TOrmModel; const aDBFileName: TFileName); reintroduce;
  published
    function IsValidToken(aParams: TRestServerURIContext): Integer;
    function RefreshToken(aParams: TRestServerURIContext): Integer;
  end;

implementation

{
******************************* TExampleService ********************************
}

constructor TExampleService.Create;
begin
  FSafe := TAutoLocker.Create;
end;

function TExampleService.Add(var ASample: TSample): Integer;
var
  OrmSample: TOrmSample;
begin
  FSafe.Enter;
  try
    OrmSample := TOrmSample.Create;
    try
      OrmSample.Name := ASample.Name;
      OrmSample.Question := ASample.Question;
      if Self.Server.Orm.Add(OrmSample, true) > 0 then
      begin
        Writeln('Record created OK');
        Result := 0;
      end
      else
      begin
        Writeln('Error creating Record');
        Result := -1;
      end;
    finally
      OrmSample.Free;
    end;
  finally
    FSafe.Leave
  end;
end;


function TExampleService.Find(var ASample: TSample): Integer;
var
  OrmSample: TOrmSample;
begin
  FSafe.Enter;
  try
    OrmSample := TOrmSample.Create(Self.Server.Orm,'Name=?',[ASample.Name]);
    try
      if OrmSample.ID=0 then
      begin
        Writeln('Error reading Record');
        Result := -1;
      end
      else
      begin
        Writeln('Record read OK');
        ASample.Name := OrmSample.Name;
        ASample.Question := OrmSample.Question;
        Result := 0;
      end;
    finally
      OrmSample.Free;
    end;
  finally
    FSafe.Leave;
  end;
end;

{
******************************** TSampleServer *********************************
}
constructor TSampleServer.Create(aModel: TOrmModel;
  const aDBFileName: TFileName);
var
  vGuid: TGUID;
begin
  inherited Create(AModel, ADBFileName, true);

  Server.CreateMissingTables;
  Db.UseCache := true;

  AuthenticationUnregisterAll;
  AuthenticationRegister([TRestServerAuthenticationJWT, TRestServerAuthenticationSignedUri]);
  SetRoutingClass(TRestRoutingREST_JWT);
  CreateGUID(vGUID);
  JWTForUnauthenticatedRequest :=
    TJwtHS256.
      Create(SHA256(GUIDToRawUTF8(vGUID)), 0, [jrcIssuer, jrcSubject], [],
        JWTDefaultTimeout);

  //AcquireExecutionMode[execOrmGet] := amMainThread;
  //AcquireExecutionMode[execOrmWrite] := amLocked;
  //AcquireExecutionMode[execSoaByInterface] := amBackgroundThread;
  //AcquireWriteTimeOut := 500;

  ServiceMethodByPassAuthentication('IsValidToken');
  ServiceMethodByPassAuthentication('RefreshToken');

  ServiceDefine(TExampleService, [IExample], sicPerThread){.
    SetOptions([], [optIgnoreException]);} // thread-safe fConnected[];
end;



function TSampleServer.IsValidToken(aParams: TRestServerURIContext): Integer;
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
    if not Assigned(JWTForUnauthenticatedRequest) then
    begin
      aParams.Returns('TRestServerAuthenticationJWT not initialized', HTTP_NOTFOUND);
      Exit;
    end;

    jwtClass := JWT_CLASS[getAlgo(JWTForUnauthenticatedRequest.Algorithm)];
    _Result := ServiceRunningContext.Request.AuthenticationCheck(
      (JWTForUnauthenticatedRequest as jwtClass));
    if not _result then
      aParams.Returns(ToText(ServiceRunningContext.Request.JWTContent.Result)^, HTTP_FORBIDDEN)
    else
    begin
      SessionExist := False;
      if Sessions <> nil then
      begin
        TokenSesID := GetCardinal(
          Pointer(ServiceRunningContext.Request.JWTContent.data.U['sessionkey']));
        if TokenSesID > 0 then
          for i := 0 to pred(Sessions.Count) do
          begin
            if (TAuthSession(Sessions[i]).ID = TokenSesID) then
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

function TSampleServer.RefreshToken(aParams: TRestServerURIContext): Integer;
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
    if not Assigned(JWTForUnauthenticatedRequest) then begin
      aParams.Returns('TRestServerAuthenticationJWT not initialized', HTTP_NOTFOUND);
      Exit;
    end;
    if UrlDecodeNeedParameters(aParams.Parameters, 'USERNAME,PASSWORD') then
    begin
      while aParams.Parameters<>nil do
      begin
        UrlDecodeValue(aParams.Parameters,'USERNAME=', vUserName, @aParams.Parameters);
        UrlDecodeValue(aParams.Parameters,'PASSWORD=', vPassword, @aParams.Parameters);
      end;

      vResult.InitFast;

      jwtClass := JWT_CLASS[getAlgo(JWTForUnauthenticatedRequest.Algorithm)];
      Token := ServiceRunningContext.Request.AuthenticationBearerToken;
      ServiceRunningContext.Request.AuthenticationCheck((JWTForUnauthenticatedRequest as jwtClass));

      if ServiceRunningContext.Request.JWTContent.result in [jwtValid, jwtExpired] then
      begin
        User := fAuthUserClass.Create(Orm,'LogonName=?',[vUserName]);
        if Assigned(User) then
        try
          if User.ID <= 0 then
            aParams.Returns('Unknown user', HTTP_FORBIDDEN)
          else
          if SameTextU(User.PasswordHashHexa, SHA256('salt' + vPassword)) or
                  SameTextU(User.PasswordHashHexa, vPassword) then
          begin
            SessionExist := False;
            if Sessions <> nil then
            begin
              TokenSesID := GetCardinal(Pointer(ServiceRunningContext.Request.JWTContent.data.U['sessionkey']));
              if TokenSesID > 0 then
                for i := 0 to pred(Sessions.Count) do
                begin
                  if (TAuthSession(Sessions[i]).UserID = User.ID) and
                     (TAuthSession(Sessions[i]).ID = TokenSesID) then
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

              jwtClass := JWT_CLASS[getAlgo(JWTForUnauthenticatedRequest.Algorithm)];
              if SessionExist then
                Token := (JWTForUnauthenticatedRequest as jwtClass)
                             .Compute(['sessionkey', Variant(ServiceRunningContext.Request.JWTContent.data.U['sessionkey'])],
                                       vUserName,
                                       'jwt.access',
                                       '',
                                       0, JWTDefaultTimeout, @Signat)
              else
              begin
                SessionCreate(User, ServiceRunningContext.Request, NewSession);
                if NewSession <> nil then
                  Token := (JWTForUnauthenticatedRequest as jwtClass)
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

end.
