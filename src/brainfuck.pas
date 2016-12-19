{$MODE objfpc}
// {$MODESWITCH advancedrecords}
program brainfuck;
uses
  sysutils,
  fpbrainfuck,  // interpreter - portable for other programs.
  fpbfarg;      // specific unit to manage parameters - not portable for other programs!

const
  CRLF = {$IFDEF windows} #13 + {$ENDIF} #10;
  VERSION = '1.1.0';

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
    0 : writeln;  // success
    1 : print(exitcode, 'No source file given for brainfucking! Too scared to try it? :P');
    2 : print(exitcode, 'Dude! Where the heck is this source file?');
    3 : print(exitcode, 'External brainfuck-like language definition does not exist or is invalid.');
    4 : print(exitcode, 'Source file does not contain a correct number of characters.');
    5 : print(exitcode, 'Controlled internal error.');  // for development purposes only
    6 : print(exitcode, 'Uncontrolled general error (' + err_unexpected_message + ').');
    9 : print(exitcode, 'Unimplemented feature.');
  end;
  ShowExitMessage := exitcode;
end;

function Main(ps : TSetParam) : byte;
{$MACRO on}
{$DEFINE __err := begin Main:=}
{$DEFINE err__ := ;Exit; end}
{$DEFINE __void__ := begin __err 9 err__ end}
begin
  try
    if ParamCount < 1 then
      __err 1 err__
    else
      Main := 0;

    case GetFucker(ps) of
      bfBrain : {default case, already loaded} ;
      bfMorse : SetBFCommands(MORSEFUCK);
      bfBit   : SetBFCommands(BITFUCK)  ;
      bfOther : __void__;
    end;

    if not ExecuteBrainfuck(ParamStr(ParamCount)) then
      __err 5 err__  // expand ExecuteBrainfuck to return more that a Boolean
    else
      write(CRLF, 'I''m done brainfucking for now... geez! Give me some vodka... -.-''');
  except
    on e : Exception do begin
      __err 6 err__;
      err_unexpected_message := e.message;
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
