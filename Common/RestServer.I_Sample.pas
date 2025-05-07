unit RestServer.I_Sample;

interface

uses
  mormot.core.base,
  mormot.core.interfaces;

type
  ISample = interface(IInvokable)
  ['{7CB8BE69-5D57-4D72-AE8E-EB69F7674CC6}']
    function FullList : TServiceCustomAnswer;
  end;

implementation

initialization
  TInterfaceFactory.RegisterInterfaces([
    TypeInfo(ISample)]);

end.
