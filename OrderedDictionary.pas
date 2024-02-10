unit OrderedDictionary;

interface

uses System.Generics.Collections, System.Generics.Defaults, Enumerations;

type
  IOrderedDictionaryComparer<T> = interface(IComparer<T>)
    function GetHashCode(const Value: T): Integer;
  end;

  TOrderedDictionaryComparer<T> = class
  public
    class function Construct(const aComparison: TComparison<T>;
      const aHasher: THasher<T>): IOrderedDictionaryComparer<T>;
  end;

  TOrderedDictionary<TKey,TValue> = class(TObjectDictionary<TKey,TValue>)
  strict private
    FComparer: IOrderedDictionaryComparer<TKey>;
    FOrderedKeyList: TList<TKey>;
    FKeyCollection: TGenericCollection<Integer, TKey>;
    FValueCollection: TGenericCollection<Integer, TValue>;
    function GetKeys: TGenericCollection<Integer, TKey>;
    function GetValues: TGenericCollection<Integer, TValue>;
    class function GetEqualityComparer(const aComparer: IOrderedDictionaryComparer<TKey>): IEqualityComparer<TKey>;
  protected
    procedure KeyNotify(const Key: TKey; Action: TCollectionNotification); override;
  public
    constructor Create(const aOwnerships: TDictionaryOwnerships;
      const AComparer: IOrderedDictionaryComparer<TKey>); overload;
    constructor Create(const aOwnerships: TDictionaryOwnerships; const ACapacity: Integer;
      const AComparer: IOrderedDictionaryComparer<TKey>); overload;
    destructor Destroy; override;
    function GetEnumerator: TGenericEnumerator<Integer, TPair<TKey, TValue>>; reintroduce;
    property Keys: TGenericCollection<Integer, TKey> read GetKeys;
    property Values: TGenericCollection<Integer, TValue> read GetValues;
  end;

  TOrderedComparer<T> = class(TInterfacedObject, IOrderedDictionaryComparer<T>)
  strict private
    fComparison: TComparison<T>;
    fHasher: THasher<T>;
    function Compare(const aLeft, aRight: T): Integer;
    function GetHashCode(const aValue: T): Integer; reintroduce;
  public
    constructor Create(const aComparison: TComparison<T>; const aHasher: THasher<T>);
  end;

implementation

uses System.Hash;

{ TOrderedDictionary<TKey, TValue> }

constructor TOrderedDictionary<TKey, TValue>.Create(const aOwnerships: TDictionaryOwnerships;
  const ACapacity: Integer; const AComparer: IOrderedDictionaryComparer<TKey>);
begin
  Create(aOwnerships, ACapacity, GetEqualityComparer(AComparer));
  FComparer := AComparer;
end;

constructor TOrderedDictionary<TKey, TValue>.Create(const aOwnerships: TDictionaryOwnerships;
  const AComparer: IOrderedDictionaryComparer<TKey>);
begin
  Create(aOwnerships, GetEqualityComparer(AComparer));
  FComparer := AComparer;
end;

class function TOrderedDictionary<TKey, TValue>.GetEqualityComparer(
  const aComparer: IOrderedDictionaryComparer<TKey>): IEqualityComparer<TKey>;
begin
  if not Assigned(aComparer) then
    Exit(nil);

  Result := TEqualityComparer<TKey>.Construct(
    function(const Left, Right: TKey): Boolean
    begin
      Result := aComparer.Compare(Left, Right) = 0;
    end,
    function(const Value: TKey): Integer
    begin
      Result := aComparer.GetHashCode(Value);
    end
  );
end;

destructor TOrderedDictionary<TKey, TValue>.Destroy;
begin
  FKeyCollection.Free;
  FValueCollection.Free;
  FOrderedKeyList.Free;
  inherited;
end;

procedure TOrderedDictionary<TKey, TValue>.KeyNotify(const Key: TKey; Action: TCollectionNotification);
begin
  inherited;
  if not Assigned(FOrderedKeyList) then
    FOrderedKeyList := TList<TKey>.Create;
  if Action in [TCollectionNotification.cnAdded] then
  begin
    FOrderedKeyList.Add(Key);
    if Assigned(FComparer) then
    begin
      FOrderedKeyList.Sort(TComparer<TKey>.Construct(
        function(const Left, Right: TKey): Integer
        begin
          Result := FComparer.Compare(Left, Right);
        end
      ));
    end;
  end
  else if Action in [TCollectionNotification.cnExtracted, TCollectionNotification.cnRemoved] then
    FOrderedKeyList.Remove(Key);
end;

function TOrderedDictionary<TKey, TValue>.GetEnumerator: TGenericEnumerator<Integer, TPair<TKey, TValue>>;
begin
  Result := TGenericEnumerator<Integer, TPair<TKey, TValue>>.Create(
      function(var anIndex: Integer): Boolean
      begin
        Inc(anIndex);
        Result := anIndex < Self.Count;
      end,
      function(const anIndex: Integer): TPair<TKey, TValue>
      begin
        Result.Key := FOrderedKeyList[anIndex];
        Result.Value := Self[Result.Key];
      end,
      -1
    );
end;

function TOrderedDictionary<TKey, TValue>.GetKeys: TGenericCollection<Integer, TKey>;
begin
  FKeyCollection.Free;
  FKeyCollection := TGenericCollection<Integer, TKey>.Create(
      function(var anIndex: Integer): Boolean
      begin
        Inc(anIndex);
        Result := anIndex < Self.Count;
      end,
      function(const anIndex: Integer): TKey
      begin
        Result := FOrderedKeyList[anIndex];
      end,
      -1
    );
  Result := FKeyCollection;
end;

function TOrderedDictionary<TKey, TValue>.GetValues: TGenericCollection<Integer, TValue>;
begin
  FValueCollection.Free;
  FValueCollection := TGenericCollection<Integer, TValue>.Create(
      function(var anIndex: Integer): Boolean
      begin
        Inc(anIndex);
        Result := anIndex < Self.Count;
      end,
      function(const anIndex: Integer): TValue
      begin
        Result := Self[FOrderedKeyList[anIndex]];
      end,
      -1
    );
  Result := FValueCollection;
end;

{ TOrderedDictionaryComparer<T> }

class function TOrderedDictionaryComparer<T>.Construct(const aComparison: TComparison<T>;
  const aHasher: THasher<T>): IOrderedDictionaryComparer<T>;
begin
  Result := TOrderedComparer<T>.Create(aComparison, aHasher);
end;

{ TOrderedComparer<T> }

constructor TOrderedComparer<T>.Create(const aComparison: TComparison<T>; const aHasher: THasher<T>);
begin
  inherited Create;
  fComparison := aComparison;
  fHasher := aHasher;
end;

function TOrderedComparer<T>.Compare(const aLeft, aRight: T): Integer;
begin
  Result := fComparison(aLeft, aRight);
end;

function TOrderedComparer<T>.GetHashCode(const aValue: T): Integer;
begin
  Result := fHasher(aValue);
end;

end.
