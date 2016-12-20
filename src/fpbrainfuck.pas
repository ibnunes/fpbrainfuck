(*
===== fpbrainfuck =====
Unit for Free Pascal and compatible Extended Pascal, Object Pascal and Delphi compilers.

Licensed under the GNU-GPL 3.0.

Author:         Igor Nunes, a.k.a. thoga31
Versions:
  Stable:       2.0.2
  In progress:  2.1.0 ?
Date:           December 19, 2016

=== General information ===

This unit provides an interpreter for Brainfuck and regular variants.
It uses only the procedural paradigm, in spite of using the mode objfpc for some particularly useful features.

For a complete definition of "Brainfuck" and "regular variants", refer to the documentation.

For a complete OOP approach, please refer to my friend's repository, Nuno Picado, available at:
  https://github.com/nunopicado/BrainFuckParser
*)

unit fpbrainfuck;
{$MODE objfpc}

interface

const
  version : string = '2.0.2';
  CRLF = {$IFDEF windows} #13 + {$ENDIF} #10;

type
  TBFCommand = string;
  TBFCode    = array of TBFCommand;
  TBFInput   = function : char;
  TBFOutput  = procedure(prompt : char);

(* TOKENS *)
const
  MINTOK = 0;
  MAXTOK = 7;

type
  TToken    = TBFCommand;
  TArrToken = array[MINTOK..MAXTOK] of TToken;

(* METHODS *)
function  ExecuteBrainfuck(filename : string) : byte;
function  ExecuteBrainfuck(thecode : TBFCode) : byte; overload;
procedure DefIOBrainfuck(inmethod : TBFInput; outmethod : TBFOutput);
procedure DefIOBrainfuck(inmethod : TBFInput); overload;
procedure DefIOBrainfuck(outmethod : TBFOutput); overload;
procedure ResetToBrainfuck;
function  SetBFCommands(nextcell, previouscell,
                        incrementcell, decrementcell,
                        outcell, incell,
                        initcycle, endcycle : TBFCommand) : byte;
function  SetBFCommands(tokens : TArrToken) : byte; overload;

(* ==================== DEBUG MODE ==================== *)
  procedure BF_SwitchDebugMode;
  function  BF_DebugStatus : boolean;
(* ==================== DEBUG MODE ==================== *)



implementation
uses crt, sysutils, fpbferr, fpbftype;

const
  BF_COMMANDS : TArrToken = ('>', '<', '+', '-', '.', ',', '[', ']');  // Original Brainfuck, as defined by Urban Müller, 1993
  TOK_NEXTCELL     = 0;
  TOK_PREVIOUSCELL = 1;
  TOK_INCCELL      = 2;
  TOK_DECCELL      = 3;
  TOK_OUTPUT       = 4;
  TOK_INPUT        = 5;
  TOK_BEGINCYCLE   = 6;
  TOK_ENDCYCLE     = 7;
  TAPE_INITSIZE    = 65535;  // MAX_WORD

// acting like constant while the State Machine runs the code
var
  TOK_COMMANDS : TArrToken;

(* CELLS *)
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
  datacells : TBFArrCell;      // cells
  cellidx   : longword;        // pointer
  lastcell  : longword;        // indicates which cell is the last one
  bfIO      : TBFIO;           // I/O methods
  aretokensregular : boolean;  // [flag] Are Tokens Regular? (a.k.a. are all lengths equal?)
  toklen           : longword; // Length of tokens

(* ==================== DEBUG MODE ==================== *)
  var debugmode : boolean;         // [flag] Debug Mode Switch

  procedure __debug__(msg : string);
  begin
    if debugmode then write(ErrOutput, msg);
  end;
(* ==================== DEBUG MODE ==================== *)

(* IMPLEMENTATION *)
function IsBFCommand(c : TBFCommand) : boolean;
var
  t : TToken;
begin
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
  if (lastcell mod TAPE_INITSIZE) = 0 then
    SetLength(datacells, Length(datacells) + TAPE_INITSIZE);
  Inc(lastcell);
  datacells[lastcell] := 0;
end;

procedure IncCell(idx : longword);
begin
  Inc(datacells[idx]);
end;

procedure DecCell(idx : longword);
begin
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
  // Why the heck fpc is not compiling string cases? I hate this massive collection of IFs...
       if ch = TOK_COMMANDS[TOK_INPUT]        then InputCell(cellidx)
  else if ch = TOK_COMMANDS[TOK_OUTPUT]       then OutputCell(cellidx)
  else if ch = TOK_COMMANDS[TOK_INCCELL]      then IncCell(cellidx)
  else if ch = TOK_COMMANDS[TOK_DECCELL]      then DecCell(cellidx)
  else if ch = TOK_COMMANDS[TOK_NEXTCELL]     then
    begin
      Inc(cellidx);
      if CountCells-1 < cellidx then
        CreateCell;
    end
  else if ch = TOK_COMMANDS[TOK_PREVIOUSCELL] then
    begin
      if cellidx > 0 then
        Dec(cellidx);
    end;
end;

{$MACRO on}
procedure DebugCells; forward;
procedure ParseBrainfuck(thecode : TBFCycle; iscycle : boolean); overload;
(* We consider that the complete program is a "cycle",
   except it terminates with the end of commands to
   process and not when the cell is zero. *)
var
  i : longword;
  cycle_count : byte;
  acycle : TBFCycle = nil;
  _debug_acycle_ : string;
  {$DEFINE cmd:=thecode[i]}  // lets simplify the code...

begin  { TODO: change this to work with a stack and not using recursion. }
  __debug__(CRLF + 'Parsing (' + IntToStr(Length(thecode)) + ' commands received)');
  if not (iscycle and (GetCell(cellidx) = 0)) then
    repeat
      i := 0;
      while i <= High(thecode) do begin

        if IsBFCommand(cmd) then begin
          // So, this is a cycle, heim? Lets do it!
          if cmd = TOK_COMMANDS[TOK_BEGINCYCLE] then begin
            acycle := GenerateCycle;
            _debug_acycle_ := '';  // to debug issue #6
            cycle_count := 1;
            __debug__(CRLF + '{ new cycle [' + IntToStr(cycle_count));  // to debug issue #6
            while (cmd <> TOK_COMMANDS[TOK_ENDCYCLE]) or (cycle_count > 0) do begin
              Inc(i);
              if cmd = TOK_COMMANDS[TOK_ENDCYCLE] then begin
                Dec(cycle_count);
                __debug__(' -> ' + IntToStr(cycle_count) + '@' + IntToStr(i));  // to debug issue #6
              end else if cmd = TOK_COMMANDS[TOK_BEGINCYCLE] then begin
                Inc(cycle_count);
                __debug__(' -> ' + IntToStr(cycle_count) + '@' + IntToStr(i));  // to debug issue #6
              end;
              if cycle_count <> 0 then begin
                AddToCycle(cmd, acycle);
                _debug_acycle_ := _debug_acycle_ + cmd;  // to debug issue #6
              end;
            end;
            __debug__('] «' + _debug_acycle_ + '»');  // to debug issue #6
            ParseBrainfuck(acycle, true);
            FreeCycle(acycle);
            if debugmode then DebugCells;
            __debug__(' } ' + CRLF);  // to debug issue #6
          end else
            // And here we are, without a cycle!
            ProcessBrainfuck(cmd);
        end;

        Inc(i);
      end;
    until (not iscycle) or (iscycle and (GetCell(cellidx) = 0));

  __debug__(' [OK]');
end;
{$MACRO off}
{$ENDREGION}

{$REGION Brainfuck source code management}
function LoadBrainfuck(filename : string; out thecode : TBFCycle) : byte;
var
  f  : file of char;
  ch : char;
  t  : TBFCommand;
  i  : byte;
label _TOTALBREAK;

  (* ==================== DEBUG MODE ==================== *)
  // Not in use at the current version
    { procedure DebugCommands(const CODE : TBFCycle);
    var j : longword;
    begin
      writeln(ErrOutput, 'DEBUG COMMANDS:');
      for j := Low(CODE) to High(CODE) do
        writeln(ErrOutput, 'cmd', j:3, ' = "', CODE[j],'"');
    end; }
  (* ==================== DEBUG MODE ==================== *)

begin
  if not aretokensregular then
    LoadBrainfuck := ERR_TOKSIZE
  else if not FileExists(filename) then
    LoadBrainfuck := ERR_NOSOURCE
  else
    LoadBrainfuck := ERR_SUCCESS;

  if LoadBrainfuck <> ERR_SUCCESS then
    Exit;

  AssignFile(f, filename);
  Reset(f);
  thecode := GenerateCycle;
  while not eof(f) do begin
    t := '';
    for i in [1..toklen] do begin
      read(f, ch);
      t := t + ch;
      if eof(f) and (i < toklen) then begin
        if ch <> #10 then
          LoadBrainfuck := ERR_CONTROLLED;  { TODO: new error code is needed! }
        goto _TOTALBREAK;
      end;
    end;
    if IsBFCommand(t) then
      AddToCycle(t, thecode)
    else
      Seek(f, FilePos(f)-toklen+1);
  end;
  _TOTALBREAK:
  CloseFile(f);

  // if debugmode then DebugCommands(thecode);   (* === DEBUG MODE === *)
end;

procedure ResetParser; forward;
procedure FreeBrainfuck(var thecode : TBFCycle);
begin
  FreeCycle(thecode);
  ResetParser;
end;


(* ==================== DEBUG MODE ==================== *)
  procedure DebugCells;
  var
    i : longword;
  begin
    writeln(ErrOutput, CRLF, 'DEBUG CELLS:');
    for i := Low(datacells) to lastcell do
      writeln(ErrOutput, 'c', i:3, ' = ', datacells[i]:3);
  end;
(* ==================== DEBUG MODE ==================== *)

function ExecuteBrainfuck(filename : string) : byte;
var thecode : TBFCycle;
begin
  ExecuteBrainfuck := LoadBrainfuck(filename, thecode);
  if ExecuteBrainfuck <> ERR_SUCCESS then
    Exit;

  ParseBrainfuck(thecode, false);

  if debugmode then DebugCells;  (* === DEBUG MODE === *)

  FreeBrainfuck(thecode);
end;

function ExecuteBrainfuck(thecode : TBFCode) : byte; overload;
begin
  if aretokensregular then begin
    ParseBrainfuck(thecode, false);
    ExecuteBrainfuck := ERR_SUCCESS;
  end else
    ExecuteBrainfuck := ERR_TOKSIZE;

  if debugmode then DebugCells;  (* === DEBUG MODE === *)
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
  SetLength(datacells, TAPE_INITSIZE);  // every program starts with cell 'c0' defined
  lastcell := TAPE_INITSIZE-1;
  datacells[0] := 0;
  cellidx := 0;
end;

function SetBFCommands(nextcell, previouscell,
                       incrementcell, decrementcell,
                       outcell, incell,
                       initcycle, endcycle : TBFCommand) : byte;
var
  i : byte;
begin
  TOK_COMMANDS[TOK_NEXTCELL]     := nextcell;
  TOK_COMMANDS[TOK_PREVIOUSCELL] := previouscell;
  TOK_COMMANDS[TOK_INCCELL]      := incrementcell;
  TOK_COMMANDS[TOK_DECCELL]      := decrementcell;
  TOK_COMMANDS[TOK_OUTPUT]       := outcell;
  TOK_COMMANDS[TOK_INPUT]        := incell;
  TOK_COMMANDS[TOK_BEGINCYCLE]   := initcycle;
  TOK_COMMANDS[TOK_ENDCYCLE]     := endcycle;

  SetBFCommands := 0;
  toklen := Length(TOK_COMMANDS[MINTOK]);
  for i := MINTOK+1 to MAXTOK do
    if Length(TOK_COMMANDS[i]) <> toklen then
      Inc(SetBFCommands);
  aretokensregular := SetBFCommands = 0;
end;

function SetBFCommands(tokens : TArrToken) : byte; overload;
begin
  SetBFCommands :=
    SetBFCommands(tokens[TOK_NEXTCELL]  , tokens[TOK_PREVIOUSCELL],
                  tokens[TOK_INCCELL]   , tokens[TOK_DECCELL]     ,
                  tokens[TOK_OUTPUT]    , tokens[TOK_INPUT]       ,
                  tokens[TOK_BEGINCYCLE], tokens[TOK_ENDCYCLE]    );
end;

procedure ResetToBrainfuck;
begin
  SetBFCommands(BF_COMMANDS);
end;

(* ==================== DEBUG MODE ==================== *)
  procedure BF_SwitchDebugMode;
  begin
    debugmode := not debugmode;
  end;

  function BF_DebugStatus : boolean;
  begin
    BF_DebugStatus := debugmode;
  end;
(* ==================== DEBUG MODE ==================== *)


initialization
  debugmode := false;
  ResetToBrainfuck;
  ResetParser;
  bfIO.Input  := @DefaultInput;
  bfIO.Output := @DefaultOutput;

finalization
  SetLength(datacells, 0);  // free alocated memory for cells
  datacells := nil;

end.
