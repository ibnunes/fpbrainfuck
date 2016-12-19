unit fpbfarg;
{$MODE objfpc}

interface

type
  TParam = string;
  TSetParam = array of TParam;
  TFucker = (bfBrain, bfMorse, bfBit, bfOther);

const
  USE_BRAINFUCK_1 = '-bf';
  USE_BRAINFUCK_2 = '--brainfuck';

  USE_MORSEFUCK_1 = '-mf';
  USE_MORSEFUCK_2 = '--morsefuck';

  USE_BITFUCK_1   = '-bit';
  USE_BITFUCK_2   = '-bitfuck';

  USE_OTHERFUCK_1 = '-of';
  USE_OTHERFUCK_2 = '--otherfuck';

  MODE_DEBUG_1 = '-d';
  MODE_DEBUG_2 = '--debug';

  (* HALT CODES *)
  ERR_NOARGS     = 1;
  ERR_FUCKDEF    = 3;
  ERR_UNEXPECTED = 6;
  ERR_VOID       = 9;


function GetParamSet : TSetParam;
// function BF_IsValidParam(p : TParam) : boolean;
function HasDebugMode(ps : TSetParam) : boolean;
function GetFucker(ps : TSetParam) : TFucker;



implementation

uses
  SysUtils;

{ const
  DEFAULT_PARAM : TSetParam = (USE_BRAINFUCK_1, USE_BRAINFUCK_2,
                               USE_MORSEFUCK_1, USE_MORSEFUCK_2,
                               USE_BITFUCK_1  , USE_BITFUCK_2  ,
                               USE_OTHERFUCK_1, USE_OTHERFUCK_2,
                               MODE_DEBUG_1   , MODE_DEBUG_2   ); }


(* PRIVATE *)
function ParamInSet(p : TParam; ps : TSetParam) : boolean;
var elem : TParam;
begin
  ParamInSet := false;
  for elem in ps do
    if p = elem then begin
      ParamInSet := true;
      break;
    end;
end;

(* PUBLIC *)
function GetParamSet : TSetParam;
var i : word;
begin
  SetLength(GetParamSet, ParamCount);
  for i := 1 to ParamCount do
    GetParamSet[i-1] := ParamStr(i);
end;


{ function BF_IsValidParam(p : TParam) : boolean;
begin
  ParamInSet(p, DEFAULT_PARAM);
end; }


function HasDebugMode(ps : TSetParam) : boolean;
begin
  HasDebugMode := ParamInSet(MODE_DEBUG_1, ps) or ParamInSet(MODE_DEBUG_2, ps);
end;

function GetFucker(ps : TSetParam) : TFucker;
begin
  // Not beautiful, but functional
  if ParamInSet(USE_BRAINFUCK_1, ps) or ParamInSet(USE_BRAINFUCK_2, ps) then begin GetFucker := bfBrain; Exit; end;
  if ParamInSet(USE_MORSEFUCK_1, ps) or ParamInSet(USE_MORSEFUCK_2, ps) then begin GetFucker := bfMorse; Exit; end;
  if ParamInSet(USE_BITFUCK_1  , ps) or ParamInSet(USE_BITFUCK_2  , ps) then begin GetFucker := bfBit;   Exit; end;
  if ParamInSet(USE_OTHERFUCK_1, ps) or ParamInSet(USE_OTHERFUCK_2, ps) then begin GetFucker := bfOther; Exit; end;

  // So, no fucker defined? It is Brainfuck, then!
  GetFucker := bfBrain;
end;




end.
