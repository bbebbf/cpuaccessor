unit ProcessPriorityScope;

interface

uses Winapi.Windows;

type
  TSetProcessPriorityClassResult = record
    Successful: Boolean;
    ActuallySetToPriorityClass: DWORD;
  end;

  IProcessPriorityScope = interface
    ['{D9CBDB3B-F487-457A-A12F-3C0E32A4BEB2}']
    function SetProcessPriorityClass(const aPriorityClass: DWORD): TSetProcessPriorityClassResult;
    procedure RestorePreviousPriorityClass;
  end;

  IThreadPriorityScope = interface
    ['{59506B03-8DB9-49C5-A738-053BE28AEB50}']
    function SetThreadPriority(const aPriority: Int32): Boolean;
    procedure RestorePreviousPriority;
  end;

  TProcessThreadPriorityScope = class
  public
    class function CreateProcessPriorityScope(const aProcessHandle: THandle;
      const aRestoreOnDestroy: Boolean = True): IProcessPriorityScope;
    class function GetProcessPriority(const aProcessHandle: THandle): DWORD;
    class function CreateThreadPriority(const aThreadHandle: THandle;
      const aRestoreOnDestroy: Boolean = True): IThreadPriorityScope;
  end;

implementation

type
  TProcessPriorityScope = class(TInterfacedObject, IProcessPriorityScope)
  strict protected
    fPriorityBefore: DWORD;
    fRestoreOnDestroy: Boolean;
    fHandle: THandle;
    function SetProcessPriorityClass(const aPriorityClass: DWORD): TSetProcessPriorityClassResult;
    procedure RestorePreviousPriorityClass;
  public
    constructor Create(const aHandle: THandle; const aRestoreOnDestroy: Boolean);
    destructor Destroy; override;
  end;

  TThreadPriorityScope = class(TInterfacedObject, IThreadPriorityScope)
  strict protected
    fPriorityBefore: Int32;
    fPriorityBeforeSet: Boolean;
    fRestoreOnDestroy: Boolean;
    fHandle: THandle;
    function SetThreadPriority(const aPriority: Int32): Boolean;
    procedure RestorePreviousPriority;
  public
    constructor Create(const aHandle: THandle; const aRestoreOnDestroy: Boolean);
    destructor Destroy; override;
  end;


{ TProcessThreadPriorityScope }

class function TProcessThreadPriorityScope.CreateProcessPriorityScope(const aProcessHandle: THandle;
  const aRestoreOnDestroy: Boolean): IProcessPriorityScope;
begin
  Result := TProcessPriorityScope.Create(aProcessHandle, aRestoreOnDestroy);
end;

class function TProcessThreadPriorityScope.CreateThreadPriority(const aThreadHandle: THandle;
  const aRestoreOnDestroy: Boolean): IThreadPriorityScope;
begin
  Result := TThreadPriorityScope.Create(aThreadHandle, aRestoreOnDestroy);
end;

class function TProcessThreadPriorityScope.GetProcessPriority(const aProcessHandle: THandle): DWORD;
begin
  Result := Winapi.Windows.GetPriorityClass(aProcessHandle);
end;

{ TProcessPriorityScope }

constructor TProcessPriorityScope.Create(const aHandle: THandle; const aRestoreOnDestroy: Boolean);
begin
  inherited Create;
  fHandle := aHandle;
  fRestoreOnDestroy := aRestoreOnDestroy;
end;

destructor TProcessPriorityScope.Destroy;
begin
  if fRestoreOnDestroy then
    RestorePreviousPriorityClass;
  inherited;
end;

function TProcessPriorityScope.SetProcessPriorityClass(const aPriorityClass: DWORD): TSetProcessPriorityClassResult;
begin
  Result := default(TSetProcessPriorityClassResult);
  var lGetResult := Winapi.Windows.GetPriorityClass(fHandle);
  if lGetResult <> 0 then
  begin
    if Winapi.Windows.SetPriorityClass(fHandle, aPriorityClass) then
    begin
      Result.Successful := True;
      Result.ActuallySetToPriorityClass := Winapi.Windows.GetPriorityClass(fHandle);
      if fPriorityBefore = 0 then
        fPriorityBefore := lGetResult;
    end;
  end;
end;

procedure TProcessPriorityScope.RestorePreviousPriorityClass;
begin
  if fPriorityBefore <> 0 then
    Winapi.Windows.SetPriorityClass(fHandle, fPriorityBefore);
end;

{ TThreadPriorityScope }

constructor TThreadPriorityScope.Create(const aHandle: THandle; const aRestoreOnDestroy: Boolean);
begin
  inherited Create;
  fHandle := aHandle;
  fRestoreOnDestroy := aRestoreOnDestroy;
end;

destructor TThreadPriorityScope.Destroy;
begin
  if fRestoreOnDestroy then
    RestorePreviousPriority;
  inherited;
end;

function TThreadPriorityScope.SetThreadPriority(const aPriority: Int32): Boolean;
begin
  Result := False;
  var lGetResult := Winapi.Windows.GetThreadPriority(fHandle);
  if lGetResult <> THREAD_PRIORITY_ERROR_RETURN then
    Result := Winapi.Windows.SetThreadPriority(fHandle, aPriority);
  if (lGetResult <> THREAD_PRIORITY_ERROR_RETURN) and not fPriorityBeforeSet then
  begin
    fPriorityBefore := lGetResult;
    fPriorityBeforeSet := True;
  end;
end;

procedure TThreadPriorityScope.RestorePreviousPriority;
begin
  if fPriorityBeforeSet then
    Winapi.Windows.SetThreadPriority(fHandle, fPriorityBefore);
end;

end.
