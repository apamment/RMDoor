unit VideoUtils;

{$mode objfpc}{$H+}

interface

uses
  Crt {$IFDEF WINDOWS}, Windows{$ENDIF};

type
  {$IFNDEF WINDOWS}
    TCharInfo = Record
      Ch: Char;
      Attr: Byte;
    end;
  {$ENDIF}
  TScreenBuffer = Array[1..25, 1..80] of TCharInfo;

procedure CursorHide;
procedure CursorShow;
procedure FastWrite(ALine: String; AX, AY, AAttr: Byte);
function GetAttrAt(AX, AY: Byte): Byte;
function GetCharAt(AX, AY: Byte): Char;
procedure RestoreScreen(var AScreenBuf: TScreenBuffer);
procedure SaveScreen(var AScreenBuf: TScreenBuffer);
function  ScreenSizeX: Word;
function  ScreenSizeY: Word;
procedure SetAttrAt(AAttr, AX, AY: Byte);
procedure SetCharAt(ACh: Char; AX, AY: Byte);

implementation

{$IFDEF GO32V2}
  var
    Screen: TScreen absolute $B800:0000;
{$ENDIF}
{$IFDEF WINDOWS}
  var
    StdOut: THandle;
{$ENDIF}

procedure CursorHide;
begin
  cursoroff;
end;

procedure CursorShow;
begin
  cursoron;
end;

{
  Write ALine at the screen coordinates AX, AY with text attribute AAttr
}
{$IFDEF GO32V2}
procedure FastWrite(ALine: String; AX, AY, AAttr: Byte);
var
  I: Integer;
begin
  { Validate parameters }
  if ((AX < 1) OR (AX > 80) OR (AY < 1) OR (AY > 25)) then Exit;

  { Trim to fit within 80 columns }
  if (Length(ALine) > (80 - AX + 1)) then ALine := Copy(ALine, 1, 80 - AX + 1);

  for I := 1 to Length(ALine) do
  begin
    Screen[AY, AX + (I - 1)].Ch := ALine[I];
    Screen[AY, AX + (I - 1)].Attr := AAttr;
  end;
end;
{$ENDIF}
{$IFDEF UNIX}
procedure FastWrite(ALine: String; AX, AY, AAttr: Byte);
var
  NeedWindow: Boolean;
  SavedAttr: Integer;
  SavedWindMinX: Integer;
  SavedWindMinY: Integer;
  SavedWindMaxX: Integer;
  SavedWindMaxY: Integer;
  SavedXY: Integer;
begin
  { Validate parameters }
  if ((AX < 1) OR (AX > 80) OR (AY < 1) OR (AY > 25)) then Exit;

  { Trim to fit within 80 columns }
  if (Length(ALine) > (80 - AX + 1)) then ALine := Copy(ALine, 1, 80 - AX + 1);

  // Save
  NeedWindow := ((WindMinX > 1) OR (WindMinY > 1) OR (WindMaxX < 80) OR (WindmaxY < 25));
  SavedAttr := TextAttr;
  SavedWindMinX := WindMinX;
  SavedWindMinY := WindMinY;
  SavedWindMaxX := WindMaxX;
  SavedWindMaxY := WindMaxY;
  SavedXY := WhereX + (WhereY SHL 8);

  // Update
  if (NeedWindow) then Window(1, 1, 80, 25);
  GotoXY(AX, AY);
  TextAttr := AAttr;

  // Trim to fit within 79 columns if on line 25
  if ((AY = 25) AND (Length(ALine) > (79 - AX + 1))) then ALine := Copy(ALine, 1, 79 - AX + 1);

  // Output
  Write(ALine);

  // Restore
  TextAttr := SavedAttr;
  if (NeedWindow) then Window(SavedWindMinX, SavedWindMinY, SavedWindMaxX, SavedWindMaxY);
  GotoXY(SavedXY AND $00FF, (SavedXY AND $FF00) SHR 8);
end;
{$ENDIF}
{$IFDEF WINDOWS}
procedure FastWrite(ALine: String; AX, AY, AAttr: Byte);
var
  Buffer: Array[0..255] of TCharInfo;
  BufferCoord: TCoord;
  BufferSize: TCoord;
  I: Integer;
  WriteRegion: TSmallRect;
begin
  { Validate parameters }
  if ((AX < 1) OR (AX > 80) OR (AY < 1) OR (AY > 25)) then Exit;

  { Trim to fit within 80 columns }
  if (Length(ALine) > (80 - AX + 1)) then ALine := Copy(ALine, 1, 80 - AX + 1);

  for I := 0 to Length(ALine) - 1 do
  begin
    Buffer[I].Attributes := AAttr;
    Buffer[I].AsciiChar := ALine[I + 1];
  end;
  BufferSize.X := Length(ALine);
  BufferSize.Y := 1;
  BufferCoord.X := 0;
  BufferCoord.Y := 0;
  WriteRegion.Left := AX - 1;
  WriteRegion.Top := AY - 1;
  WriteRegion.Right := AX + Length(ALine) - 2;
  WriteRegion.Bottom := AY - 1;
  WriteConsoleOutput(StdOut, @Buffer, BufferSize, BufferCoord, WriteRegion);
end;
{$ENDIF}

{
  Returns the text attribute at screen position AX, AY
}
{$IFDEF GO32V2}
function GetAttrAt(AX, AY: Byte): Byte;
begin
  { Validate parameters }
  if ((AX < 1) OR (AX > 80) OR (AY < 1) OR (AY > 25)) then
  begin
    GetAttrAt := 7;
    Exit;
  end;

  GetAttrAt := Screen[AY, AX].Attr;
end;
{$ENDIF}
{$IFDEF UNIX}
function GetAttrAt(AX, AY: Byte): Byte;
begin
  { Validate parameters }
  if ((AX < 1) OR (AX > 80) OR (AY < 1) OR (AY > 25)) then
  begin
    GetAttrAt := 7;
    Exit;
  end;

  Result := ConsoleBuf^[((AY - 1) * ScreenWidth) + (AX - 1)].attr;
end;
{$ENDIF}
{$IFDEF WINDOWS}
function GetAttrAt(AX, AY: Byte): Byte;
var
  Attr: Word;
  Coord: TCoord;
  {$IFDEF FPC}NumRead: Cardinal;{$ENDIF}
  {$IFDEF VPASCAL}NumRead: Integer;{$ENDIF}
begin
  { Validate parameters }
  if ((AX < 1) OR (AX > 80) OR (AY < 1) OR (AY > 25)) then
  begin
    GetAttrAt := 7;
    Exit;
  end;

  Coord.X := AX - 1;
  Coord.Y := AY - 1;
  ReadConsoleOutputAttribute(StdOut, @Attr, 1, Coord, NumRead);
  Result := Attr;
end;
{$ENDIF}

{
  Returns the character at screen position AX, AY
}
{$IFDEF GO32V2}
function GetCharAt(AX, AY: Byte): Char;
begin
  { Validate parameters }
  if ((AX < 1) OR (AX > 80) OR (AY < 1) OR (AY > 25)) then
  begin
    GetCharAt := ' ';
    Exit;
  end;

  GetCharAt := Screen[AY, AX].Ch;
end;
{$ENDIF}
{$IFDEF UNIX}
function GetCharAt(AX, AY: Byte): Char;
begin
  { Validate parameters }
  if ((AX < 1) OR (AX > 80) OR (AY < 1) OR (AY > 25)) then
  begin
    Result := ' ';
    Exit;
  end;

  Result := ConsoleBuf^[((AY - 1) * ScreenWidth) + (AX - 1)].ch;
end;
{$ENDIF}
{$IFDEF WINDOWS}
function GetCharAt(AX, AY: Byte): Char;
var
  Ch: Char;
  Coord: TCoord;
  {$IFDEF FPC}NumRead: Cardinal;{$ENDIF}
  {$IFDEF VPASCAL}NumRead: Integer;{$ENDIF}
begin
  { Validate parameters }
  if ((AX < 1) OR (AX > 80) OR (AY < 1) OR (AY > 25)) then
  begin
    Result := ' ';
    Exit;
  end;

  Coord.X := AX - 1;
  Coord.Y := AY - 1;
  ReadConsoleOutputCharacter(StdOut, @Ch, 1, Coord, NumRead);
  if (NumRead = 0) then
  begin
    Result := #32
  end else
  begin
    Result := Ch;
  end;
end;
{$ENDIF}

{$IFDEF GO32V2}
procedure RestoreScreen(var AScreenBuf: TScreenBuf);
begin
  Move(AScreenBuf, Screen, 4000);
end;
{$ENDIF}
{$IFDEF UNIX}
procedure RestoreScreen(var AScreenBuf: TScreenBuf);
var
  X, Y: Integer;
begin
  // REETODO Don't hardcode to 80x25
  for Y := 1 to 25 do
  begin
    for X := 1 to 80 do
    begin
      SysWrtCharStrAtt(@AScreenBuf[Y][X].Ch, 1, X - 1, Y - 1, AScreenBuf[Y][X].Attr);
    end;
  end;
end;
{$ENDIF}
{$IFDEF WINDOWS}
procedure RestoreScreen(var AScreenBuf: TScreenBuffer);
var
  BufSize    : TCoord;
  WritePos   : TCoord;
  DestRect   : TSmallRect;
begin
  // REETODO Don't hardcode to 80x25
  BufSize.X       := 80;
  BufSize.Y       := 25;
  WritePos.X      := 0;
  WritePos.Y      := 0;
  DestRect.Left   := 0;
  DestRect.Top    := 0;
  DestRect.Right  := 79;
  DestRect.Bottom := 24;
  WriteConsoleOutput(GetStdHandle(STD_OUTPUT_HANDLE), @AScreenBuf[1][1], BufSize, WritePos, DestRect);
end;
{$ENDIF}

{ REETODO Should detect screen size }
{$IFDEF GO32V2}
procedure SaveScreen(var AScreenBuf: TScreenBuf);
begin
  Move(Screen, AScreenBuf, 4000);
end;
{$ENDIF}
{$IFDEF UNIX}
procedure SaveScreen(var AScreenBuf: TScreenBuf);
begin
  Move(SysTVGetSrcBuf^, AScreenBuf, SizeOf(TScreenBuf));
end;
{$ENDIF}
{$IFDEF WINDOWS}
procedure SaveScreen(var AScreenBuf: TScreenBuffer);
var
  BufSize    : TCoord;
  ReadPos    : TCoord;
  SourceRect : TSmallRect;
begin
  // REETODO Don't hardcode to 80x25
  BufSize.X         := 80;
  BufSize.Y         := 25;
  ReadPos.X         := 0;
  ReadPos.Y         := 0;
  SourceRect.Left   := 0;
  SourceRect.Top    := 0;
  SourceRect.Right  := 79;
  SourceRect.Bottom := 24;
  ReadConsoleOutput(GetStdHandle(STD_OUTPUT_HANDLE), @AScreenBuf[1][1], BufSize, ReadPos, SourceRect);
end;
{$ENDIF}

{$IFDEF GO32V2}
function ScreenSizeX: Word;
begin
  { REETODO }
  ScreenSizeX := 80;
end;
{$ENDIF}
{$IFDEF UNIX}
function ScreenSizeX: Word;
var
  Size: TSysPoint;
begin
  SysTVGetScrMode(@Size, False);
  ScreenSizeX := Size.X;
end;
{$ENDIF}
{$IFDEF WINDOWS}
function ScreenSizeX: Word;
var
  CSBI: TConsoleScreenBufferInfo;
begin
  GetConsoleScreenBufferInfo(StdOut, CSBI);
  ScreenSizeX := CSBI.srWindow.Right - CSBI.srWindow.Left + 1;
end;
{$ENDIF}

{$IFDEF GO32V2}
function ScreenSizeY: Word;
begin
  { REETODO }
  ScreenSizeY := 25;
end;
{$ENDIF}
{$IFDEF UNIX}
function ScreenSizeY: Word;
var
  Size: TSysPoint;
begin
  SysTVGetScrMode(@Size, False);
  ScreenSizeY := Size.Y;
end;
{$ENDIF}
{$IFDEF WINDOWS}
function ScreenSizeY: Word;
var
  CSBI: TConsoleScreenBufferInfo;
begin
  GetConsoleScreenBufferInfo(StdOut, CSBI);
  ScreenSizeY := CSBI.srWindow.Bottom - CSBI.srWindow.Top + 1;
end;
{$ENDIF}

{
  Set the text attribute at screen coordinate AX, AY to AAttr
}
{$IFDEF GO32V2}
procedure SetAttrAt(AAttr, AX, AY: Byte);
begin
  { Validate parameters }
  if ((AX < 1) OR (AX > 80) OR (AY < 1) OR (AY > 25)) then Exit;

  Screen[AY, AX].Attr := AAttr;
end;
{$ENDIF}
{$IFDEF UNIX}
procedure SetAttrAt(AAttr, AX, AY: Byte);
var
  NeedWindow: Boolean;
  SavedAttr: Integer;
  SavedWindMinX: Integer;
  SavedWindMinY: Integer;
  SavedWindMaxX: Integer;
  SavedWindMaxY: Integer;
  SavedXY: Integer;
begin
  { Validate parameters }
  if ((AX < 1) OR (AX > 80) OR (AY < 1) OR (AY > 25)) then Exit;

  // Save
  NeedWindow := ((WindMinX > 1) OR (WindMinY > 1) OR (WindMaxX < 80) OR (WindmaxY < 25));
  SavedAttr := TextAttr;
  SavedWindMinX := WindMinX;
  SavedWindMinY := WindMinY;
  SavedWindMaxX := WindMaxX;
  SavedWindMaxY := WindMaxY;
  SavedXY := WhereX + (WhereY SHL 8);

  // Update
  if (NeedWindow) then Window(1, 1, 80, 25);
  GotoXY(AX, AY);
  TextAttr := AAttr;

  // Output
  Write(GetCharAt(AX, AY));

  // Restore
  TextAttr := SavedAttr;
  if (NeedWindow) then Window(SavedWindMinX, SavedWindMinY, SavedWindMaxX, SavedWindMaxY);
  GotoXY(SavedXY AND $00FF, (SavedXY AND $FF00) SHR 8);
end;
{$ENDIF}
{$IFDEF WINDOWS}
procedure SetAttrAt(AAttr, AX, AY: Byte);
var
  WriteCoord: TCoord;
  {$IFDEF FPC}NumWritten: Cardinal;{$ENDIF}
  {$IFDEF VPASCAL}NumWritten: Integer;{$ENDIF}
begin
  { Validate parameters }
  if ((AX < 1) OR (AX > 80) OR (AY < 1) OR (AY > 25)) then Exit;

  WriteCoord.X := AX - 1;
  WriteCoord.Y := AY - 1;
  WriteConsoleOutputAttribute(StdOut, @AAttr, 1, WriteCoord, NumWritten);
end;
{$ENDIF}

{
  Set the character at screen coordinate AX, AY to ACH
}
{$IFDEF GO32V2}
procedure SetCharAt(ACh: Char; AX, AY: Byte);
begin
  { Validate parameters }
  if ((AX < 1) OR (AX > 80) OR (AY < 1) OR (AY > 25)) then Exit;

  Screen[AY, AX].Ch := ACh;
end;
{$ENDIF}
{$IFDEF UNIX}
procedure SetCharAt(ACh: Char; AX, AY: Byte);
var
  NeedWindow: Boolean;
  SavedAttr: Integer;
  SavedWindMinX: Integer;
  SavedWindMinY: Integer;
  SavedWindMaxX: Integer;
  SavedWindMaxY: Integer;
  SavedXY: Integer;
begin
  { Validate parameters }
  if ((AX < 1) OR (AX > 80) OR (AY < 1) OR (AY > 25)) then Exit;

  // Save
  NeedWindow := ((WindMinX > 1) OR (WindMinY > 1) OR (WindMaxX < 80) OR (WindmaxY < 25));
  SavedAttr := TextAttr;
  SavedWindMinX := WindMinX;
  SavedWindMinY := WindMinY;
  SavedWindMaxX := WindMaxX;
  SavedWindMaxY := WindMaxY;
  SavedXY := WhereX + (WhereY SHL 8);

  // Update
  if (NeedWindow) then Window(1, 1, 80, 25);
  GotoXY(AX, AY);
  TextAttr := GetAttrAt(AX, AY);

  // Output
  Write(ACh);

  // Restore
  TextAttr := SavedAttr;
  if (NeedWindow) then Window(SavedWindMinX, SavedWindMinY, SavedWindMaxX, SavedWindMaxY);
  GotoXY(SavedXY AND $00FF, (SavedXY AND $FF00) SHR 8);
end;
{$ENDIF}
{$IFDEF WINDOWS}
procedure SetCharAt(ACh: Char; AX, AY: Byte);
var
  WriteCoord: TCoord;
  {$IFDEF FPC}NumWritten: Cardinal;{$ENDIF}
  {$IFDEF VPASCAL}NumWritten: Integer;{$ENDIF}
begin
  { Validate parameters }
  if ((AX < 1) OR (AX > 80) OR (AY < 1) OR (AY > 25)) then Exit;

  WriteCoord.X := AX - 1;
  WriteCoord.Y := AY - 1;
  WriteConsoleOutputCharacter(StdOut, @ACh, 1, WriteCoord, NumWritten);
end;
{$ENDIF}

{
  Initialization stuff
}
begin
  {$IFDEF WINDOWS}
    StdOut := GetStdHandle(STD_OUTPUT_HANDLE);
  {$ENDIF}
end.

