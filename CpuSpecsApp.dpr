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
  OrderedDictionary in 'OrderedDictionary.pas';

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
  Writeln('=================');
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
  Writeln('CPU caches:');
  for var cache in aCpuSpecification.Caches do
  begin
    if cache.Level = 1 then
      Inc(lCacheL1Total, cache.Size)
    else if cache.Level = 2 then
      Inc(lCacheL2Total, cache.Size)
    else if cache.Level = 3 then
      Inc(lCacheL3Total, cache.Size);
  end;
  Writeln('');
  Writeln('Total L1 Cache: ' + MemorySizeToStr(lCacheL1Total, TMemoryUnit.Bytes, TMemoryUnit.Megabytes, -1));
  Writeln('Total L2 Cache: ' + MemorySizeToStr(lCacheL2Total, TMemoryUnit.Bytes, TMemoryUnit.Megabytes, -1));
  Writeln('Total L3 Cache: ' + MemorySizeToStr(lCacheL3Total, TMemoryUnit.Bytes, TMemoryUnit.Megabytes, -1));

  Writeln('');
  Writeln('Processor ids [0 - ' + IntToStr(aCpuSpecification.LogicalProcessors.Count - 1) + '] found.');
end;

begin
  try
    var lCpuInfo := TCpuAccessor.GetCpuSpecification;
    ShowCpuSpecs(lCpuInfo);
    while True do
    begin
      var lScope: IProcessorAffinityMaskScope := nil;
      repeat
        Writeln('');
        Write('Select a processor id [0 - ' + IntToStr(lCpuInfo.LogicalProcessors.Count - 1) + '] or S for system default');
        if lCpuInfo.IsHybrid then
        begin
          Write(' or E for E-cores or P for P-cores');
        end;
        Write(' for sorting workload: ');

        var lSelectedProcessorStr: string;
        Readln(lSelectedProcessorStr);

        var lSelectedProcessor: Cardinal;
        if not TryStrToUInt(lSelectedProcessorStr, lSelectedProcessor) then
          lSelectedProcessor := 0;
        if lSelectedProcessor > 255 then
          lSelectedProcessor := 0;

        var lProcMessage := '';
        if SameText('S', lSelectedProcessorStr) then
        begin
          lScope := TProcessorAffinityMaskScope.CreateThreadAffinityMaskScope(GetCurrentThread());
          lScope.SetProcessorAffinityMaskToSystemMask();
          lProcMessage := 'System default';
        end
        else if lCpuInfo.IsHybrid and SameText('P', lSelectedProcessorStr) then
        begin
          lScope := TCpuAccessor.TryCastThreadToPCores(GetCurrentThread());
          lProcMessage := 'P-core processors';
        end
        else if lCpuInfo.IsHybrid and SameText('E', lSelectedProcessorStr) then
        begin
          lScope := TCpuAccessor.TryCastThreadToECores(GetCurrentThread());
          lProcMessage := 'E-core processors';
        end
        else
        begin
          lScope := TCpuAccessor.TryCastThreadToProcessor(GetCurrentThread(), lSelectedProcessor);
          lProcMessage := 'processor id ' + IntToStr(lSelectedProcessor);
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
      Writeln('');
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
      Writeln;
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
