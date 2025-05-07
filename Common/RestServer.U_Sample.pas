unit RestServer.U_Sample;

interface
uses
  mormot.core.base,
  mormot.core.os,
  mormot.core.interfaces,
  mormot.core.variants,
  mormot.core.rtti,
  mormot.core.json,
  mormot.orm.core,
  mormot.soa.core,
  mormot.soa.server,
  RestServer.I_Sample,
  RestServer.U_DTB,
  JWTServer.U_RESTServer;

type
  TSample = class(TInterfacedObject, ISample)
  private
    //FLocker: TSynLocker;
  public
    //procedure FreeInstance(); override;
    //class function NewInstance(): TObject; override;
  published
    function FullList : TServiceCustomAnswer;
  end;

implementation

{ TSample }

{procedure TSample.FreeInstance;
begin
  //FLocker.Done();
  //inherited FreeInstance();
end;}

function TSample.FullList: TServiceCustomAnswer;
var
  L : TOrmTable;
  tmp : variant;
begin
  Result.Header := JSON_CONTENT_TYPE_HEADER;
  Result.Content := '';
  Result.Status := HTTP_SUCCESS;
  //FLocker.Lock();
  {try
    Result.Header := JSON_CONTENT_TYPE_HEADER;
    L := MainServer.RestServer.Orm.ExecuteList([TSampleData],
      'SELECT * FROM SAMPLEDATA LIMIT 100');
    if Assigned(L) then begin
      tmp := _Arr([]);
      L.ToDocVariant(tmp, true);
      Result.Content := tmp;
      L.Free;
    end;
    Result.Status := HTTP_SUCCESS;
  finally
    //FLocker.UnLock();
  end;}
end;

{
class function TSample.NewInstance: TObject;
begin
  Result := inherited NewInstance();
  TSample(Result).FLocker.Init();
end;
}

end.

