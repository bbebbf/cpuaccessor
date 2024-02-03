unit Cpu.Tools;

interface

uses Cpu.Types;

type
  TCpuTools = class
  public
    class function GetSystemCpuSetInformationFunc: TGetSystemCpuSetInformationFunc;
    class function GetLogicalProcessorInformationExFunc: TGetLogicalProcessorInformationExFunc;
    class function GetCallNtPowerInformationFunc: TCallNtPowerInformationFunc;
    class function EnumGetSystemCpuSetInformation(const aEnumeratorProc: TCpuSetInformationEnumeratorProc;
      const aProcessHandle: THandle = 0): Boolean;
    class function EnumGetLogicalProcessorInformationEx(const aEnumeratorProc: TCpuSetInformationEnumeratorProc): Boolean;
    class function ReadClockSpeedsFromCallNtPowerInformation(const aLogicalProcessorCount: Integer;
      const aEnumeratorProc: TProcessorPowerEnumeratorProc): Boolean;
  end;

implementation

uses Winapi.Windows;

{ TCpuTools }

class function TCpuTools.EnumGetLogicalProcessorInformationEx(const aEnumeratorProc: TCpuSetInformationEnumeratorProc): Boolean;
begin
  Result := False;
  var lBuffer: Pointer := nil;
  var lGetLogicalProcessorInformationExFunc := TCpuTools.GetLogicalProcessorInformationExFunc;
  if not lGetLogicalProcessorInformationExFunc.Found then
    Exit;

  try
    var lReturnLength: DWORD := 0;
    var lInfoFound := False;

    if not lGetLogicalProcessorInformationExFunc.Invoke(RelationProcessorCore, lBuffer, lReturnLength) then
    begin
      if GetLastError() = ERROR_INSUFFICIENT_BUFFER then
      begin
        lBuffer := GetMemory(lReturnLength);
        lInfoFound := lGetLogicalProcessorInformationExFunc.Invoke(RelationProcessorCore, lBuffer, lReturnLength);
      end;
    end;
    if (not lInfoFound) or (lReturnLength = 0) then
      Exit;

    var lCurrentCoreIndex: Integer := 0;
    var lCurrentLogicalProcessorIndex: Integer := 0;

    Result := True;
    var lCurrentPtr: PSYSTEM_LOGICAL_PROCESSOR_INFORMATION_EX := lBuffer;
    var lBytesRead: DWORD := 0;

    while True do
    begin
      if lCurrentPtr.Relationship = RelationProcessorCore then
      begin
        var lCurrentLogicalProcessorCount: Integer := 0;
        var lEfficiencyClass: Byte := lCurrentPtr.Processor.Reserved[0];
        for var i := 0 to (SizeOf(lCurrentPtr.Processor.GroupMask[0].Mask) * 8) - 1 do
        begin
          var lTestbit: ULONG32 := 1 shl i;
          // If lLogicalProcessor is not set in bit mask then continue.
          if lCurrentPtr.Processor.GroupMask[0].Mask and lTestbit <> lTestbit then
            Continue;

          var lCpuSetInfoRec: CPUACCESSOR_SYSTEM_CPU_SET_INFORMATION := default(CPUACCESSOR_SYSTEM_CPU_SET_INFORMATION);
          lCpuSetInfoRec.CoreIndex := lCurrentCoreIndex;
          lCpuSetInfoRec.LogicalProcessorIndex := lCurrentLogicalProcessorIndex;
          lCpuSetInfoRec.EfficiencyClass := lEfficiencyClass;
          aEnumeratorProc(lCpuSetInfoRec);

          Inc(lCurrentLogicalProcessorIndex);
          Inc(lCurrentLogicalProcessorCount);
        end;
        Inc(lCurrentCoreIndex, lCurrentLogicalProcessorCount);
      end;

      Inc(lBytesRead, lCurrentPtr.Size);
      if lBytesRead >= lReturnLength then
        Break;
      lCurrentPtr := Pointer(Cardinal(lCurrentPtr) + lCurrentPtr.Size);
    end;
  finally
    FreeMemory(lBuffer);
    FreeLibrary(lGetLogicalProcessorInformationExFunc.Kernel32Handle);
  end;
end;

class function TCpuTools.EnumGetSystemCpuSetInformation(const aEnumeratorProc: TCpuSetInformationEnumeratorProc;
  const aProcessHandle: THandle): Boolean;
begin
  Result := False;
  var lBuffer: Pointer := nil;
  var lGetSystemCpuSetInformationFunction := TCpuTools.GetSystemCpuSetInformationFunc;
  if not lGetSystemCpuSetInformationFunction.Found then
    Exit;

  try
    var lReturnLength: DWORD := 0;
    var lInfoFound := False;

    if not lGetSystemCpuSetInformationFunction.Invoke(lBuffer, 0, lReturnLength, aProcessHandle, 0) then
    begin
      if GetLastError() = ERROR_INSUFFICIENT_BUFFER then
      begin
        lBuffer := GetMemory(lReturnLength);
        lInfoFound := lGetSystemCpuSetInformationFunction.Invoke(lBuffer, lReturnLength, lReturnLength, aProcessHandle, 0);
      end;
    end;
    if (not lInfoFound) or (lReturnLength = 0) then
      Exit;

    Result := True;
    var lCurrentPtr: PCPUACCESSOR_SYSTEM_CPU_SET_INFORMATION := lBuffer;
    var lBytesRead: DWORD := 0;

    while True do
    begin
      aEnumeratorProc(lCurrentPtr^);

      Inc(lBytesRead, lCurrentPtr.Size);
      if lBytesRead >= lReturnLength then
        Break;
      lCurrentPtr := Pointer(Cardinal(lCurrentPtr) + lCurrentPtr.Size);
    end;
  finally
    FreeMemory(lBuffer);
    FreeLibrary(lGetSystemCpuSetInformationFunction.Kernel32Handle);
  end;
end;

class function TCpuTools.GetCallNtPowerInformationFunc: TCallNtPowerInformationFunc;
begin
  Result := default(TCallNtPowerInformationFunc);
  Result.DLLHandle := LoadLibrary(PChar('PowrProf.dll'));
  if Result.DLLHandle = 0 then
    Exit;

  Result.Invoke := GetProcAddress(Result.DLLHandle, 'CallNtPowerInformation');
  Result.Found := Assigned(Result.Invoke);
  if not Result.Found then
  begin
    FreeLibrary(Result.DLLHandle);
    Result.DLLHandle := 0;
  end;
end;

class function TCpuTools.GetLogicalProcessorInformationExFunc: TGetLogicalProcessorInformationExFunc;
begin
  Result := default(TGetLogicalProcessorInformationExFunc);
  Result.Kernel32Handle := LoadLibrary(PChar('kernel32.dll'));
  if Result.Kernel32Handle = 0 then
    Exit;

  Result.Invoke := GetProcAddress(Result.Kernel32Handle, 'GetLogicalProcessorInformationEx');
  Result.Found := Assigned(Result.Invoke);
  if not Result.Found then
  begin
    FreeLibrary(Result.Kernel32Handle);
    Result.Kernel32Handle := 0;
  end;
end;

class function TCpuTools.GetSystemCpuSetInformationFunc: TGetSystemCpuSetInformationFunc;
begin
  Result := default(TGetSystemCpuSetInformationFunc);
  Result.Kernel32Handle := LoadLibrary(PChar('kernel32.dll'));
  if Result.Kernel32Handle = 0 then
    Exit;

  Result.Invoke := GetProcAddress(Result.Kernel32Handle, 'GetSystemCpuSetInformation');
  Result.Found := Assigned(Result.Invoke);
  if not Result.Found then
  begin
    FreeLibrary(Result.Kernel32Handle);
    Result.Kernel32Handle := 0;
  end;
end;

class function TCpuTools.ReadClockSpeedsFromCallNtPowerInformation(const aLogicalProcessorCount: Integer;
  const aEnumeratorProc: TProcessorPowerEnumeratorProc): Boolean;
const ProcessorInformation = 11;
begin
  Result := False;
  var lGetCallNtPowerInformationFunc := TCpuTools.GetCallNtPowerInformationFunc;
  if not lGetCallNtPowerInformationFunc.Found then
    Exit;

  var lBuffer: Pointer := nil;
  try
    var lPROCESSOR_POWER_INFORMATIONSize := SizeOf(CPUACCESSOR_PROCESSOR_POWER_INFORMATION);
    var lOutputBufferLength := aLogicalProcessorCount * lPROCESSOR_POWER_INFORMATIONSize;
    lBuffer := GetMemory(lOutputBufferLength);
    if lGetCallNtPowerInformationFunc.Invoke(ProcessorInformation, nil, 0, lBuffer, lOutputBufferLength) <> 0 then
      Exit;

    Result := True;
    var lProcessorPowerInfo: PCPUACCESSOR_PROCESSOR_POWER_INFORMATION := lBuffer;
    var lBytesRead: Integer := 0;
    while True do
    begin
      aEnumeratorProc(lProcessorPowerInfo^);
      Inc(lBytesRead, lPROCESSOR_POWER_INFORMATIONSize);
      if lBytesRead >= lOutputBufferLength then
        Break;
      lProcessorPowerInfo := Pointer(Cardinal(lProcessorPowerInfo) + lPROCESSOR_POWER_INFORMATIONSize);
    end;
  finally
    FreeMemory(lBuffer);
    FreeLibrary(lGetCallNtPowerInformationFunc.DLLHandle);
  end;
end;

end.
