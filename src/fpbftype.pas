{$MODE objfpc}
{$MODESWITCH advancedrecords}
unit fpbftype;

interface

type
  TStackOfWord = record
    private
      idx  : longword;
      data : array of word;
    public
      property Count : longword read idx;
      function Pop : word;
      function Peek : word;
      procedure Push(n : word);
      function IsEmpty : boolean;
  end;


implementation
uses
  SysUtils;

const
  INITSIZE = 65535;

function TStackOfWord.Pop : word;
begin
  Pop := self.Peek;
  { self.data[idx] := 0; }  // not exactly necessary
  Dec(self.idx);
end;

function TStackOfWord.Peek : word;
begin
  Peek := self.data[idx];
end;

procedure TStackOfWord.Push(n : word);
begin
  if (self.idx = 0) and (Length(self.data) = 0) then
    SetLength(self.data, INITSIZE)
  else if (self.idx mod INITSIZE) = 0 then
    SetLength(self.data, Length(self.data) + INITSIZE);
  Inc(self.idx);
  self.data[self.idx] := n;
end;

function TStackOfWord.IsEmpty : boolean;
begin
  IsEmpty := self.idx = 0;
end;

end.
