program CpuSpecsApp;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.Classes,
  System.SysUtils,
  System.Diagnostics,
  Winapi.Windows,
  System.Generics.Collections,
  System.Generics.Defaults,
  CpuAccessor in 'CpuAccessor.pas',
  ProcessorAffinityMaskScope in 'ProcessorAffinityMaskScope.pas',
  Cpu.Tools in 'Cpu.Tools.pas',
  Cpu.Types in 'Cpu.Types.pas',
  AggregatedList in 'AggregatedList.pas',
  Enumerations in 'Enumerations.pas',
  OrderedDictionary in 'OrderedDictionary.pas',
  ProcessPriorityScope in 'ProcessPriorityScope.pas';

procedure BubbleSort(var A: array of Cardinal);
var
  i: Cardinal;
  temp: Cardinal;
  done: Boolean;
begin
  repeat
    done := True;
    for i := Low(A) to High(A) - 1 do
    begin
      if A[i] > A[i + 1] then
      begin
        temp := A[i];
        A[i] := A[i + 1];
        A[i + 1] := temp;
        done := False;
      end;
    end;
  until done;
end;

procedure ShowCpuSpecs(const aCpuSpecification: tCpuSpecification);
begin
  var lCacheL1Total: Cardinal := 0;
  var lCacheL2Total: Cardinal := 0;
  var lCacheL3Total: Cardinal := 0;
  Writeln('CPU Specification');
  Writeln('-----------------');
  Writeln('Vendor: "' + aCpuSpecification.VendorString + '"');
  Writeln('Brand: "' + aCpuSpecification.BrandString + '"');
  WriteLn('Is Hypervisor present: ' + BoolToStr(aCpuSpecification.IsHypervisorPresent, True));
  WriteLn('Hypervisor: "' + aCpuSpecification.HypervisorString + '"');
  WriteLn('Hypervisor-Version: "' + aCpuSpecification.HypervisorVersion + '"');
  Write('Is Hybrid: ' + BoolToStr(aCpuSpecification.IsHybrid, True));
  if aCpuSpecification.IsHybrid then
  begin
    Write(', MinEfficiencyClass: ' + IntToStr(Ord(aCpuSpecification.MinEfficiencyClass)));
    Write(', MaxEfficiencyClass: ' + IntToStr(Ord(aCpuSpecification.MaxEfficiencyClass)));
  end;
  Writeln;
  Writeln('CpuSet info source: "' + TCpuAccessor.CpuSetInfoSourceToStr(aCpuSpecification.CpuSetInfoSource) + '"');
  Writeln;
  Writeln('Core topology:');
  for var core in aCpuSpecification.Cores do
  begin
    Writeln('');
    Writeln('Core #' + IntToStr(core.CoreId));
    Writeln('   Efficiency class: ' + IntToStr(core.EfficiencyClass));
    for var entry in core.AggregatedProcessors.Entries do
    begin
      Write('   Clock speeds: Max. ' + IntToStr(entry.Key.MaxMhz) +
        ' MHz, limit ' + IntToStr(entry.Key.MhzLimit) +
        ' MHz, current ' + IntToStr(entry.Key.CurrentMhz) +
        ' MHz');
      Write(', Logical processor count: ' + IntToStr(entry.Value.Count));
      Writeln;
    end;
    for var entry in core.AggregatedCaches.Entries do
    begin
      var lTargetMemUnit := TMemoryUnit.Kilobytes;
      if entry.Key.Level > 1 then
        lTargetMemUnit := TMemoryUnit.Megabytes;
      Write('   Cache L' + IntToStr(entry.Key.Level) + ' #' + IntToStr(entry.Key.Id));
      if entry.Key.Type_ > 0 then
        Write(' ' + TCpuAccessor.CacheTypeToStr(entry.Key.Type_));
      Write(', Size: ' + MemorySizeToStr(entry.Key.Size, TMemoryUnit.Bytes, lTargetMemUnit));
      Write(', Lines: ' + UIntToStr(entry.Key.LineCount));
      Writeln;
    end;
  end;
  Writeln;
  Writeln('CPU cache totals:');
  for var cache in aCpuSpecification.Caches do
  begin
    if cache.Level = 1 then
      Inc(lCacheL1Total, cache.Size)
    else if cache.Level = 2 then
      Inc(lCacheL2Total, cache.Size)
    else if cache.Level = 3 then
      Inc(lCacheL3Total, cache.Size);
  end;
  Writeln('   L1: ' + MemorySizeToStr(lCacheL1Total, TMemoryUnit.Bytes, TMemoryUnit.Megabytes, -1));
  Writeln('   L2: ' + MemorySizeToStr(lCacheL2Total, TMemoryUnit.Bytes, TMemoryUnit.Megabytes, -1));
  Writeln('   L3: ' + MemorySizeToStr(lCacheL3Total, TMemoryUnit.Bytes, TMemoryUnit.Megabytes, -1));
end;

procedure PrintQueryProcessState(const aState: TCpuAccessorQueryProcessState);
begin
  case aState of
    TCpuAccessorQueryProcessState.Successful:
    begin
      Writeln('Successfully queried.');
    end;
    TCpuAccessorQueryProcessState.NotFound:
    begin
      Writeln('Process not found.');
    end;
    TCpuAccessorQueryProcessState.AccessDenied:
    begin
      Writeln('Access to process denied.');
    end;
    TCpuAccessorQueryProcessState.Failed:
    begin
      Writeln('Query failed.');
    end;
  end;
end;

function SelectProcessors(const aCpuSpecification: tCpuSpecification; const aOptionally: Boolean): string;
begin
  var lValidProcessors := TStringList.Create;
  try
    lValidProcessors.CaseSensitive := False;
    for var i in aCpuSpecification.LogicalProcessors do
      lValidProcessors.Add(IntToStr(i.ProcessorId));

    var lMessage := ' a processor [0 - ' + IntToStr(aCpuSpecification.LogicalProcessors.Count - 1) + ']';
    if aOptionally then
    begin
      lMessage := 'Optionally select' + lMessage;
      lValidProcessors.Add('');
    end
    else
    begin
      lMessage := 'Select' + lMessage;
    end;
    if aCpuSpecification.IsHybrid then
    begin
      lMessage := lMessage + ', (E)-Cores, (P)-Cores';
      lValidProcessors.Add('P');
      lValidProcessors.Add('E');
    end;
    lMessage := lMessage + ' or (S)ystem default';
    lValidProcessors.Add('S');
    var lSelection: string;
    repeat
      Write(lMessage + ': ');
      Readln(lSelection);
    until lValidProcessors.IndexOf(lSelection) >= 0;
    Result := lSelection;
  finally
    lValidProcessors.Free;
  end;
end;

function SelectProcessId: Cardinal;
begin
  Write('Process id: ');
  var lProcessIdStr: string;
  Readln(lProcessIdStr);
  if not TryStrToUInt(lProcessIdStr, Result) then
  begin
    Result := 0;
    Writeln('Invalid process id.');
    Writeln;
  end;
end;

procedure CastProcessIdToProcessor(const aCpuSpecification: tCpuSpecification);
begin
  Writeln('Cast process to processor');
  Writeln('-------------------------');
  var lProcessId := SelectProcessId;
  if lProcessId = 0 then
    Exit;

  var lSelectedProcessorStr :=  SelectProcessors(aCpuSpecification, False);
  var lResult: TCpuAccessorCastProcessToProcessorsResult;
  if SameText('S', lSelectedProcessorStr) then
  begin
    lResult := TCpuAccessor.TryCastProcessIdToSystemDefault(lProcessId, False);
  end
  else if aCpuSpecification.IsHybrid and SameText('P', lSelectedProcessorStr) then
  begin
    lResult := TCpuAccessor.TryCastProcessIdToPCores(lProcessId, False);
  end
  else if aCpuSpecification.IsHybrid and SameText('E', lSelectedProcessorStr) then
  begin
    lResult := TCpuAccessor.TryCastProcessIdToECores(lProcessId, False);
  end
  else
  begin
    lResult := TCpuAccessor.TryCastProcessIdToProcessor(lProcessId, StrToInt(lSelectedProcessorStr), False);
  end;
  PrintQueryProcessState(lResult.State);
end;

procedure PrintAffinityMask(const aProcessId: Cardinal);
begin
  var lResult := TCpuAccessor.GetProcessorsForProcess(aProcessId);
  if lResult.State = TCpuAccessorQueryProcessState.Successful then
  begin
    Write('Processors: ');
    for var i := Low(lResult.Processors) to High(lResult.Processors) do
    begin
      if i = Low(lResult.Processors) then
        Write('[')
      else
        Write(', ');
      Write(IntToStr(lResult.Processors[i].ProcessorId));
    end;
    Write(']');
  end
  else
  begin
    PrintQueryProcessState(lResult.State);
  end;
end;

procedure QueryAffinityMask;
begin
  Writeln('Query affinity mask');
  Writeln('-------------------');
  var lProcessId := SelectProcessId;
  if lProcessId = 0 then
    Exit;
  PrintAffinityMask(lProcessId);
end;

procedure SortingDemo(const aCpuSpecification: tCpuSpecification);
begin
  Writeln('Bubble sorting');
  Writeln('--------------');
  var lScope: IProcessorAffinityMaskScope := nil;
  repeat
    var lSelectedProcessorStr :=  SelectProcessors(aCpuSpecification, True);

    if Length(lSelectedProcessorStr) = 0 then
    begin
      lScope := nil;
      Break;
    end;

    var lProcMessage := '';
    if SameText('S', lSelectedProcessorStr) then
    begin
      lScope := TProcessorAffinityMaskScope.CreateProcessAffinityMaskScope(GetCurrentProcess());
      lScope.SetProcessorAffinityMaskToSystemMask();
      lProcMessage := 'System default';
    end
    else if aCpuSpecification.IsHybrid and SameText('P', lSelectedProcessorStr) then
    begin
      lScope := TCpuAccessor.TryCastProcessToPCores(GetCurrentProcess());
      lProcMessage := 'P-core processors';
    end
    else if aCpuSpecification.IsHybrid and SameText('E', lSelectedProcessorStr) then
    begin
      lScope := TCpuAccessor.TryCastProcessToECores(GetCurrentProcess());
      lProcMessage := 'E-core processors';
    end
    else
    begin
      lScope := TCpuAccessor.TryCastProcessToProcessor(GetCurrentProcess(), StrToInt(lSelectedProcessorStr));
      lProcMessage := 'processor id ' + lSelectedProcessorStr;
    end;
    if Assigned(lScope) then
    begin
      Writeln('Successfully switched to ' + lProcMessage + '.');
    end
    else
    begin
      Writeln('Switching to ' + lProcMessage + ' failed.');
    end;
  until Assigned(lScope);
  PrintAffinityMask(GetCurrentProcessId);
  Writeln;
  Writeln('Press <ENTER> to start sorting.');
  ReadLn;

  var largeList := TList<Cardinal>.Create;
  for var i := 10000 downto 1 do
    largeList.Add(i);

  var lSortRuns := 100;

  var lStopwatch := TStopwatch.StartNew;
  for var i := 1 to lSortRuns do
  begin
    Writeln('(' + FormatFloat('000', i) + '/' + IntToStr(lSortRuns) + ') Bubble sorting ' +
      UIntToStr(largeList.Count) + ' items...');
    BubbleSort(largeList.ToArray);
  end;
  Writeln;
  Writeln('Done. Elapsed time: ' + FormatFloat('#0.00', lStopwatch.Elapsed.TotalSeconds) + ' seconds.');
end;

procedure QueryProcessPriorityClass;
begin
  Writeln('Query process priority class');
  Writeln('----------------------------');
  var lProcessId := SelectProcessId;
  if lProcessId = 0 then
    Exit;

  var lProcessHandle: THandle;
  var lResult := GetProcessHandle(lProcessId, True, lProcessHandle);
  if lResult <> TCpuAccessorQueryProcessState.Successful then
  begin
    PrintQueryProcessState(lResult);
    Exit;
  end;

  Writeln('Priority class: $' + IntToHex(TProcessThreadPriorityScope.GetProcessPriority(lProcessHandle), 0));
end;

procedure SetProcessPriorityClass;
begin
  Writeln('Set process priority class');
  Writeln('--------------------------');
  var lProcessId := SelectProcessId;
  if lProcessId = 0 then
    Exit;

  var lProcessHandle: THandle;
  var lResult := GetProcessHandle(lProcessId, True, lProcessHandle);
  if lResult <> TCpuAccessorQueryProcessState.Successful then
  begin
    PrintQueryProcessState(lResult);
    Exit;
  end;

  Write('Priority class: ');
  var lPriorityClassStr: string;
  Readln(lPriorityClassStr);
  var lPriorityClass: DWORD;
  if not TryStrToUInt(lPriorityClassStr, lPriorityClass) then
  begin
    Writeln('Invalid priority class "' + lPriorityClassStr + '".');
    Exit;
  end;

  var lSetResult := TProcessThreadPriorityScope.CreateProcessPriorityScope(lProcessHandle, False)
    .SetProcessPriorityClass(lPriorityClass);
  if lSetResult.Successful then
  begin
    Writeln('Successful. Actually set to $' + IntToHex(lSetResult.ActuallySetToPriorityClass, 0) + '.');
  end
  else
  begin
    Writeln('Failed.');
  end;
end;

begin
  try
    var lCpuInfo := TCpuAccessor.GetCpuSpecification;
    while True do
    begin
      Writeln('Cpu accessor');
      Writeln('============');
      Writeln;
      Writeln('Own process id: ' + UIntToStr(GetCurrentProcessId));
      Writeln;
      Writeln('1) Show CPU specs');
      Writeln('2) Sorting demo');
      Writeln('3) Query affinity mask for process id');
      Writeln('4) Cast process id to processor');
      Writeln('5) Query process priority class');
      Writeln('6) Set process priority class');
      Writeln('Q) Quit');
      Writeln;
      Write('Please select: ');
      var lMenuCode: string;
      Readln(lMenuCode);
      Writeln;
      if SameText(lMenuCode, 'q') then
        Break
      else if SameText(lMenuCode, '1') then
        ShowCpuSpecs(lCpuInfo)
      else if SameText(lMenuCode, '2') then
        SortingDemo(lCpuInfo)
      else if SameText(lMenuCode, '3') then
        QueryAffinityMask()
      else if SameText(lMenuCode, '4') then
        CastProcessIdToProcessor(lCpuInfo)
      else if SameText(lMenuCode, '5') then
        QueryProcessPriorityClass()
      else if SameText(lMenuCode, '6') then
        SetProcessPriorityClass();
      Writeln;
    end;
  except
    on E: Exception do
    begin
      Writeln(E.ClassName, ': ', E.Message);
      Readln;
    end;
  end;
end.
