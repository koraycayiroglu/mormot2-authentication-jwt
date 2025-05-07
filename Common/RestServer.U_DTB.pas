unit RestServer.U_DTB;

interface

uses
  mormot.core.base,
  mormot.orm.core,
  RestServer.U_Data;

type
  TFirstName = RawUTF8;
  TLastName  = RawUTF8;

  TSampleData = class(TOrm)
  private
    FFirstName: TFirstName;
    FLastName: TLastName;
  published
    property FirstName : TFirstName read FFirstName write FFirstName;
    property LastName : TLastName read FLastName write FLastName;
  end;

function DTBModel(const ARoot: RawUTF8): TOrmModel;

implementation

function DTBModel(const ARoot: RawUTF8): TOrmModel;
begin
  Result := CreateOrmModel(ARoot, [TSampleData]);
end;

end.
