unit AggregatedList;

interface

uses System.Generics.Collections, System.Generics.Defaults, OrderedDictionary;

type
  TAggregatedList<T, K> = class
  strict private
    fEntries: TOrderedDictionary<T, TList<K>>;
  public
    constructor Create(const aComparer: IOrderedDictionaryComparer<T> = nil);
    destructor Destroy; override;
    procedure Add(const aEntry: T; const aId: K);
    property Entries: TOrderedDictionary<T, TList<K>> read fEntries;
  end;

implementation

{ TAggregatedList<T, K> }

constructor TAggregatedList<T, K>.Create(const aComparer: IOrderedDictionaryComparer<T>);
begin
  inherited Create;
  fEntries := TOrderedDictionary<T, TList<K>>.Create([], aComparer);
end;

destructor TAggregatedList<T, K>.Destroy;
begin
  fEntries.Free;
  inherited;
end;

procedure TAggregatedList<T, K>.Add(const aEntry: T; const aId: K);
begin
  var lIdList: TList<K>;
  if not fEntries.TryGetValue(aEntry, lIdList) then
  begin
    lIdList:= TList<K>.Create;
    fEntries.Add(aEntry, lIdList);
  end;
  lIdList.Add(aId);
end;

end.
