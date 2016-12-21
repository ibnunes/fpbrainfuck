(*
===== fpbrainfuck =====
Unit for Free Pascal and compatible Extended Pascal, Object Pascal and Delphi compilers.

Licensed under the GNU-GPL 3.0.

Author:         Igor Nunes, a.k.a. thoga31
Versions:
  Stable:       2.1.0-candidate
  In progress:  2.1.0-final
Date:           December 21, 2016

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
uses fpbftype;

const
  version : string = '2.1.0-candidate';
  CRLF = {$IFDEF windows} #13 + {$ENDIF} #10;

type
  TBFInput   = function : char;
  TBFOutput  = procedure(prompt : char);

(* TOKENS *)
{ type
  TToken     = TBFCommand;
  TTokenEnum = (tokNext , tokPrev,
                tokInc  , tokDec ,
                tokOut  , tokIn  ,
                tokBegin, tokEnd );
  TArrToken  = array[TTokenEnum] of TToken; }

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
uses crt, sysutils, fpbferr;

const
  TAPE_INITSIZE = 65535;  // MAX_WORD

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

  TStateMachine = record         (* STATE MACHINE *)
    datacells : TBFArrCell;      // cells
    cellidx   : longword;        // pointer
    lastcell  : longword;        // indicates which cell is the last one
    bfIO      : TBFIO;           // I/O methods
  end;

var
  sm     : TStateMachine;
  toklen : longword; // Length of tokens
  flag   : record
    aretokensregular : boolean;  // [flag] Are Tokens Regular? (a.k.a. are all lengths equal?)
    debugmode        : boolean;  // [flag] Debug Mode Switch
  end;

(* ==================== DEBUG MODE ==================== *)
  procedure __debug__(msg : string);
  begin
    if flag.debugmode then write(ErrOutput, msg);
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
  CountCells := Length(sm.datacells);
end;

procedure CreateCell;
begin
  if (sm.lastcell mod TAPE_INITSIZE) = 0 then
    SetLength(sm.datacells, Length(sm.datacells) + TAPE_INITSIZE);
  Inc(sm.lastcell);
  sm.datacells[sm.lastcell] := 0;
end;

procedure IncCell(idx : longword);
begin
  Inc(sm.datacells[idx]);
end;

procedure DecCell(idx : longword);
begin
  Dec(sm.datacells[idx]);
end;

function GetCell(idx : longword) : TBFCell;
begin
  GetCell := sm.datacells[idx];
end;

function CellToChar(data : TBFCell) : char;
begin
  CellToChar := Chr(data);
end;

procedure OutputCell(idx : longword);
begin
  sm.bfIO.Output(CellToChar(GetCell(idx)));
end;

procedure InputCell(idx : longword);
begin
  sm.datacells[idx] := Ord(PChar(sm.bfIO.Input)^);
end;
{$ENDREGION}

{$REGION Tokenizer}
function Tokenizer(oper : TBFCommand) : TTokenEnum;
var tok : TTokenEnum;
begin
  // Tokenizer := tokNone;
  for tok in TOK_ENUMERATORS do
    if TOK_COMMANDS[tok] = oper then begin
      Tokenizer := tok;
      break;
    end;
end;
{$ENDREGION}

{$REGION Brainfuck interpreter}
procedure ProcessBrainfuck(ch : TBFCommand);
(* Main procedure of all! This is the brain of the interpreter. *)

  function IncR(var n : longword) : longword;
  (* Just to avoid a little begin-end block :) *)
  begin
    Inc(n);
    IncR := n;
  end;

begin
  case Tokenizer(ch) of
    tokIn   : InputCell(sm.cellidx);
    tokOut  : OutputCell(sm.cellidx);
    tokInc  : IncCell(sm.cellidx);
    tokDec  : DecCell(sm.cellidx);
    tokNext : if CountCells-1 < IncR(sm.cellidx) then
                CreateCell;
    tokPrev : if sm.cellidx > 0 then
                Dec(sm.cellidx);
  end;
end;

{$MACRO on}
procedure ParseBrainfuck(thecode : TBFCycle); overload;
var
  i : longword;
  cycles : TStackOfWord;
  cycle_count : longword = 0;
  {$DEFINE cmd:=thecode.Token(i)}  // lets simplify the code...

  procedure SeekEndOfCycle;
  (* Just to make the code more easy for the eyes. *)
  begin
    cycle_count := 1;
    while (cmd <> TOK_COMMANDS[tokEnd]) or (cycle_count > 0) do begin
      Inc(i);
      if cmd = TOK_COMMANDS[tokBegin] then
        Inc(cycle_count)
      else if cmd = TOK_COMMANDS[tokEnd] then
        Dec(cycle_count);
    end;
  end;

begin
  i := 0;
  while i < thecode.Count do begin
    if cmd = TOK_COMMANDS[tokBegin] then begin
      if GetCell(sm.cellidx) = 0 then
        SeekEndOfCycle
      else
        cycles.Push(i);
    end
    else if cmd = TOK_COMMANDS[tokEnd] then begin
      if GetCell(sm.cellidx) = 0 then
        cycles.Pop
      else
        i := cycles.Peek;
    end else
      ProcessBrainfuck(cmd);

    Inc(i);
  end;
end;
{$MACRO off}
{$ENDREGION}

{$REGION Brainfuck source code management}
function LoadBrainfuck(filename : string; var thecode : TBFCycle) : byte;
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
      for j := 0 to CODE.Count do
        writeln(ErrOutput, 'cmd', j:3, ' = "', CODE.Token(j),'"');
    end; }
  (* ==================== DEBUG MODE ==================== *)

begin
  if not flag.aretokensregular then
    LoadBrainfuck := ERR_TOKSIZE
  else if not FileExists(filename) then
    LoadBrainfuck := ERR_NOSOURCE
  else
    LoadBrainfuck := ERR_SUCCESS;

  // __debug__('LoadBrainfuck initially returned ' + IntToStr(LoadBrainfuck) + CRLF);
  if LoadBrainfuck <> ERR_SUCCESS then
    Exit;

  AssignFile(f, filename);
  Reset(f);
  // __debug__('LoadBrainfuck is now reading the source file...' + CRLF);
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
      // __debug__('  >>> Appending token «' + t + '»' + CRLF);
      thecode.Append(t)
    else
      Seek(f, FilePos(f)-toklen+1);
  end;

  _TOTALBREAK:
  CloseFile(f);
  // __debug__('LoadBrainfuck terminated successfully.' + CRLF);

  // if debugmode then DebugCommands(thecode);   (* === DEBUG MODE === *)
end;

procedure ResetParser; forward;
procedure FreeBrainfuck;
begin
  ResetParser;
end;


(* ==================== DEBUG MODE ==================== *)
  procedure DebugCells;
  var
    i : longword;
  begin
    writeln(ErrOutput, CRLF, 'DEBUG CELLS [', sm.lastcell, ']:');
    for i := Low(sm.datacells) to sm.lastcell do
      writeln(ErrOutput, 'c', i:5, ' = ', sm.datacells[i]:3);
  end;
(* ==================== DEBUG MODE ==================== *)

function ExecuteBrainfuck(filename : string) : byte;
var thecode : TBFCycle;
begin
  ExecuteBrainfuck := LoadBrainfuck(filename, thecode);
  if ExecuteBrainfuck <> ERR_SUCCESS then
    Exit;

  ParseBrainfuck(thecode);

  if flag.debugmode then DebugCells;  (* === DEBUG MODE === *)

  FreeBrainfuck;
end;

function ExecuteBrainfuck(thecode : TBFCode) : byte; overload;
begin
  if flag.aretokensregular then begin
    ParseBrainfuck(thecode);
    ExecuteBrainfuck := ERR_SUCCESS;
  end else
    ExecuteBrainfuck := ERR_TOKSIZE;

  if flag.debugmode then DebugCells;  (* === DEBUG MODE === *)
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
  sm.bfIO.Input  := inmethod;
  sm.bfIO.Output := outmethod;
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
  SetLength(sm.datacells, TAPE_INITSIZE);  // every program starts with cell 'c0' defined
  sm.lastcell := 0;
  sm.cellidx := 0;
end;

function SetBFCommands(nextcell, previouscell,
                       incrementcell, decrementcell,
                       outcell, incell,
                       initcycle, endcycle : TBFCommand) : byte;
var
  i : TToken;
begin
  TOK_COMMANDS[tokNext]  := nextcell;
  TOK_COMMANDS[tokPrev]  := previouscell;
  TOK_COMMANDS[tokInc]   := incrementcell;
  TOK_COMMANDS[tokDec]   := decrementcell;
  TOK_COMMANDS[tokOut]   := outcell;
  TOK_COMMANDS[tokIn]    := incell;
  TOK_COMMANDS[tokBegin] := initcycle;
  TOK_COMMANDS[tokEnd]   := endcycle;

  SetBFCommands := 0;
  toklen := Length(TOK_COMMANDS[tokNext]);
  for i in TOK_COMMANDS do
    if Length(i) <> toklen then
      Inc(SetBFCommands);
  flag.aretokensregular := SetBFCommands = 0;
end;

function SetBFCommands(tokens : TArrToken) : byte; overload;
begin
  SetBFCommands :=
    SetBFCommands(tokens[tokNext] , tokens[tokPrev],
                  tokens[tokInc]  , tokens[tokDec] ,
                  tokens[tokOut]  , tokens[tokIn]  ,
                  tokens[tokBegin], tokens[tokEnd] );
end;

procedure ResetToBrainfuck;
const
  BF_COMMANDS : TArrToken = ('>', '<', '+', '-', '.', ',', '[', ']');
  // Original Brainfuck, as defined by Urban Müller, 1993
begin
  SetBFCommands(BF_COMMANDS);
end;

(* ==================== DEBUG MODE ==================== *)
  procedure BF_SwitchDebugMode;
  begin
    flag.debugmode := not flag.debugmode;
  end;

  function BF_DebugStatus : boolean;
  begin
    BF_DebugStatus := flag.debugmode;
  end;
(* ==================== DEBUG MODE ==================== *)


initialization
  flag.debugmode := false;
  ResetToBrainfuck;
  ResetParser;
  sm.bfIO.Input  := @DefaultInput;
  sm.bfIO.Output := @DefaultOutput;

finalization
  SetLength(sm.datacells, 0);  // free alocated memory for cells
  sm.datacells := nil;

end.
