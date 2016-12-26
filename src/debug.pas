{$REGION Public debugging methods}
procedure BF_SwitchDebugMode;
begin
  flag.debugmode := not flag.debugmode;
end;

function BF_DebugStatus : boolean;
begin
  BF_DebugStatus := flag.debugmode;
end;
{$ENDREGION}

{$REGION Private debugging methods}
procedure __debug__(msg : string);
begin
  if flag.debugmode then write(ErrOutput, msg);
end;

procedure DebugCells;
var
  i : longword;
begin
  writeln(ErrOutput, CRLF, 'DEBUG CELLS [', sm.lastcell, ']:');
  for i := Low(sm.datacells) to sm.lastcell do
    writeln(ErrOutput, 'c', i:5, ' = ', sm.datacells[i]:3);
end;

// Not in use at the current version
{ procedure DebugCommands(const CODE : TBFCycle);
  var j : longword;
  begin
    writeln(ErrOutput, 'DEBUG COMMANDS:');
    for j := 0 to CODE.Count do
      writeln(ErrOutput, 'cmd', j:3, ' = "', CODE.Token(j),'"');
  end; }

{$ENDREGION}
