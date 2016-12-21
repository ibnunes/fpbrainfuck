{$MODE objfpc}
unit fpbffucker;

interface
uses fpbftype;

type
  TFileFucker = Text;

function ReadNewFuckers(var f : TFileFucker; var newfucker : TArrToken) : boolean;
function ReadNewFuckers(fname : string; var newfucker : TArrToken) : boolean; overload;


implementation
uses
  SysUtils;

function ReadNewFuckers(var f : TFileFucker; var newfucker : TArrToken) : boolean;
var
  tok : TTokenEnum;
  op  : TToken;
begin
  ReadNewFuckers := true;
  try
    Reset(f);
    try
      for tok in TOK_ENUMERATORS do begin
        readln(f, op);
        newfucker[tok] := op;
      end;
    except
      on e: Exception do
        ReadNewFuckers := false;
    end;
  finally
    Close(f);
  end;
end;


function ReadNewFuckers(fname : string; var newfucker : TArrToken) : boolean; overload;
var f : Text;
begin
  ReadNewFuckers := FileExists(fname);
  if ReadNewFuckers then begin
    Assign(f, fname);
    ReadNewFuckers := ReadNewFuckers(f, newfucker);
  end;
end;

end.
