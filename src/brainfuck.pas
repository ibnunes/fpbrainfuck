{$MODE objfpc}
// {$MODESWITCH advancedrecords}
program brainfuck;
uses
  sysutils,
  fpbrainfuck,  // interpreter - portable for other programs.
  fpbfarg;      // specific unit to manage parameters - not portable for other programs!

const
  CRLF = {$IFDEF windows} #13 + {$ENDIF} #10;
  VERSION = '1.1.1';

(* Natively supported Brainfuck-like regular variants *)
const
  //           BRAINFUCK:    >      <      +      -      .      ,      [      ]      // As defined by Urban Müller, 1993
  MORSEFUCK : TArrToken = ('.--', '--.', '..-', '-..', '-.-', '.-.', '---', '...');  // As defined by Igor Nunes, 2016
  BITFUCK   : TArrToken = ('001', '000', '010', '011', '100', '101', '110', '111');  // As defined by Nuno Picado, 2016

(*
  HALT CODES
    0 = success
    1 = no arguments given
    2 = source file does no exist
    3 = external brainfuck-like language definition does not exist or is invalid
    4 = source file does not contain a correct number of characters
    5 = controlled internal error
    6 = uncontrolled general error
    9 = unimplemented feature
*)

type
  TExitOutput = procedure (n : byte; s : string);

var
  err_unexpected_message : string = '';

procedure WriteExit(n : byte; s : string);
begin
  writeln(CRLF, n:2, ': ', s);
  {$IFDEF windows}
    readln;
  {$ELSE}
    writeln;
  {$ENDIF}
end;

function ShowExitMessage(const exitcode : byte; print : TExitOutput) : byte;
(* Shows the meaning of the exit code and returns it unchanged *)
begin
  case exitcode of
    ERR_SUCCESS    : writeln;  // success
    ERR_NOARGS     : print(exitcode, 'No source file given for brainfucking! Too scared to try it? :P');
    ERR_NOSOURCE   : print(exitcode, 'Dude! Where the heck is this source file?');
    ERR_FUCKDEF    : print(exitcode, 'External brainfuck-like language definition does not exist or is invalid.');
    ERR_TOKSIZE    : print(exitcode, 'Source file does not contain a correct number of characters.');
    ERR_CONTROLLED : print(exitcode, 'Controlled internal error.');  // for development purposes only
    ERR_UNEXPECTED : print(exitcode, 'Uncontrolled general error (' + err_unexpected_message + ').');
    ERR_VOID       : print(exitcode, 'Unimplemented feature.');
  end;
  ShowExitMessage := exitcode;
end;

function Main(ps : TSetParam) : byte;
{$MACRO on}
{$DEFINE __err := begin Main:=}
{$DEFINE err__ := ;Exit; end}
{$DEFINE __void__ := begin __err ERR_VOID err__ end}
var
  errcode : byte = ERR_SUCCESS;

begin
  try
    if ParamCount < 1 then
      __err ERR_NOARGS err__;

    case GetFucker(ps) of
      bfBrain : {default case, already loaded} ;
      bfMorse : SetBFCommands(MORSEFUCK);
      bfBit   : SetBFCommands(BITFUCK)  ;
      bfOther : __void__;
    end;

    errcode := ExecuteBrainfuck(ParamStr(ParamCount));
    if errcode <> ERR_SUCCESS then
      __err errcode err__  // expand ExecuteBrainfuck to return more that a Boolean
    else
      write(CRLF, 'I''m done brainfucking for now... geez! Give me some vodka... -.-''');
    Main := errcode;
  except
    on e : Exception do begin
      err_unexpected_message := e.message;
      __err ERR_UNEXPECTED err__;
    end;
  end;
end;


begin
  writeln('Regular Brainfuck-like Languages Interpreter');
  writeln('By: Igor Nunes. Version: ', VERSION,'. Unit Version: ', fpbrainfuck.version, CRLF);

  { Should I use 'Halt' to return the exit code to the OS?
    Uncomment next line to use it. }
  // {$DEFINE usehalt}
  {$IFDEF usehalt}
  writeln('NOTE: ''usehal'' is defined.', CRLF);
  Halt(ShowExitMessage(Main(GetParamSet), @WriteExit));
  {$ELSE}
  ShowExitMessage(Main(GetParamSet), @WriteExit);
  {$ENDIF}
end.
