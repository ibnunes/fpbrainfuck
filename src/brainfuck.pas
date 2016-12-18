{$MODE objfpc}
{$MODESWITCH advancedrecords}
program brainfuck;
uses fpbrainfuck;

const
  CRLF = {$IFDEF windows} #13 + {$ENDIF} #10;
  VERSION = '1.1.0';

begin
  writeln('Regular Brainfuck-like Languages Interpreter');
  writeln('By: Igor Nunes. Version: ', VERSION,'. Unit Version: ', fpbrainfuck.version);
  writeln;

  SetBFCommands('.--', '--.', '..-', '-..', '-.-', '.-.', '---', '...');
              //  >      <      +      -      .      ,      [      ]

  if ParamCount < 1 then
    writeln('No source file given for brainfucking! Too scared to try it? :P')
  else if ParamCount > 1 then
    writeln('You''ve given a source file and more! I just need the source file, my dear brainfucker! ;)')
  else if not ExecuteBrainfuck(ParamStr(1)) then
    writeln('Dude! Where the heck is this source file?')
  else
    write(CRLF, 'I''m done brainfucking for now... geez! Give me some vodka... -.-''');

  {$IFDEF windows}
    readln;
  {$ELSE}
    writeln;
  {$ENDIF}
end.
