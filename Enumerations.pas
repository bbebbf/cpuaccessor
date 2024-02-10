unit Enumerations;

interface

uses System.Generics.Collections;

type
  TMoveNextFunc<I> = reference to function(var anIndex: I): Boolean;
  TGetCurrentFunc<I,T> = reference to function(const anIndex: I): T;

  TGenericEnumerator<I,T> = class(TEnumerator<T>)
  strict private
    FMoveNextFunc: TMoveNextFunc<I>;
    FGetCurrentFunc: TGetCurrentFunc<I,T>;
    FIndexData: I;
    function GetCurrent: T;
  protected
    function DoGetCurrent: T; override;
    function DoMoveNext: Boolean; override;
  public
    constructor Create(const aMoveNextFunc: TMoveNextFunc<I>;
      const aGetCurrentFunc: TGetCurrentFunc<I,T>;
      const anIndexStartData: I);
    property Current: T read GetCurrent;
    function MoveNext: Boolean;
  end;

  TGenericCollection<I,T> = class(TEnumerable<T>)
  strict private
    FMoveNextFunc: TMoveNextFunc<I>;
    FGetCurrentFunc: TGetCurrentFunc<I,T>;
    FIndexData: I;
  protected
    function DoGetEnumerator: TEnumerator<T>; override;
  public
    constructor Create(const aMoveNextFunc: TMoveNextFunc<I>;
      const aGetCurrentFunc: TGetCurrentFunc<I,T>;
      const anIndexStartData: I);
    function GetEnumerator: TGenericEnumerator<I,T>; reintroduce;
    function ToArray: TArray<T>; override; final;
  end;

implementation

{ TGenericEnumerator<I, T> }

constructor TGenericEnumerator<I, T>.Create(const aMoveNextFunc: TMoveNextFunc<I>;
  const aGetCurrentFunc: TGetCurrentFunc<I, T>; const anIndexStartData: I);
begin
  inherited Create;
  FMoveNextFunc := aMoveNextFunc;
  FGetCurrentFunc := aGetCurrentFunc;
  FIndexData := anIndexStartData;
end;

function TGenericEnumerator<I, T>.DoGetCurrent: T;
begin
  Result := FGetCurrentFunc(FIndexData);
end;

function TGenericEnumerator<I, T>.DoMoveNext: Boolean;
begin
  Result := FMoveNextFunc(FIndexData);
end;

function TGenericEnumerator<I, T>.GetCurrent: T;
begin
  Result := DoGetCurrent;
end;

function TGenericEnumerator<I, T>.MoveNext: Boolean;
begin
  Result := DoMoveNext;
end;

{ TGenericCollection<I, T> }

constructor TGenericCollection<I, T>.Create(const aMoveNextFunc: TMoveNextFunc<I>;
  const aGetCurrentFunc: TGetCurrentFunc<I, T>; const anIndexStartData: I);
begin
  inherited Create;
  FMoveNextFunc := aMoveNextFunc;
  FGetCurrentFunc := aGetCurrentFunc;
  FIndexData := anIndexStartData;
end;

function TGenericCollection<I, T>.DoGetEnumerator: TEnumerator<T>;
begin
  Result := GetEnumerator;
end;

function TGenericCollection<I, T>.GetEnumerator: TGenericEnumerator<I, T>;
begin
  Result := TGenericEnumerator<I, T>.Create(FMoveNextFunc, FGetCurrentFunc, FIndexData);
end;

function TGenericCollection<I, T>.ToArray: TArray<T>;
var lCount: Integer;
  lValue: T;
begin
  lCount := -1;
  SetLength(Result, lCount);
  while FMoveNextFunc(FIndexData) do
  begin
    Inc(lCount);
    SetLength(Result, lCount);
    Result[lCount - 1] := lValue;
  end;
end;

end.
