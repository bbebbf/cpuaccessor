unit ProcessorAffinityMaskScope;

interface

uses Winapi.Windows;


type
  IProcessorAffinityMaskScope = interface
    ['{55C23E04-6773-43D2-8E7B-892311FBA924}']
    function SetProcessorAffinityMask(const aMask: NativeUInt): Boolean;
    function SetProcessorAffinityMaskToSystemMask(): Boolean;
    procedure RestorePreviousMask;
  end;

  TProcessorAffinityMaskScope = class
  public
    class function CreateProcessAffinityMaskScope(const aProcessHandle: THandle;
      const aRestoreOnDestroy: Boolean = True): IProcessorAffinityMaskScope;
    class function CreateThreadAffinityMaskScope(const aThreadHandle: THandle;
      const aRestoreOnDestroy: Boolean = True): IProcessorAffinityMaskScope;
  end;

implementation

uses System.SysUtils;

type
  TAffinityMaskScopeInternalAction = reference to function(const aHandle: THandle; const aMask: NativeUInt): NativeUInt;

  TAffinityMaskScopeInternal = class(TInterfacedObject, IProcessorAffinityMaskScope)
  strict protected
    fMaskBefore: NativeUInt;
    fRestoreOnDestroy: Boolean;
    fHandle: THandle;
    fAction: TAffinityMaskScopeInternalAction;
    function SetProcessorAffinityMask(const aMask: NativeUInt): Boolean;
    function SetProcessorAffinityMaskToSystemMask(): Boolean;
    function SetProcessorAffinityMaskIntenal(const aMask: NativeUInt): NativeUInt; virtual;
    procedure RestorePreviousMask;
  public
    constructor Create(const aHandle: THandle; const aRestoreOnDestroy: Boolean;
      const aAction: TAffinityMaskScopeInternalAction);
    destructor Destroy; override;
  end;

{ TProcessorAffinityMaskScope }

class function TProcessorAffinityMaskScope.CreateProcessAffinityMaskScope(const aProcessHandle: THandle;
  const aRestoreOnDestroy: Boolean): IProcessorAffinityMaskScope;
begin
  Result := TAffinityMaskScopeInternal.Create(aProcessHandle, aRestoreOnDestroy,
    function(const aHandle: THandle; const aMask: NativeUInt): NativeUInt
    begin
      var lProcessMask: NativeUInt;
      var lSystemMask: NativeUInt;
      Result := 0;
      if not Winapi.Windows.GetProcessAffinityMask(aHandle, lProcessMask, lSystemMask) then
        Exit;

      if Winapi.Windows.SetProcessAffinityMask(aHandle, aMask) then
        Result := lProcessMask;
    end
  );
end;

class function TProcessorAffinityMaskScope.CreateThreadAffinityMaskScope(const aThreadHandle: THandle;
  const aRestoreOnDestroy: Boolean): IProcessorAffinityMaskScope;
begin
  Result := TAffinityMaskScopeInternal.Create(aThreadHandle, aRestoreOnDestroy,
    function(const aHandle: THandle; const aMask: NativeUInt): NativeUInt
    begin
      Result := Winapi.Windows.SetThreadAffinityMask(aHandle, aMask);
    end
  );
end;

{ TAffinityMaskScopeInternal }

constructor TAffinityMaskScopeInternal.Create(const aHandle: THandle; const aRestoreOnDestroy: Boolean;
  const aAction: TAffinityMaskScopeInternalAction);
begin
  inherited Create;
  fHandle := aHandle;
  fRestoreOnDestroy := aRestoreOnDestroy;
  fAction := aAction;
end;

destructor TAffinityMaskScopeInternal.Destroy;
begin
  if fRestoreOnDestroy then
    RestorePreviousMask;
  inherited;
end;

procedure TAffinityMaskScopeInternal.RestorePreviousMask;
begin
  if fMaskBefore > 0 then
    SetProcessorAffinityMaskIntenal(fMaskBefore);
end;

function TAffinityMaskScopeInternal.SetProcessorAffinityMask(const aMask: NativeUInt): Boolean;
begin
  Result := True;
  if aMask = 0 then
    Exit(False);

  var lReturnedAffinityMask := SetProcessorAffinityMaskIntenal(aMask);
  if lReturnedAffinityMask = 0 then
    Exit(False);

  if fMaskBefore = 0 then
    fMaskBefore := lReturnedAffinityMask;
end;

function TAffinityMaskScopeInternal.SetProcessorAffinityMaskIntenal(const aMask: NativeUInt): NativeUInt;
begin
  Result := fAction(fHandle, aMask);
end;

function TAffinityMaskScopeInternal.SetProcessorAffinityMaskToSystemMask: Boolean;
begin
  Result := False;
  var lProcessMask: NativeUInt;
  var lSystemMask: NativeUInt;
  if not Winapi.Windows.GetProcessAffinityMask(fHandle, lProcessMask, lSystemMask) then
    Exit;

  Result := SetProcessorAffinityMask(lSystemMask);
end;

end.
