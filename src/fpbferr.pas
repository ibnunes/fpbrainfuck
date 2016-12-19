unit fpbferr;

interface
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
const
  ERR_SUCCESS    = 0;
  ERR_NOARGS     = 1;
  ERR_NOSOURCE   = 2;
  ERR_FUCKDEF    = 3;
  ERR_TOKSIZE    = 4;
  ERR_CONTROLLED = 5;
  ERR_UNEXPECTED = 6;
  ERR_VOID       = 9;

type
  TExitOutput = procedure (n : byte; s : string);

var
  err_unexpected_message : string = '';


function  ShowExitMessage(const exitcode : byte; print : TExitOutput) : byte;


implementation

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

end.
