unit Cpu.Types;

interface

uses Winapi.Windows;

type
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

  TPOWER_INFORMATION_LEVEL = Byte;

  TCallNtPowerInformation = function(const aInformationLevel: TPOWER_INFORMATION_LEVEL;
    const aInputBuffer: Pointer; const aInputBufferLength: ULONG;
    const aOutputBuffer: Pointer; const aOutputBufferLength: ULONG): LONG; stdcall;

  TCallNtPowerInformationFunc = record
    DLLHandle: THandle;
    Found: Boolean;
    Invoke: TCallNtPowerInformation;
  end;

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

function UInt32ToBitset32(const aValue: UInt32): TBitset32;

implementation

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

end.
