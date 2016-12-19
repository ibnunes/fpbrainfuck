{$MODE objfpc}
// {$MODESWITCH advancedrecords}
program brainfuck;
uses
  sysutils,
  fpbrainfuck,  // interpreter - portable for other programs.
  fpbfarg,      // specific unit to manage parameters - not portable for other programs!
  fpbferr;

const
  VERSION = '1.1.1';

(* Natively supported Brainfuck-like regular variants *)
const
  //          BRAINFUCK =    >      <      +      -      .      ,      [      ]      // As defined by Urban Müller, 1993
  MORSEFUCK : TArrToken = ('.--', '--.', '..-', '-..', '-.-', '.-.', '---', '...');  // As defined by Igor Nunes, 2016
  BITFUCK   : TArrToken = ('001', '000', '010', '011', '100', '101', '110', '111');  // As defined by Nuno Picado, 2016

procedure WriteExit(n : byte; s : string);
begin
  writeln(CRLF, 'A fucking error happened!');
  writeln(ErrOutput, n:2, ': ', s);  // [exec] 2> [stream; e.g. /dev/null]
  {$IFDEF windows}
    readln;
  {$ELSE}
    writeln;
  {$ENDIF}
end;

function Main(ps : TSetParam) : byte;
{$MACRO on}
{$DEFINE __err := begin Main:=}
{$DEFINE err__ := ;Exit; end}
{$DEFINE __void__ := begin __err ERR_VOID err__ end}
var
  errcode : byte = ERR_SUCCESS;
  fucker  : TFucker;

begin
  try
    if ParamCount < 1 then
      __err ERR_NOARGS err__;

    fucker := GetFucker(ps);
    case fucker of
      bfBrain : {default case, already loaded} ;
      bfMorse : SetBFCommands(MORSEFUCK);
      bfBit   : SetBFCommands(BITFUCK)  ;
      bfOther : __void__;
    end;
    writeln('Using ', fucker, CRLF);

    if HasDebugMode(ps) then
      BF_SwitchDebugMode;

    errcode := ExecuteBrainfuck(ParamStr(ParamCount));
    if errcode <> ERR_SUCCESS then
      __err errcode err__
    else begin
      write(CRLF, 'I''m done brainfucking for now... geez! Give me some vodka... -.-''');
      Main := errcode;
    end;
  except
    on e : Exception do begin
      err_unexpected_message := e.message;
      __err ERR_UNEXPECTED err__;
    end;
  end;
end;


begin
  writeln('Regular Brainfuck-like Languages Interpreter');
  writeln('By: Igor Nunes. Version: ', VERSION,'. Unit Version: ', fpbrainfuck.version);

  Halt(ShowExitMessage(Main(GetParamSet), @WriteExit));
end.
