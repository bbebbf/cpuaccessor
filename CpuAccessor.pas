unit CpuAccessor;

interface

uses system.Generics.Collections, ProcessorAffinityMaskScope, Cpu.Types;

type
  TCpuCore = class;

  TCpuLogicalProcessor = class
  strict private
    fProcessorId: Byte;
    fCore: TCpuCore;
  private
    fMaxMhz: Cardinal;
    fCurrentMhz: Cardinal;
    fMhzLimit: Cardinal;
  public
    constructor Create(const aCore: TCpuCore; const aProcessorId: Byte);
    property ProcessorId: Byte read fProcessorId;
    property Core: TCpuCore read fCore;
    property MaxMhz: Cardinal read fMaxMhz;
    property CurrentMhz: Cardinal read fCurrentMhz;
    property MhzLimit: Cardinal read fMhzLimit;
  end;

  TCpuCore = class
  strict private
    fCoreId: Byte;
    fLogicalProcessors: TList<TCpuLogicalProcessor>;
  private
    fEfficiencyClass: Byte;
  public
    constructor Create(const aCoreId: Byte);
    destructor Destroy; override;
    property CoreId: Byte read fCoreId;
    property EfficiencyClass: Byte read fEfficiencyClass;
    property LogicalProcessors: TList<TCpuLogicalProcessor> read fLogicalProcessors;
  end;

  TCpuCache = class
  strict private
    fCacheId: Word;
  private
    fLevel: Byte;
    fType: Byte;
    fSize: Cardinal;
    fLineCount: Cardinal;
    fLogicalProcessors: TList<TCpuLogicalProcessor>;
  public
    constructor Create(const aCacheId: Word);
    destructor Destroy; override;
    property CacheId: Word read fCacheId;
    property Level: Byte read fLevel;
    property Type_: Byte read fType;
    property Size: Cardinal read fSize;
    property LineCount: Cardinal read fLineCount;
    property LogicalProcessors: TList<TCpuLogicalProcessor> read fLogicalProcessors;
  end;

  TCpuSpecification = class
  strict private
    const
      LeafCpuBasicFirst = 0;
      LeafHybridInfo = $1a;
      LeafHipervisorFirst = $40000000;
      LeafExtInfoFirst = $80000000;
    var
      fCpuSetInfoSource: TCpuSetInfoSource;
      fCores: TList<TCpuCore>;
      fLogicalProcessors: TList<TCpuLogicalProcessor>;
      fCaches: TList<TCpuCache>;
      fCpuIdRead: Boolean;
      fVendor: TCpuVendor;
      fVendorString: string;
      fBrandString: string;
      fIsHybrid: Boolean;
      fIsHypervisorPresent: Boolean;
      fHypervisorString: string;
      fHypervisorVersion: string;
    procedure ReadCpu;
    procedure ReadCaches;
    procedure ReadClockSpeeds;
    procedure PopulateCpuSets(const aCpuSetInfoRec: CPUACCESSOR_SYSTEM_CPU_SET_INFORMATION);
    function GetCores: TList<TCpuCore>;
    function GetLogicalProcessors: TList<TCpuLogicalProcessor>;
    function GetVendor: TCpuVendor;
    function GetVendorString: string;
    function GetBrandString: string;
    function GetIsHybrid: Boolean;
    function GetCpuSetInfoSource: TCpuSetInfoSource;
    function GetMaxEfficiencyClass: Byte;
    function GetMinEfficiencyClass: Byte;
    function GetIsHypervisorPresent: Boolean;
    function GetHypervisorString: string;
    function GetPhysicalCore(const aCoreId: Byte): TCpuCore;
    function GetCacheEntry(const aCacheId: Byte): TCpuCache;
  private
    function GetHypervisorVersion: string;
    function GetCaches: TList<TCpuCache>;
  public
    destructor Destroy; override;
    function FindLogicalProcessor(const aProcessorId: Byte): TCpuLogicalProcessor;
    function IsAMD: Boolean;
    function IsIntel: Boolean;
    property CpuSetInfoSource: TCpuSetInfoSource read GetCpuSetInfoSource;
    property Vendor: TCpuVendor read GetVendor;
    property VendorString: string read GetVendorString;
    property BrandString: string read GetBrandString;
    property IsHypervisorPresent: Boolean read GetIsHypervisorPresent;
    property HypervisorString: string read GetHypervisorString;
    property HypervisorVersion: string read GetHypervisorVersion;
    property IsHybrid: Boolean read GetIsHybrid;
    property MaxEfficiencyClass: Byte read GetMaxEfficiencyClass;
    property MinEfficiencyClass: Byte read GetMinEfficiencyClass;
    property Cores: TList<TCpuCore> read GetCores;
    property LogicalProcessors: TList<TCpuLogicalProcessor> read GetLogicalProcessors;
    property Caches: TList<TCpuCache> read GetCaches;
  end;

  TCpuAccessor = class
  strict private
    class var fCpuSpecification: TCpuSpecification;
    class function GetECoresAffinityMask: NativeUInt;
    class function GetPCoresAffinityMask: NativeUInt;
  public
    class constructor ClassCreate;
    class destructor ClassDestroy;
    /// <summary>
    ///   Gets basic features from the CPU such as vendor, brand and cpu topology.
    /// </summary>
    /// <param name="aRefreshData">
    ///   If TRUE cached data will be discarded and newly read data will be returned
    ///   for example to get the current clock speeds.
    /// </param>
    /// <returns>
    ///   A data structure which includes the read data.
    ///   This data structure is owned by the class TCpuAccessor and must not be destroyed.
    /// </returns>
    class function GetCpuSpecification(const aRefreshData: Boolean = False): TCpuSpecification;
    class function CpuSetInfoSourceToStr(const aCpuSetInfoSource: TCpuSetInfoSource): string;
    class function CacheTypeToStr(const aCacheType: Byte): string;
    /// <summary>
    ///   Tries to set the affinity mask of the E-core processors to a given process.
    /// </summary>
    /// <param name="aProcessHandle">
    ///   The handle to that process.
    /// </param>
    /// <returns>
    ///   If sucessful a IProcessorAffinityMaskScope instance will be returned.
    ///   If an error occurred NIL will be returned.
    ///   When the IProcessorAffinityMaskScope instance becomes NIL again
    ///   the process will return to its previous affinity mask.
    /// </returns>
    class function TryCastProcessToECores(const aProcessHandle: THandle): IProcessorAffinityMaskScope;
    /// <summary>
    ///   Tries to set the affinity mask of the P-core processors to a given process.
    /// </summary>
    /// <param name="aProcessHandle">
    ///   The handle to that process.
    /// </param>
    /// <returns>
    ///   If sucessful a IProcessorAffinityMaskScope instance will be returned.
    ///   If an error occurred NIL will be returned.
    ///   When the IProcessorAffinityMaskScope instance becomes NIL again
    ///   the process will return to its previous affinity mask.
    /// </returns>
    class function TryCastProcessToPCores(const aProcessHandle: THandle): IProcessorAffinityMaskScope;
    /// <summary>
    ///   Tries to set the affinity mask of the E-core processors to a given thread.
    /// </summary>
    /// <param name="aThreadHandle">
    ///   The handle to that thread.
    /// </param>
    /// <returns>
    ///   If sucessful a IProcessorAffinityMaskScope instance will be returned.
    ///   If an error occurred NIL will be returned.
    ///   When the IProcessorAffinityMaskScope instance becomes NIL again
    ///   the thread will return to its previous affinity mask.
    /// </returns>
    class function TryCastThreadToECores(const aThreadHandle: THandle): IProcessorAffinityMaskScope;
    /// <summary>
    ///   Tries to set the affinity mask of the P-core processors to a given thread.
    /// </summary>
    /// <param name="aThreadHandle">
    ///   The handle to that thread.
    /// </param>
    /// <returns>
    ///   If sucessful a IProcessorAffinityMaskScope instance will be returned.
    ///   If an error occurred NIL will be returned.
    ///   When the IProcessorAffinityMaskScope instance becomes NIL again
    ///   the thread will return to its previous affinity mask.
    /// </returns>
    class function TryCastThreadToPCores(const aThreadHandle: THandle): IProcessorAffinityMaskScope;
    /// <summary>
    ///   Tries to set the affinity mask a given processor to a given process.
    /// </summary>
    /// <param name="aProcessHandle">
    ///   The handle to that process.
    /// </param>
    /// <param name="aProcessorId">
    ///   The processor id.
    /// </param>
    /// <returns>
    ///   If sucessful a IProcessorAffinityMaskScope instance will be returned.
    ///   If an error occurred NIL will be returned.
    ///   When the IProcessorAffinityMaskScope instance becomes NIL again
    ///   the process will return to its previous affinity mask.
    /// </returns>
    class function TryCastProcessToProcessor(const aProcessHandle: THandle; const aProcessorId: Byte): IProcessorAffinityMaskScope;
    /// <summary>
    ///   Tries to set the affinity mask a given processor to a given thread.
    /// </summary>
    /// <param name="aThreadHandle">
    ///   The handle to that thread.
    /// </param>
    /// <param name="aProcessorId">
    ///   The processor id.
    /// </param>
    /// <returns>
    ///   If sucessful a IProcessorAffinityMaskScope instance will be returned.
    ///   If an error occurred NIL will be returned.
    ///   When the IProcessorAffinityMaskScope instance becomes NIL again
    ///   the thread will return to its previous affinity mask.
    /// </returns>
    class function TryCastThreadToProcessor(const aThreadHandle: THandle; const aProcessorId: Byte): IProcessorAffinityMaskScope;
  end;


implementation

uses System.SysUtils, System.Classes, Winapi.Windows, Cpu.Tools;

{ TCpuCore }

constructor TCpuCore.Create(const aCoreId: Byte);
begin
  inherited Create;
  fCoreId := aCoreId;
  fLogicalProcessors := TList<TCpuLogicalProcessor>.Create;
end;

destructor TCpuCore.Destroy;
begin
  fLogicalProcessors.Free;
  inherited;
end;

{ TCpuLogicalProcessor }

constructor TCpuLogicalProcessor.Create(const aCore: TCpuCore; const aProcessorId: Byte);
begin
  inherited Create;
  fCore := aCore;
  fProcessorId := aProcessorId;
end;

{ TCpuCache }

constructor TCpuCache.Create(const aCacheId: Word);
begin
  inherited Create;
  fLogicalProcessors := TList<TCpuLogicalProcessor>.Create;
  fCacheId := aCacheId;
end;

destructor TCpuCache.Destroy;
begin
  fLogicalProcessors.Free;
  inherited;
end;

{ TCpuSpecification }

destructor TCpuSpecification.Destroy;
begin
  fCores.Free;
  fCaches.Free;
  fLogicalProcessors.Free;
  inherited;
end;

function TCpuSpecification.GetPhysicalCore(const aCoreId: Byte): TCpuCore;
begin
  for var entry in fCores do
    if entry.CoreId = aCoreId then
      Exit(entry);

  Result := TCpuCore.Create(aCoreId);
  fCores.Add(Result);
end;

function TCpuSpecification.GetCacheEntry(const aCacheId: Byte): TCpuCache;
begin
  for var entry in fCaches do
    if entry.CacheId = aCacheId then
      Exit(entry);

  Result := TCpuCache.Create(aCacheId);
  fCaches.Add(Result);
end;

function TCpuSpecification.GetCaches: TList<TCpuCache>;
begin
  ReadCpu;
  Result := fCaches;
end;

function TCpuSpecification.GetCores: TList<TCpuCore>;
begin
  ReadCpu;
  Result := fCores;
end;

function TCpuSpecification.GetVendor: TCpuVendor;
begin
  ReadCpu;
  Result := fVendor;
end;

function TCpuSpecification.GetVendorString: string;
begin
  ReadCpu;
  Result := fVendorString;
end;

function TCpuSpecification.IsAMD: Boolean;
begin
  ReadCpu;
  Result := fVendor = TCpuVendor.AMD;
end;

function TCpuSpecification.IsIntel: Boolean;
begin
  ReadCpu;
  Result := fVendor = TCpuVendor.Intel;
end;

function TCpuSpecification.FindLogicalProcessor(const aProcessorId: Byte): TCpuLogicalProcessor;
begin
  Result := nil;
  ReadCpu;
  for var lLogicalProcessor in fLogicalProcessors do
    if lLogicalProcessor.ProcessorId = aProcessorId then
      Exit(lLogicalProcessor);
end;

function TCpuSpecification.GetBrandString: string;
begin
  ReadCpu;
  Result := fBrandString;
end;

function TCpuSpecification.GetCpuSetInfoSource: TCpuSetInfoSource;
begin
  ReadCpu;
  Result := fCpuSetInfoSource;
end;

function TCpuSpecification.GetHypervisorString: string;
begin
  ReadCpu;
  Result := fHypervisorString;
end;

function TCpuSpecification.GetHypervisorVersion: string;
begin
  ReadCpu;
  Result := fHypervisorVersion;
end;

function TCpuSpecification.GetIsHybrid: Boolean;
begin
  ReadCpu;
  Result := fIsHybrid;
end;

function TCpuSpecification.GetIsHypervisorPresent: Boolean;
begin
  ReadCpu;
  Result := fIsHypervisorPresent;
end;

function TCpuSpecification.GetLogicalProcessors: TList<TCpuLogicalProcessor>;
begin
  ReadCpu;
  Result := fLogicalProcessors;
end;

function TCpuSpecification.GetMaxEfficiencyClass: Byte;
begin
  ReadCpu;
  Result := 0;
  for var i := 0 to fCores.Count - 1 do
    if (i = 0) or (fCores[i].EfficiencyClass > Result) then
      Result := fCores[i].EfficiencyClass;
end;

function TCpuSpecification.GetMinEfficiencyClass: Byte;
begin
  ReadCpu;
  Result := 0;
  for var i := 0 to fCores.Count - 1 do
    if (i = 0) or (fCores[i].EfficiencyClass < Result) then
      Result := fCores[i].EfficiencyClass;
end;

procedure TCpuSpecification.ReadCpu;
begin
  if fCpuIdRead then
    Exit;

  {$WARN SYMBOL_PLATFORM OFF}
  fCpuIdRead := True;
  fLogicalProcessors.Free;
  fCores.Free;
  fCaches.Free;
  fLogicalProcessors := TObjectList<TCpuLogicalProcessor>.Create;
  fCores := TObjectList<TCpuCore>.Create;
  fCaches := TObjectList<TCpuCache>.Create;
  if TCpuTools.EnumGetSystemCpuSetInformation(PopulateCpuSets) then
    fCpuSetInfoSource := TCpuSetInfoSource.SourceGetSystemCpuSetInformation
  else if TCpuTools.EnumGetLogicalProcessorInformationExCores(PopulateCpuSets) then
    fCpuSetInfoSource := TCpuSetInfoSource.SourceGetLogicalProcessorInformationEx
  else
    fCpuSetInfoSource := TCpuSetInfoSource.SourceUnknown;

  ReadCaches;

  var lCpuIdRec: TCPUIDRec;
  var lCpuIdRecs: TDictionary<UInt32, TCPUIDRec> := nil;
  try
    lCpuIdRecs := TDictionary<UInt32, TCPUIDRec>.Create;
    var lLeafCpuBasicLast := GetCPUID(LeafCpuBasicFirst).EAX;
    for var i := LeafCpuBasicFirst to lLeafCpuBasicLast do
      lCpuIdRecs.Add(i, GetCPUID(i));

    if lCpuIdRecs.Count = 0 then
      Exit;

    // Read vendor id string
    var lVendorBytes: TBytes;
    SetLength(lVendorBytes, 12);
    PUInt32(@lVendorBytes[0])^ := lCpuIdRecs[LeafCpuBasicFirst].EBX;
    PUInt32(@lVendorBytes[4])^ := lCpuIdRecs[LeafCpuBasicFirst].EDX;
    PUInt32(@lVendorBytes[8])^ := lCpuIdRecs[LeafCpuBasicFirst].ECX;
    fVendorString := TEncoding.ASCII.GetString(lVendorBytes);

    // Find vendor
    fVendor := TCpuVendor.VendorUnknown;
    for var i := Low(TCpuVendor) to High(TCpuVendor) do
    begin
      if SameStr(fVendorString, CpuVendorStrings[i]) then
      begin
        fVendor := i;
        Break;
      end;
    end;

    var lLeafHipervisorLast: Cardinal;
    var lF1_ECX: TBitset32 := [];
    if lCpuIdRecs.TryGetValue(LeafCpuBasicFirst + 1, lCpuIdRec) then
      lF1_ECX := UInt32ToBitset32(lCpuIdRec.ECX);
    fIsHypervisorPresent := 31 in lF1_ECX;
    fHypervisorString := '';

    if fIsHypervisorPresent then
    begin
      lCpuIdRec := GetCPUID(LeafHipervisorFirst);
      lLeafHipervisorLast := lCpuIdRec.EAX;
      var lHvBytes: TBytes;
      SetLength(lHvBytes, 12);
      PUInt32(@lHvBytes[0])^ := lCpuIdRec.EBX;
      PUInt32(@lHvBytes[4])^ := lCpuIdRec.ECX;
      PUInt32(@lHvBytes[8])^ := lCpuIdRec.EDX;
      fHypervisorString := TEncoding.ASCII.GetString(lHvBytes);
      if LeafHipervisorFirst + 1 <= lLeafHipervisorLast then
      begin
        lCpuIdRec := GetCPUID(LeafHipervisorFirst + 1);
        SetLength(lHvBytes, 4);
        PUInt32(@lHvBytes[0])^ := lCpuIdRec.EAX;
        if Length(fHypervisorString) = 0 then
          fHypervisorString := TEncoding.ASCII.GetString(lHvBytes);
      end;
      if LeafHipervisorFirst + 2 <= lLeafHipervisorLast then
      begin
        lCpuIdRec := GetCPUID(LeafHipervisorFirst + 2);
        fHypervisorVersion := UIntToStr(lCpuIdRec.EBX shr 16) + '.' +
          UIntToStr(lCpuIdRec.EBX and $ffff) + '.' +
          UIntToStr(lCpuIdRec.EAX);
      end;
    end;



    // Read Intel hybrid flag for 12th generations processors.
    // https://www.intel.com/content/www/us/en/developer/articles/guide/12th-gen-intel-core-processor-gamedev-guide.html
    var lF7_EDX: TBitset32 := [];
    if lCpuIdRecs.TryGetValue(LeafCpuBasicFirst + 7, lCpuIdRec) then
      lF7_EDX := UInt32ToBitset32(lCpuIdRec.EDX);
    fIsHybrid := 15 in lF7_EDX;

    var lLeafExtInfoLast := GetCPUID(LeafExtInfoFirst).EAX;
    for var i := LeafExtInfoFirst to lLeafExtInfoLast do
      lCpuIdRecs.Add(i, GetCPUID(i));

    // Read brand string
    var lCpuIdExRec2: TCPUIDRec;
    var lCpuIdExRec3: TCPUIDRec;
    var lCpuIdExRec4: TCPUIDRec;
    if lCpuIdRecs.TryGetValue(LeafExtInfoFirst + 2, lCpuIdExRec2) and
       lCpuIdRecs.TryGetValue(LeafExtInfoFirst + 3, lCpuIdExRec3) and
       lCpuIdRecs.TryGetValue(LeafExtInfoFirst + 4, lCpuIdExRec4) then
    begin
      // Read brand id string
      var lBrandBytes: TBytes;
      SetLength(lBrandBytes, 48);

      PUInt32(@lBrandBytes[00])^ := lCpuIdExRec2.EAX;
      PUInt32(@lBrandBytes[04])^ := lCpuIdExRec2.EBX;
      PUInt32(@lBrandBytes[08])^ := lCpuIdExRec2.ECX;
      PUInt32(@lBrandBytes[12])^ := lCpuIdExRec2.EDX;

      PUInt32(@lBrandBytes[16])^ := lCpuIdExRec3.EAX;
      PUInt32(@lBrandBytes[20])^ := lCpuIdExRec3.EBX;
      PUInt32(@lBrandBytes[24])^ := lCpuIdExRec3.ECX;
      PUInt32(@lBrandBytes[28])^ := lCpuIdExRec3.EDX;

      PUInt32(@lBrandBytes[32])^ := lCpuIdExRec4.EAX;
      PUInt32(@lBrandBytes[36])^ := lCpuIdExRec4.EBX;
      PUInt32(@lBrandBytes[40])^ := lCpuIdExRec4.ECX;
      PUInt32(@lBrandBytes[44])^ := lCpuIdExRec4.EDX;

      fBrandString := Trim(TEncoding.ASCII.GetString(lBrandBytes));
    end;
    ReadClockSpeeds;
  finally
    lCpuIdRecs.Free;
  end;
  {$WARN SYMBOL_PLATFORM ON}
end;

procedure TCpuSpecification.ReadCaches;
begin
  TCpuTools.EnumGetLogicalProcessorInformationExCaches(
    procedure(const aCacheRec: CPUACCESSOR_CACHE_INFORMATION)
    begin
      var lCache := GetCacheEntry(aCacheRec.CacheIndex);
      lCache.fLevel := aCacheRec.CacheLevel;
      lCache.fType := Ord(aCacheRec.Type_);
      lCache.fSize := aCacheRec.CacheSize;
      lCache.fLineCount := aCacheRec.CacheSize div aCacheRec.LineSize;
      for var lLogicalProcessor in fLogicalProcessors do
      begin
        if lLogicalProcessor.ProcessorId = aCacheRec.LogicalProcessorIndex then
        begin
          lCache.LogicalProcessors.Add(lLogicalProcessor);
          Break;
        end;
      end;
    end)
end;

procedure TCpuSpecification.ReadClockSpeeds;
begin
  TCpuTools.ReadClockSpeedsFromCallNtPowerInformation(fLogicalProcessors.Count,
    procedure(const aProcessorPowerRec: CPUACCESSOR_PROCESSOR_POWER_INFORMATION)
    begin
      var lLogikalProcessor := FindLogicalProcessor(aProcessorPowerRec.Number);
      if Assigned(lLogikalProcessor) then
      begin
        lLogikalProcessor.fMaxMhz := aProcessorPowerRec.MaxMhz;
        lLogikalProcessor.fCurrentMhz := aProcessorPowerRec.CurrentMhz;
        lLogikalProcessor.fMhzLimit := aProcessorPowerRec.MhzLimit;
      end;
    end)
end;

procedure TCpuSpecification.PopulateCpuSets(const aCpuSetInfoRec: CPUACCESSOR_SYSTEM_CPU_SET_INFORMATION);
begin
  if aCpuSetInfoRec.Type_ <> 0 then
    Exit;

  var lCore := GetPhysicalCore(aCpuSetInfoRec.CoreIndex);
  lCore.fEfficiencyClass := aCpuSetInfoRec.EfficiencyClass;
  var lLogicalProcessor := TCpuLogicalProcessor.Create(lCore, aCpuSetInfoRec.LogicalProcessorIndex);
  LogicalProcessors.Add(lLogicalProcessor);
  lCore.LogicalProcessors.Add(lLogicalProcessor);
end;

{ TCpuAccessor }

class constructor TCpuAccessor.ClassCreate;
begin
  fCpuSpecification := nil;
end;

class destructor TCpuAccessor.ClassDestroy;
begin
  fCpuSpecification.Free;
end;

class function TCpuAccessor.GetCpuSpecification(const aRefreshData: Boolean): TCpuSpecification;
begin
  if Assigned(fCpuSpecification) and not aRefreshData then
    Exit(fCpuSpecification);

  fCpuSpecification.Free;
  fCpuSpecification := TCpuSpecification.Create;
  Result := fCpuSpecification;
end;

class function TCpuAccessor.GetECoresAffinityMask: NativeUInt;
begin
  Result := 0;
  var lCpuSpecs := GetCpuSpecification;
  var lMinEfficiencyClass := lCpuSpecs.MinEfficiencyClass;
  for var lLogicalProcessor in lCpuSpecs.LogicalProcessors do
    if lLogicalProcessor.Core.EfficiencyClass = lMinEfficiencyClass then
      Result := Result or (NativeUInt(1) shl lLogicalProcessor.ProcessorId);
end;

class function TCpuAccessor.GetPCoresAffinityMask: NativeUInt;
begin
  Result := 0;
  var lCpuSpecs := GetCpuSpecification;
  var lMinEfficiencyClass := lCpuSpecs.MinEfficiencyClass;
  for var lLogicalProcessor in lCpuSpecs.LogicalProcessors do
    if lLogicalProcessor.Core.EfficiencyClass > lMinEfficiencyClass then
      Result := Result or (NativeUInt(1) shl lLogicalProcessor.ProcessorId);
end;

class function TCpuAccessor.TryCastProcessToECores(const aProcessHandle: THandle): IProcessorAffinityMaskScope;
begin
  Result := nil;
  var lAffinityMask := GetECoresAffinityMask;
  if lAffinityMask = 0 then
    Exit;

  Result := TProcessorAffinityMaskScope.CreateProcessAffinityMaskScope(aProcessHandle);
  if not Result.SetProcessorAffinityMask(lAffinityMask) then
    Result := nil;
end;

class function TCpuAccessor.TryCastProcessToPCores(const aProcessHandle: THandle): IProcessorAffinityMaskScope;
begin
  Result := nil;
  var lAffinityMask := GetPCoresAffinityMask;
  if lAffinityMask = 0 then
    Exit;

  Result := TProcessorAffinityMaskScope.CreateProcessAffinityMaskScope(aProcessHandle);
  if not Result.SetProcessorAffinityMask(lAffinityMask) then
    Result := nil;
end;

class function TCpuAccessor.TryCastProcessToProcessor(const aProcessHandle: THandle; const aProcessorId: Byte): IProcessorAffinityMaskScope;
begin
  Result := nil;
  var lAffinityMask: NativeUInt := NativeUInt(1) shl aProcessorId;
  if lAffinityMask = 0 then
    Exit;

  Result := TProcessorAffinityMaskScope.CreateProcessAffinityMaskScope(aProcessHandle);
  if not Result.SetProcessorAffinityMask(lAffinityMask) then
    Result := nil;
end;

class function TCpuAccessor.TryCastThreadToProcessor(const aThreadHandle: THandle; const aProcessorId: Byte): IProcessorAffinityMaskScope;
begin
  Result := nil;
  var lAffinityMask: NativeUInt := NativeUInt(1) shl aProcessorId;
  if lAffinityMask = 0 then
    Exit;

  Result := TProcessorAffinityMaskScope.CreateThreadAffinityMaskScope(aThreadHandle);
  if not Result.SetProcessorAffinityMask(lAffinityMask) then
    Result := nil;
end;

class function TCpuAccessor.TryCastThreadToECores(const aThreadHandle: THandle): IProcessorAffinityMaskScope;
begin
  Result := nil;
  var lAffinityMask := GetECoresAffinityMask;
  if lAffinityMask = 0 then
    Exit;

  Result := TProcessorAffinityMaskScope.CreateThreadAffinityMaskScope(aThreadHandle);
  if not Result.SetProcessorAffinityMask(lAffinityMask) then
    Result := nil;
end;

class function TCpuAccessor.TryCastThreadToPCores(const aThreadHandle: THandle): IProcessorAffinityMaskScope;
begin
  Result := nil;
  var lAffinityMask := GetPCoresAffinityMask;
  if lAffinityMask = 0 then
    Exit;

  Result := TProcessorAffinityMaskScope.CreateThreadAffinityMaskScope(aThreadHandle);
  if not Result.SetProcessorAffinityMask(lAffinityMask) then
    Result := nil;
end;

class function TCpuAccessor.CpuSetInfoSourceToStr(const aCpuSetInfoSource: TCpuSetInfoSource): string;
begin
  Result := 'Unknown';
  case aCpuSetInfoSource of
    TCpuSetInfoSource.SourceGetSystemCpuSetInformation:
      Exit('GetSystemCpuSetInformation');
    TCpuSetInfoSource.SourceGetLogicalProcessorInformationEx:
      Exit('GetLogicalProcessorInformationEx');
  end;
end;

class function TCpuAccessor.CacheTypeToStr(const aCacheType: Byte): string;
begin
  Result := 'Undefined';
  case PROCESSOR_CACHE_TYPE(aCacheType) of
    PROCESSOR_CACHE_TYPE.CacheInstruction:
      Exit('Instruction');
    PROCESSOR_CACHE_TYPE.CacheData:
      Exit('Data');
    PROCESSOR_CACHE_TYPE.CacheTrace:
      Exit('Trace');
  end;
end;

end.
