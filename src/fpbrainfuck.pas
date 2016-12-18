unit fpbrainfuck;
{$MODE objfpc}

interface

const
  version : string = '2.0.0';

type
  TBFCommand = string;
  TBFCode    = array of TBFCommand;
  TBFInput   = function : char;
  TBFOutput  = procedure(prompt : char);

function  ExecuteBrainfuck(filename : string) : boolean;
function  ExecuteBrainfuck(thecode : TBFCode) : boolean; overload;
procedure DefIOBrainfuck(inmethod : TBFInput; outmethod : TBFOutput);
procedure DefIOBrainfuck(inmethod : TBFInput); overload;
procedure DefIOBrainfuck(outmethod : TBFOutput); overload;
procedure ResetToBrainfuck;
function  SetBFCommands(nextcell, previouscell,
                        incrementcell, decrementcell,
                        incell, outcell,
                        initcycle, endcycle : TBFCommand) : byte;


implementation
uses crt, sysutils;

// default Brainfuck
const
  BF_NEXTCELL     = '>';
  BF_PREVIOUSCELL = '<';
  BF_INCCELL      = '+';
  BF_DECCELL      = '-';
  BF_OUTPUT       = '.';
  BF_INPUT        = ',';
  BF_BEGINCYCLE   = '[';
  BF_ENDCYCLE     = ']';
  BF_COMMANDS = [BF_NEXTCELL  , BF_PREVIOUSCELL,  // cell selector
                 BF_INCCELL   , BF_DECCELL     ,  // cell data
                 BF_OUTPUT    , BF_INPUT       ,  // IO
                 BF_BEGINCYCLE, BF_ENDCYCLE    ]; // cycles

// acting like constants
const
  MINTOK = 0;
  MAXTOK = 7;

type
  TToken = TBFCommand;
  TArrToken = array[MINTOK..MAXTOK] of TToken;

var
  TOK_NEXTCELL     : TToken;
  TOK_PREVIOUSCELL : TToken;
  TOK_INCCELL      : TToken;
  TOK_DECCELL      : TToken;
  TOK_OUTPUT       : TToken;
  TOK_INPUT        : TToken;
  TOK_BEGINCYCLE   : TToken;
  TOK_ENDCYCLE     : TToken;
  TOK_COMMANDS     : TArrToken;


type
  TBFCell    = byte;
  TBFArrCell = array of TBFCell;
  TBFCycle   = TBFCode;  // cycles are arrays of TBFCommand
  TBFIO = record
    Input  : TBFInput;
    Output : TBFOutput;
  end;

(* STATE MACHINE *)
var
  datacells : TBFArrCell;  // cells
  cellidx : longword;      // pointer
  bfIO : TBFIO;            // I/O methods
  aretokensregular : boolean;  // Are Tokens Regular? (a.k.a. all lengths equal)



function IsBFCommand(c : TBFCommand) : boolean;
var
  t : TToken;
begin
  // IsBFCommand := CharInSet(ch, BF_COMMANDS);
  IsBFCommand := false;
  for t in TOK_COMMANDS do
    if t = c then begin
      IsBFCommand := true;
      break;
    end;
end;

{$REGION Cell Management}
function CountCells : longword;
begin
  CountCells := Length(datacells);
end;

procedure CreateCell;
begin
  SetLength(datacells, Length(datacells)+1);
  datacells[High(datacells)] := 0;
end;

procedure IncCell(idx : longword);
begin
  if datacells[idx] < 255 then
    Inc(datacells[idx]);
end;

procedure DecCell(idx : longword);
begin
  if datacells[idx] > 0 then
    Dec(datacells[idx]);
end;

function GetCell(idx : longword) : TBFCell;
begin
  GetCell := datacells[idx];
end;

function CellToChar(data : TBFCell) : char;
begin
  CellToChar := Chr(data);
end;

procedure OutputCell(idx : longword);
begin
  bfIO.Output(CellToChar(GetCell(idx)));
end;

procedure InputCell(idx : longword);
begin
  datacells[idx] := Ord(PChar(bfIO.Input)^);
end;
{$ENDREGION}

{$REGION Cycle Management}
function GenerateCycle : TBFCycle;
begin
  SetLength(GenerateCycle, 0);
end;

procedure FreeCycle(var cycle : TBFCycle);
begin
  SetLength(cycle, 0);
  cycle := nil;
end;

procedure AddToCycle(ch : TBFCommand; var cycle : TBFCycle);
begin
  SetLength(cycle, Length(cycle)+1);
  cycle[High(cycle)] := ch;
end;
{$ENDREGION}

{$REGION Brainfuck interpreter}
procedure ProcessBrainfuck(ch : TBFCommand);
(* Main procedure of all! This is the brain of the interpreter. *)
begin
       if ch = TOK_INPUT        then InputCell(cellidx)
  else if ch = TOK_OUTPUT       then OutputCell(cellidx)
  else if ch = TOK_INCCELL      then IncCell(cellidx)
  else if ch = TOK_DECCELL      then DecCell(cellidx)
  else if ch = TOK_NEXTCELL     then
    begin
      Inc(cellidx);
      if CountCells-1 < cellidx then
        CreateCell;
    end
  else if ch = TOK_PREVIOUSCELL then
    begin
      if cellidx > 0 then
        Dec(cellidx);
    end;
end;

{$MACRO on}
procedure ParseBrainfuck(thecode : TBFCycle; iscycle : boolean); overload;
(* We consider that the complete program is a "cycle",
   except it terminates with the end of commands to
   process and not when the cell is zero. *)
var
  i : longword;
  cycle_count : byte;
  acycle : TBFCycle = nil;
  {$DEFINE cmd:=thecode[i]}

begin
  repeat
    i := 0;
    while i <= High(thecode) do begin

      if IsBFCommand(cmd) then begin
        // So, this is a cycle, heim? Lets do it!
        if cmd = TOK_BEGINCYCLE then begin
          acycle := GenerateCycle;
          cycle_count := 1;
          Inc(i);
          while (cmd <> TOK_ENDCYCLE) and (cycle_count > 0) do begin
            if cmd = TOK_ENDCYCLE then
              Dec(cycle_count)
            else if cmd = TOK_BEGINCYCLE then
              Inc(cycle_count);
            if cycle_count <> 0 then
              AddToCycle(cmd, acycle);
            Inc(i);
          end;
          ParseBrainfuck(acycle, true);
          FreeCycle(acycle);
        end;

        // And here we are, without a cycle!
        ProcessBrainfuck(cmd);
      end;

      Inc(i);
    end;
  until (not iscycle) or (iscycle and (GetCell(cellidx) = 0));
end;
{$MACRO off}
{$ENDREGION}

{$REGION Brainfuck source code management}
function LoadBrainfuck(filename : string; out thecode : TBFCycle) : boolean;
var
  f  : file of char;
  ch : char;
  t  : TBFCommand;
  i  : byte;
label _TOTALBREAK;

  // uncomment for debugging purposes only
  { procedure DebugCommands(const CODE : TBFCycle);
  var j : longword;
  begin
    writeln;
    for j := Low(CODE) to High(CODE) do
      writeln('cmd', j:3, ' = "', CODE[j],'"');
    writeln;
  end; }

begin
  LoadBrainfuck := FileExists(filename) and aretokensregular;
  if not LoadBrainfuck then
    Exit;

  AssignFile(f, filename);
  Reset(f);
  thecode := GenerateCycle;
  while not eof(f) do begin
    t := '';
    for i in [1..Length(TOK_COMMANDS[MINTOK])] do begin
      read(f, ch);
      t := t + ch;
      if eof(f) and (i < Length(TOK_COMMANDS[MINTOK])) then begin
        LoadBrainfuck := ch = #10;
        goto _TOTALBREAK;
      end;
    end;
    if IsBFCommand(t) then
      AddToCycle(t, thecode)
    else
      Seek(f, FilePos(f)-Length(TOK_COMMANDS[MINTOK])+1);
  end;
  _TOTALBREAK:
  CloseFile(f);
  // DebugCommands(thecode);  { uncomment for debugging purposes only }
end;

procedure ResetParser; forward;
procedure FreeBrainfuck(var thecode : TBFCycle);
begin
  FreeCycle(thecode);
  ResetParser;
end;


// uncomment for debugging purposes only
{ procedure DebugCells;
var
  i : longword;
begin
  writeln;
  writeln('DEBUG CELLS:');
  for i := Low(datacells) to High(datacells) do
    writeln('c', i:3, ' = ', datacells[i]:3);
end; }

function ExecuteBrainfuck(filename : string) : boolean;
var thecode : TBFCycle;
begin
  ExecuteBrainfuck := LoadBrainfuck(filename, thecode);
  if not ExecuteBrainfuck then
    Exit;

  ParseBrainfuck(thecode, false);
  // DebugCells;  { uncomment for debugging purposes only }
  FreeBrainfuck(thecode);
end;

function  ExecuteBrainfuck(thecode : TBFCode) : boolean; overload;
begin
  ExecuteBrainfuck := aretokensregular;
  if ExecuteBrainfuck then
    ParseBrainfuck(thecode, false);
  // DebugCells;  { uncomment for debugging purposes only }
end;
{$ENDREGION}

{$REGION Define I/O methods}
function DefaultInput : char;
begin
  DefaultInput := ReadKey;
end;

procedure DefaultOutput(ch : char);
begin
  write(ch);
end;

procedure DefIOBrainfuck(inmethod : TBFInput; outmethod : TBFOutput);
begin
  bfIO.Input  := inmethod;
  bfIO.Output := outmethod;
end;

procedure DefIOBrainfuck(inmethod : TBFInput); overload;
begin
  DefIOBrainfuck(inmethod, @DefaultOutput);
end;

procedure DefIOBrainfuck(outmethod : TBFOutput); overload;
begin
  DefIOBrainfuck(@DefaultInput, outmethod);
end;
{$ENDREGION}

procedure ResetParser;
begin
  SetLength(datacells, 1);  // every program starts with cell 'c0' defined
  datacells[0] := 0;
  cellidx := 0;
end;

function SetBFCommands(nextcell, previouscell,
                       incrementcell, decrementcell,
                       incell, outcell,
                       initcycle, endcycle : TBFCommand) : byte;
var
  i, len : byte;
begin
  TOK_NEXTCELL     := nextcell;
    TOK_COMMANDS[MINTOK]   := TOK_NEXTCELL;
  TOK_PREVIOUSCELL := previouscell;
    TOK_COMMANDS[MINTOK+1] := TOK_PREVIOUSCELL;
  TOK_INCCELL      := incrementcell;
    TOK_COMMANDS[MINTOK+2] := TOK_INCCELL;
  TOK_DECCELL      := decrementcell;
    TOK_COMMANDS[MINTOK+3] := TOK_DECCELL;
  TOK_OUTPUT       := incell;
    TOK_COMMANDS[MINTOK+4] := TOK_OUTPUT;
  TOK_INPUT        := outcell;
    TOK_COMMANDS[MINTOK+5] := TOK_INPUT;
  TOK_BEGINCYCLE   := initcycle;
    TOK_COMMANDS[MINTOK+6] := TOK_BEGINCYCLE;
  TOK_ENDCYCLE     := endcycle;
    TOK_COMMANDS[MINTOK+7] := TOK_ENDCYCLE;

  SetBFCommands := 0;
  len := Length(TOK_COMMANDS[MINTOK]);
  for i := MINTOK+1 to MAXTOK do
    if Length(TOK_COMMANDS[i]) <> len then
      Inc(SetBFCommands);
  aretokensregular := SetBFCommands = 0;
end;

procedure ResetToBrainfuck;
begin
  SetBFCommands(BF_NEXTCELL  , BF_PREVIOUSCELL,
                BF_INCCELL   , BF_DECCELL     ,
                BF_OUTPUT    , BF_INPUT       ,
                BF_BEGINCYCLE, BF_ENDCYCLE    );
end;


initialization
  ResetToBrainfuck;
  ResetParser;
  bfIO.Input  := @DefaultInput;
  bfIO.Output := @DefaultOutput;

finalization
  SetLength(datacells, 0);  // free alocated memory for cells
  datacells := nil;

end.
