unit Cpu.Types;

interface

uses System.Math, Winapi.Windows;

type
  TProcessorInfoExEnumeratorProc = reference to procedure(const aProcessorInfoExRec: SYSTEM_LOGICAL_PROCESSOR_INFORMATION_EX);

  TCpuSetInfoSource = (SourceUnknown, SourceGetSystemCpuSetInformation, SourceGetLogicalProcessorInformationEx);

  TCpuVendor = (VendorUnknown, Intel, AMD, Cyrix, VIA, Transmeta, SIS, UMC, RISE,
    HV_TCG, HV_KVM, HV_VMware, HV_VirtualBox, HV_XEN, HV_MicrosoftHV, HV_Parallels, HV_BHYVE, HV_QNX);

  TInt031 = 0..31;
  TBitset32 = set of TInt031;

  CPUACCESSOR_SYSTEM_CPU_SET_INFORMATION = record
    Size: DWORD;
    Type_: DWORD;
    Id: DWORD;
    Group: Word;
    LogicalProcessorIndex: Byte;
    CoreIndex: Byte;
    LastLevelCacheIndex: Byte;
    NumaNodeIndex: Byte;
    EfficiencyClass: Byte;
    AllFlags: Byte;
    SchedulingClass: Byte;
    ReservedBytes: array[0..2] of Byte;
    AllocationTag: DWORD64;
  end;
  PCPUACCESSOR_SYSTEM_CPU_SET_INFORMATION = ^CPUACCESSOR_SYSTEM_CPU_SET_INFORMATION;

  TCpuSetInformationEnumeratorProc = reference to procedure(const aCpuSetInfoRec: CPUACCESSOR_SYSTEM_CPU_SET_INFORMATION);

  CPUACCESSOR_PROCESSOR_POWER_INFORMATION = record
    Number: ULONG;
    MaxMhz: ULONG;
    CurrentMhz: ULONG;
    MhzLimit: ULONG;
    MaxIdleState: ULONG;
    CurrentIdleState: ULONG;
  end;
  PCPUACCESSOR_PROCESSOR_POWER_INFORMATION = ^CPUACCESSOR_PROCESSOR_POWER_INFORMATION;

  TProcessorPowerEnumeratorProc = reference to procedure(const aProcessorPowerRec: CPUACCESSOR_PROCESSOR_POWER_INFORMATION);

  CPUACCESSOR_CACHE_INFORMATION = record
    CacheIndex: Word;
    LogicalProcessorIndex: Byte;
    CacheLevel: Byte;
    CacheSize: DWORD;
    LineSize: WORD;
    Type_: PROCESSOR_CACHE_TYPE;
  end;

  TCacheEnumeratorProc = reference to procedure(const aCacheRec: CPUACCESSOR_CACHE_INFORMATION);

  TGetSystemCpuSetInformation = function(const aInformation: PCPUACCESSOR_SYSTEM_CPU_SET_INFORMATION;
    const BufferLength: ULONG; var aReturnedLength: ULONG; const aProcess: THandle; const aFlags: ULONG): BOOL; stdcall;

  TGetSystemCpuSetInformationFunc = record
    Kernel32Handle: THandle;
    Found: Boolean;
    Invoke: TGetSystemCpuSetInformation;
  end;

  TGetLogicalProcessorInformationEx = function(const aRelation: LOGICAL_PROCESSOR_RELATIONSHIP;
    const aInformation: PSYSTEM_LOGICAL_PROCESSOR_INFORMATION_EX; var aReturnedLength: ULONG): BOOL; stdcall;

  TGetLogicalProcessorInformationExFunc = record
    Kernel32Handle: THandle;
    Found: Boolean;
    Invoke: TGetLogicalProcessorInformationEx;
  end;

  TPOWER_INFORMATION_LEVEL = DWORD;

  TCallNtPowerInformation = function(const aInformationLevel: TPOWER_INFORMATION_LEVEL;
    const aInputBuffer: Pointer; const aInputBufferLength: ULONG;
    const aOutputBuffer: Pointer; const aOutputBufferLength: ULONG): LONG; stdcall;

  TCallNtPowerInformationFunc = record
    DLLHandle: THandle;
    Found: Boolean;
    Invoke: TCallNtPowerInformation;
  end;

  TMemoryUnit = (Bytes, Kilobytes, Megabytes, Gigabytes, Terrabytes);

  TCpuAccessorQueryProcessState = (NotFound, AccessDenied, Successful, Failed);

const
  CpuVendorStrings: Array[TCpuVendor] of string =
    (
      '',
      'GenuineIntel',
      'AuthenticAMD',
      'CyrixInstead',
      'CentaurHauls',
      'GenuineTMx86',
      'SiS SiS SiS ',
      'UMC UMC UMC ',
      'RiseRiseRise',
      'TCGTCGTCGTCG',
      ' KVMKVMKVM  ',
      'VMwareVMware',
      'VBoxVBoxVBox',
      'XenVMMXenVMM',
      'Microsoft Hv',
      ' prl hyperv ',
      'bhyve bhyve ',
      ' QNXQVMBSQG '
    );

  MemoryUnitStrings: Array[TMemoryUnit] of string =
    (
      'Bytes',
      'KB',
      'MB',
      'GB',
      'TB'
    );

function UInt32ToBitset32(const aValue: UInt32): TBitset32;

function MemorySizeToStr(const aValue: UInt64; const aSourceUnit, aTargetUnit: TMemoryUnit;
  const aDigit: TRoundToRange = 0): string;

function GetProcessHandle(const aProcessId: NativeUInt; const aForSetInfo: Boolean;
  out aProcessHandle: THandle): TCpuAccessorQueryProcessState;

implementation

uses System.SysUtils, System.StrUtils;

function UInt32ToBitset32(const aValue: UInt32): TBitset32;
begin
  Result := [];
  var lTestbit: UInt32 := 1;
  var i := Low(TInt031);
  while True do
  begin
    if (lTestbit and aValue) = lTestbit then
      Include(Result, i);
    if i >= High(TInt031) then
      Exit;
    Inc(i);
    lTestbit := lTestbit * 2;
  end;
end;

function MemorySizeToStr(const aValue: UInt64; const aSourceUnit, aTargetUnit: TMemoryUnit;
  const aDigit: TRoundToRange): string;
begin
  var lTranslatedValue: Extended := aValue;
  if aSourceUnit < aTargetUnit then
  begin
    for var i := Succ(aSourceUnit) to aTargetUnit do
      lTranslatedValue := lTranslatedValue / 1024;
  end
  else if aTargetUnit < aSourceUnit then
  begin
    for var i := Succ(aTargetUnit) to aSourceUnit do
      lTranslatedValue := lTranslatedValue * 1024;
  end;
  lTranslatedValue := System.Math.SimpleRoundTo(lTranslatedValue, aDigit);
  var lDigitFormat := '';
  if aDigit < 0 then
    lDigitFormat := '.' + DupeString('0', Abs(aDigit));
  Result := FormatFloat('#0' + lDigitFormat, lTranslatedValue) + ' ' + MemoryUnitStrings[aTargetUnit];
end;

function GetProcessHandle(const aProcessId: NativeUInt; const aForSetInfo: Boolean;
  out aProcessHandle: THandle): TCpuAccessorQueryProcessState;
const
  PROCESS_QUERY_LIMITED_INFORMATION = $1000;
begin
  var lSetFlag: NativeUInt := 0;
  if aForSetInfo then
    lSetFlag := PROCESS_SET_INFORMATION;
  aProcessHandle := Winapi.Windows.OpenProcess(lSetFlag or PROCESS_QUERY_LIMITED_INFORMATION, False, aProcessId);
  if aProcessHandle = 0 then
    aProcessHandle := Winapi.Windows.OpenProcess(lSetFlag or PROCESS_QUERY_INFORMATION, False, aProcessId);
  if aProcessHandle = 0 then
  begin
    var lErrorCode := Winapi.Windows.GetLastError;
    if lErrorCode = Winapi.Windows.ERROR_INVALID_PARAMETER then
      Exit(TCpuAccessorQueryProcessState.NotFound);

    Exit(TCpuAccessorQueryProcessState.AccessDenied);
  end;
  Result := TCpuAccessorQueryProcessState.Successful;
end;

end.
