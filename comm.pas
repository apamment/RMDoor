// FOSSIL support courtesy of EleCOM http://www.elebbs.com
unit Comm;

{$mode objfpc}{$h+}

interface

{$IFDEF GO32V2}
  {$DEFINE COMM_FOSSIL}
{$ENDIF}
{$IFDEF UNIX}
  {$DEFINE COMM_SOCKET}
{$ENDIF}
{$IFDEF WINDOWS}
  {$DEFINE COMM_SOCKET}
{$ENDIF}

uses
  {$IFDEF GO32V2}
    Dos, Go32,
  {$ENDIF}
  {$IFDEF UNIX}
    BaseUnix, Sockets,
  {$ENDIF}
  {$IFDEF WINDOWS}
    Winsock, Sockets,
  {$ENDIF}
  Classes, SysUtils;

function CommCarrier: Boolean;
function CommCharAvail: Boolean;
procedure CommClose(ADisconnect: Boolean);
procedure CommFlushOutBuffer;
procedure CommOpen(ACommNumber: LongInt);
function CommPeekChar: Char;
procedure CommPurgeOutBuffer;
function CommReadChar: Char;
procedure CommSetBaud(ABaud: LongInt);
procedure CommWrite(AText: String);

implementation

var
  FBuffer: String = '';
  FCarrier: Boolean = true;
  FCommNumber: Integer = -1;
  {$IFDEF COMM_FOSSIL}
    Regs: Registers;
  {$ENDIF}

procedure CommWriteRaw(AText: String); forward;
procedure CommWriteBlock(var Block; BlockLen: LongInt); forward;
{$IFDEF GO32V2}
  procedure DosAlloc(var ASelector: Word; var ASegment: Word; ASize: LongInt); forward;
  procedure DosFree(ASelector: Word); forward;
{$ENDIF}
procedure ReceiveData; forward;

function CommCarrier: Boolean;
begin
  {$IFDEF COMM_FOSSIL}
    Regs.AH := $03;
    Regs.DX := FCommNumber;
    Intr($14, Regs);
    FCarrier := ((Regs.AL AND 128) <> 0);
  {$ENDIF}

  Result := FCarrier;
end;

function CommCharAvail: Boolean;
begin
  if (Length(FBuffer) = 0) then ReceiveData;
  Result := Length(FBuffer) > 0;
end;

procedure CommClose(ADisconnect: Boolean);
begin
  {$IFDEF COMM_SOCKET}
    if (ADisconnect) then fpShutdown(FCommNumber, 2);
    {$IFDEF UNIX}
      fpClose(FCommNumber);
    {$ENDIF}
    {$IFDEF WINDOWS}
      CloseSocket(FCommNumber);
    {$ENDIF}
  {$ENDIF}
  {$IFDEF COMM_FOSSIL}
    if (ADisconnect) then
    begin
      Regs.AH := $05;
      Regs.DX := FCommNumber;
      Intr($14, Regs);
    end;
  {$ENDIF}
end;

procedure CommFlushOutBuffer;
begin
  // REETODO No output buffer to flush at this time
end;

procedure CommOpen(ACommNumber: LongInt);
{$IFDEF COMM_SOCKET}
  var
    Arg: Integer;
{$ENDIF}
begin
  FCommNumber := ACommNumber;

  {$IFDEF COMM_FOSSIL}
    FCommNumber -= 1;

    Regs.AH := $04;
    Regs.DX := FCommNumber;
    Regs.BX := $4F50;
    Intr($14, Regs);

    FCarrier := (Regs.AX = $1954);
  {$ENDIF}
  {$IFDEF UNIX}
    // Set blocking mode
    Arg := fpFcntl(FCommNumber, F_GETFL);
    Arg := Arg AND NOT(O_NONBLOCK);
    fpFcntl(FCommNumber, F_SETFL, Arg);
  {$ENDIF}
  {$IFDEF WINDOWS}
    // Set blocking mode
    Arg := 0;
    IOCtlSocket(FCommNumber, longint(FIONBIO), Arg);
  {$ENDIF}

  {$IFDEF COMM_SOCKET}
    CommWriteRaw(#255#251#0); // Will binary
    CommWriteRaw(#255#251#1); // Will echo
  {$ENDIF}
end;

function CommPeekChar: Char;
begin
  while (Length(FBuffer) = 0) do
  begin
    Sleep(1);
    ReceiveData;
  end;

  Result := FBuffer[1];
end;

procedure CommPurgeOutBuffer;
begin
  // REETODO No output buffer to purge at this time
end;

function CommReadChar: Char;
begin
  while (Length(FBuffer) = 0) do
  begin
    Sleep(1);
    ReceiveData;
  end;

  Result := FBuffer[1];
  Delete(FBuffer, 1, 1);
end;

procedure CommSetBaud(ABaud: LongInt);
begin
  {$IFDEF COMM_FOSSIL}
    WriteLn('REEPORT Comm CommSetBaud'); Halt;
  {$ENDIF}
end;

procedure CommWrite(AText: String);
begin
  {$IFDEF COMM_SOCKET}
    // TODO Probably a better way to do this, works for now
    // TODO Also, only for Telnet mode
    AText := StringReplace(AText, #255, #255#255, [rfReplaceAll]);
  {$ENDIF}
  CommWriteBlock(AText[1], Length(AText));
end;

procedure CommWriteRaw(AText: String);
begin
  CommWriteBlock(AText[1], Length(AText));
end;

procedure CommWriteBlock(var Block; BlockLen: LongInt);
{$IFDEF GO32V2}
  var
    Selector, Segment: Word;
{$ENDIF}
begin
  // No need to do anything if BlockLen <= 0.  This also fixes a bug reported
  // by xbit, where the GO32V2 version would appear to work in local mode because
  // Global_DOS_Alloc would set Int31Error = 8 when the BlockLen = 0
  if (BlockLen <= 0) then Exit;

  {$IFDEF COMM_SOCKET}
    fpSend(FCommNumber, @Block, BlockLen, 0);
  {$ENDIF}
  {$IFDEF COMM_FOSSIL}
    DosAlloc(Selector, Segment, BlockLen);

    if Int31Error <> 0 then Exit;
    DosMemPut(Segment, 0, Block, BlockLen);

    Regs.AH := $19;
    Regs.DX := FCommNumber;
    Regs.CX := Blocklen;
    Regs.ES := Segment;
    Regs.DI := 0;
    Intr($14, Regs);

    DosMemGet(Segment, 0, Block, BlockLen);
    DosFree(Selector);
  {$ENDIF}
end;

{$IFDEF GO32V2}
procedure DosAlloc(var ASelector: Word; var ASegment: Word; ASize: LongInt);
var
  Res: Longint;
begin
  Res := Global_DOS_Alloc(ASize);
  ASelector := Word(Res);

  ASegment := Word(Res SHR 16);
end;

procedure DosFree(ASelector: Word);
begin
  Global_DOS_Free(ASelector);
end;
{$ENDIF}

procedure ReceiveData;
var
  CanRead: Boolean;
  NumRead: Integer;
  ReadArray: Array[1..1024] of Char;
  {$IFDEF COMM_SOCKET}
    FDSet: TFDSet;
    Timeout: TTimeVal;
  {$ENDIF}
  {$IFDEF GO32V2}
    Selector, Segment: Word;
  {$ENDIF}
begin
  {$IFDEF COMM_SOCKET}
    Timeout.tv_sec := 0;
    Timeout.tv_usec := 0;

    {$IFDEF UNIX}
      fpFD_ZERO(FDSet);
      fpFD_SET(FCommNumber, FDSet);
      CanRead := (fpSelect(FCommNumber + 1, @FDSet, nil, nil, @Timeout) > 0);
    {$ENDIF}
    {$IFDEF WINDOWS}
      FDSet.fd_array[0] := 0; // Does nothing, other than avoids "does not seem to be initialized" hint
      FD_ZERO(FDSet);
      FD_SET(FCommNumber, FDSet);
      CanRead := (Select(0, @FDSet, nil, nil, @Timeout) > 0);
    {$ENDIF}

    if (CanRead) then
    begin
      NumRead := fpRecv(FCommNumber, @ReadArray, SizeOf(ReadArray), 0);
      if (NumRead = -1) then
      begin
        FCarrier := false;
        // TODO Get error
      end else
      if (NumRead = 0) then
      begin
        FCarrier := false;
      end else
      begin
        FBuffer := ReadArray;
        SetLength(FBuffer, NumRead);
      end;
    end;
  {$ENDIF}
  {$IFDEF COMM_FOSSIL}
    Regs.AH := $03;
    Regs.DX := FCommNumber;
    Intr($14, Regs);
    CanRead := ((Regs.AH AND 01) <> 0);

    if (CanRead) then
    begin
      DosAlloc(Selector, Segment, SizeOf(ReadArray));

      if Int31Error <> 0 then Exit;
      DosMemPut(Segment, 0, ReadArray, SizeOf(ReadArray));

      Regs.AH := $18;
      Regs.DX := FCommNumber;
      Regs.CX := SizeOf(ReadArray);
      Regs.ES := Segment;
      Regs.DI := 0;
      Intr($14, Regs);

      NumRead := Regs.AX;

      DosMemGet(Segment, 0, ReadArray, SizeOf(ReadArray));
      DosFree(Selector);

      FBuffer := ReadArray;
      SetLength(FBuffer, NumRead);
    end;
  {$ENDIF}

  if (Length(FBuffer) > 0) then
  begin
    // TODO Probably a better way to do this, works for now
    FBuffer := StringReplace(FBuffer, #13#10, #13, [rfReplaceAll]); // CR+LF to CR
    FBuffer := StringReplace(FBuffer, #13#0, #13, [rfReplaceAll]); // CR+NULL to CR
    FBuffer := StringReplace(FBuffer, #10, #13, [rfReplaceAll]); // LF to CR
  end;
end;

end.

