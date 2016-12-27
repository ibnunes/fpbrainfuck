{$MODE objfpc}
program brainfuck;
uses
  crt,          // for some multi-platform colors
  sysutils,     // for try-except routines
  fpbrainfuck,  // Brainfuck Interpreter State Machine
  fpbfarg,      // Specific unit to manage parameters
  fpbftype,     // Unit with type-definitions
  fpbffucker,   // Unit to import BF-variants (under construction)
  fpbferr;      // Error management

const
  VERSION = '1.2.1-alpha';

(* Natively supported Brainfuck-like regular variants *)
const
  //          BRAINFUCK =    >      <      +      -      .      ,      [      ]      // As defined by Urban Müller, 1993
  MORSEFUCK : TArrToken = ('.--', '--.', '..-', '-..', '-.-', '.-.', '---', '...');  // As defined by Igor Nunes, 2016
  BITFUCK   : TArrToken = ('001', '000', '010', '011', '100', '101', '110', '111');  // As defined by Nuno Picado, 2016
  COLOR_REGULAR =  7;
  COLOR_ERROR   = 12;
  COLOR_APP     = 15;

procedure WriteExit(n : byte; s : string);
begin
  TextColor(COLOR_ERROR);
  writeln(CRLF, 'A fucking error happened!');
  TextColor(COLOR_APP);
  writeln(ErrOutput, n:2, ': ', s);  // [exec] 2> [stream; e.g. /dev/null]
  {$IFDEF windows}
    readln;
  {$ELSE}
    writeln;
  {$ENDIF}
end;

function Main(ps : TSetParam) : byte;
{$MACRO on}
{$DEFINE __void__ := begin Main := ERR_VOID; Exit; end}
var
  errcode   : byte = ERR_SUCCESS;
  fucker    : TFucker;
  newfucker : TArrToken;
  _defaultflushfunc : CodePointer;

begin
  try
    if ParamCount < 1 then begin
      Main := ERR_NOARGS;
      Exit;
    end;

    fucker := GetFucker(ps);
    case fucker of
      bfBrain : {default case, already loaded} ;
      bfMorse : SetBFOperators(MORSEFUCK);
      bfBit   : SetBFOperators(BITFUCK)  ;
      bfOther :
        begin
          __void__;  // while building this feature: it returns ERR_VOID.

          // NOT TESTED YET! It compiled, but I haven't tested this even once.
          if ReadNewFuckers(ParamStr(2), newfucker) then
            SetBFOperators(newfucker)
          else begin
            Main := ERR_CONTROLLED;   // TODO: new error type is needed
            Exit;
          end;
        end;
    end;
    writeln('Using ', fucker, CRLF);

    if HasDebugMode(ps) then
      BF_SwitchDebugMode;

    _defaultflushfunc := Textrec(Output).FlushFunc;   // Saves the default FlushFunc for later
    Textrec(Output).FlushFunc := nil;                 // And now disables it

    TextColor(COLOR_REGULAR);
    errcode := ExecuteBrainfuck(ParamStr(ParamCount));

    Flush(Output);                                    // Empties stdout if it still has content
    Textrec(Output).FlushFunc := _defaultflushfunc;   // Back to default FlushFunc

    if errcode <> ERR_SUCCESS then begin
      Main := errcode;
      Exit;
    end else begin
      TextColor(COLOR_APP);
      write(CRLF, CRLF, 'I''m done brainfucking for now... geez! Give me some vodka... -.-''');
      Main := errcode;
    end;
  except
    on e : Exception do begin
      err_unexpected_message := e.message;
      Main := ERR_UNEXPECTED;
    end;
  end;
  TextColor(COLOR_REGULAR);
end;


begin
  TextColor(COLOR_APP);
  writeln('Regular Brainfuck-like Languages Interpreter');
  writeln('By: Igor Nunes. Version: ', VERSION,'. Unit Version: ', fpbrainfuck.version);

  Halt(ShowExitMessage(Main(GetParamSet), @WriteExit));
end.
