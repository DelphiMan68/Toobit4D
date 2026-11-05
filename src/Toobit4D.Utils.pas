unit Toobit4D.Utils;
{$I Toobit4D.inc}

{ Self-contained helpers: SHA-256 / HMAC-SHA256 (pure Pascal, identical on Delphi
  and FreePascal), URL encoding, UTC millisecond clock and the ordered parameter
  list used for request signing. }

interface

uses
  SysUtils;

type
  IToobitParams = interface
    ['{7B1D3C52-5E0A-4C57-9C3B-0D6E5B8E2A41}']
    function Add(const AName, AValue: string): IToobitParams; overload;
    function Add(const AName: string; AValue: Int64): IToobitParams; overload;
    { Adds only when AValue <> '' }
    function AddIf(const AName, AValue: string): IToobitParams;
    { Adds only when AValue > 0 }
    function AddPos(const AName: string; AValue: Int64): IToobitParams;
    function Has(const AName: string): Boolean;
    function Count: Integer;
    function Name(AIndex: Integer): string;
    function Value(AIndex: Integer): string;
    { name=value&name=value  (raw, exactly what is signed) }
    function ToRaw: string;
    { same order, names/values percent-encoded (what goes on the wire) }
    function ToEncoded: string;
  end;

function NewParams: IToobitParams;

function Utf8Bytes(const S: string): TBytes;
function BytesToHexLower(const B: TBytes): string;
function Sha256Bytes(const AData: TBytes): TBytes;
function HmacSha256Hex(const AKey, AMessage: string): string;
function UrlEncode(const S: string): string;

{ UTC unix time in milliseconds (local clock, no server offset). }
function ToobitUtcNowMs: Int64;
{ Monotonic millisecond tick. }
function ToobitTickMs: Int64;

{ RFC 4231 test case 2 - returns True when HMAC-SHA256 works on this compiler. }
function ToobitSelfTest: Boolean;

implementation

uses
  {$IFDEF FPC} DateUtils, LazSysUtils {$ELSE} System.DateUtils, Winapi.Windows {$ENDIF};

const
  K256: array[0..63] of Cardinal = (
    $428A2F98, $71374491, $B5C0FBCF, $E9B5DBA5,
    $3956C25B, $59F111F1, $923F82A4, $AB1C5ED5,
    $D807AA98, $12835B01, $243185BE, $550C7DC3,
    $72BE5D74, $80DEB1FE, $9BDC06A7, $C19BF174,
    $E49B69C1, $EFBE4786, $0FC19DC6, $240CA1CC,
    $2DE92C6F, $4A7484AA, $5CB0A9DC, $76F988DA,
    $983E5152, $A831C66D, $B00327C8, $BF597FC7,
    $C6E00BF3, $D5A79147, $06CA6351, $14292967,
    $27B70A85, $2E1B2138, $4D2C6DFC, $53380D13,
    $650A7354, $766A0ABB, $81C2C92E, $92722C85,
    $A2BFE8A1, $A81A664B, $C24B8B70, $C76C51A3,
    $D192E819, $D6990624, $F40E3585, $106AA070,
    $19A4C116, $1E376C08, $2748774C, $34B0BCB5,
    $391C0CB3, $4ED8AA4A, $5B9CCA4F, $682E6FF3,
    $748F82EE, $78A5636F, $84C87814, $8CC70208,
    $90BEFFFA, $A4506CEB, $BEF9A3F7, $C67178F2);

  HexLower: array[0..15] of Char = '0123456789abcdef';
  HexUpper: array[0..15] of Char = '0123456789ABCDEF';

{ ---------------------------------------------------------------- bytes -- }

function Utf8Bytes(const S: string): TBytes;
begin
  {$IFDEF FPC}
  // Toobit parameters are ASCII; copy the bytes as-is.
  SetLength(Result, Length(S));
  if Length(S) > 0 then
    Move(S[1], Result[0], Length(S));
  {$ELSE}
  Result := TEncoding.UTF8.GetBytes(S);
  {$ENDIF}
end;

function BytesToHexLower(const B: TBytes): string;
var
  I: Integer;
begin
  SetLength(Result, Length(B) * 2);
  for I := 0 to High(B) do
  begin
    Result[I * 2 + 1] := HexLower[B[I] shr 4];
    Result[I * 2 + 2] := HexLower[B[I] and $0F];
  end;
end;

{ ------------------------------------------------------------- SHA-256 -- }

function RotR(X: Cardinal; N: Integer): Cardinal;
begin
  Result := (X shr N) or (X shl (32 - N));
end;

function Sha256Bytes(const AData: TBytes): TBytes;
var
  H: array[0..7] of Cardinal;
  W: array[0..63] of Cardinal;
  LMsg: TBytes;
  LLen, LTotal, LBlock, T, I: Integer;
  LBits: Int64;
  A, B, C, D, E, F, G, HH, T1, T2, S0, S1: Cardinal;
begin
  H[0] := $6A09E667; H[1] := $BB67AE85; H[2] := $3C6EF372; H[3] := $A54FF53A;
  H[4] := $510E527F; H[5] := $9B05688C; H[6] := $1F83D9AB; H[7] := $5BE0CD19;

  // padding: 0x80, zeros, 64-bit big-endian bit length; total multiple of 64
  LLen := Length(AData);
  LTotal := ((LLen + 8) div 64 + 1) * 64;
  SetLength(LMsg, LTotal);
  FillChar(LMsg[0], LTotal, 0);
  if LLen > 0 then
    Move(AData[0], LMsg[0], LLen);
  LMsg[LLen] := $80;
  LBits := Int64(LLen) * 8;
  for I := 0 to 7 do
    LMsg[LTotal - 1 - I] := Byte((LBits shr (8 * I)) and $FF);

  for LBlock := 0 to (LTotal div 64) - 1 do
  begin
    for T := 0 to 15 do
      W[T] := (Cardinal(LMsg[LBlock * 64 + T * 4]) shl 24) or
              (Cardinal(LMsg[LBlock * 64 + T * 4 + 1]) shl 16) or
              (Cardinal(LMsg[LBlock * 64 + T * 4 + 2]) shl 8) or
               Cardinal(LMsg[LBlock * 64 + T * 4 + 3]);
    for T := 16 to 63 do
    begin
      S0 := RotR(W[T - 15], 7) xor RotR(W[T - 15], 18) xor (W[T - 15] shr 3);
      S1 := RotR(W[T - 2], 17) xor RotR(W[T - 2], 19) xor (W[T - 2] shr 10);
      W[T] := W[T - 16] + S0 + W[T - 7] + S1;
    end;

    A := H[0]; B := H[1]; C := H[2]; D := H[3];
    E := H[4]; F := H[5]; G := H[6]; HH := H[7];

    for T := 0 to 63 do
    begin
      S1 := RotR(E, 6) xor RotR(E, 11) xor RotR(E, 25);
      T1 := HH + S1 + ((E and F) xor ((E xor $FFFFFFFF) and G)) + K256[T] + W[T];
      S0 := RotR(A, 2) xor RotR(A, 13) xor RotR(A, 22);
      T2 := S0 + ((A and B) xor (A and C) xor (B and C));
      HH := G; G := F; F := E; E := D + T1;
      D := C; C := B; B := A; A := T1 + T2;
    end;

    H[0] := H[0] + A; H[1] := H[1] + B; H[2] := H[2] + C; H[3] := H[3] + D;
    H[4] := H[4] + E; H[5] := H[5] + F; H[6] := H[6] + G; H[7] := H[7] + HH;
  end;

  SetLength(Result, 32);
  for I := 0 to 7 do
  begin
    Result[I * 4]     := Byte(H[I] shr 24);
    Result[I * 4 + 1] := Byte(H[I] shr 16);
    Result[I * 4 + 2] := Byte(H[I] shr 8);
    Result[I * 4 + 3] := Byte(H[I]);
  end;
end;

function HmacSha256Hex(const AKey, AMessage: string): string;
var
  LKeyRaw, LKey, LMsg, LInner, LOuter, LDigest: TBytes;
  I: Integer;
begin
  LKeyRaw := Utf8Bytes(AKey);
  if Length(LKeyRaw) > 64 then
    LKeyRaw := Sha256Bytes(LKeyRaw);

  // block-sized key, zero padded
  SetLength(LKey, 64);
  FillChar(LKey[0], 64, 0);
  if Length(LKeyRaw) > 0 then
    Move(LKeyRaw[0], LKey[0], Length(LKeyRaw));

  LMsg := Utf8Bytes(AMessage);

  // inner = H((K xor ipad) || msg)
  SetLength(LInner, 64 + Length(LMsg));
  for I := 0 to 63 do
    LInner[I] := LKey[I] xor $36;
  if Length(LMsg) > 0 then
    Move(LMsg[0], LInner[64], Length(LMsg));
  LDigest := Sha256Bytes(LInner);

  // outer = H((K xor opad) || inner)
  SetLength(LOuter, 64 + 32);
  for I := 0 to 63 do
    LOuter[I] := LKey[I] xor $5C;
  Move(LDigest[0], LOuter[64], 32);

  Result := BytesToHexLower(Sha256Bytes(LOuter));
end;

function ToobitSelfTest: Boolean;
begin
  Result := HmacSha256Hex('Jefe', 'what do ya want for nothing?') =
    '5bdcc146bf60754e6a042426089575c75a003f089d2739839dec58b964ec3843';
end;

{ ----------------------------------------------------------- url encode -- }

function UrlEncode(const S: string): string;
var
  LBytes: TBytes;
  I: Integer;
  B: Byte;
begin
  Result := '';
  LBytes := Utf8Bytes(S);
  for I := 0 to High(LBytes) do
  begin
    B := LBytes[I];
    if ((B >= Ord('A')) and (B <= Ord('Z'))) or
       ((B >= Ord('a')) and (B <= Ord('z'))) or
       ((B >= Ord('0')) and (B <= Ord('9'))) or
       (B = Ord('-')) or (B = Ord('_')) or (B = Ord('.')) or (B = Ord('~')) then
      Result := Result + Char(B)
    else
      Result := Result + '%' + HexUpper[B shr 4] + HexUpper[B and $0F];
  end;
end;

{ -------------------------------------------------------------- clocks -- }

function ToobitUtcNowMs: Int64;
var
  LUtc: TDateTime;
begin
  {$IFDEF FPC}
  LUtc := NowUTC;
  {$ELSE}
  LUtc := TTimeZone.Local.ToUniversalTime(Now);
  {$ENDIF}
  Result := Int64(DateTimeToUnix(LUtc)) * 1000 + MilliSecondOf(LUtc);
end;

function ToobitTickMs: Int64;
begin
  {$IFDEF FPC}
  Result := GetTickCount64;
  {$ELSE}
  Result := Winapi.Windows.GetTickCount64;
  {$ENDIF}
end;

{ ------------------------------------------------------------- params -- }

type
  TToobitParams = class(TInterfacedObject, IToobitParams)
  private
    FNames: array of string;
    FValues: array of string;
    procedure Push(const AName, AValue: string);
  public
    function Add(const AName, AValue: string): IToobitParams; overload;
    function Add(const AName: string; AValue: Int64): IToobitParams; overload;
    function AddIf(const AName, AValue: string): IToobitParams;
    function AddPos(const AName: string; AValue: Int64): IToobitParams;
    function Has(const AName: string): Boolean;
    function Count: Integer;
    function Name(AIndex: Integer): string;
    function Value(AIndex: Integer): string;
    function ToRaw: string;
    function ToEncoded: string;
  end;

procedure TToobitParams.Push(const AName, AValue: string);
begin
  SetLength(FNames, Length(FNames) + 1);
  SetLength(FValues, Length(FValues) + 1);
  FNames[High(FNames)] := AName;
  FValues[High(FValues)] := AValue;
end;

function TToobitParams.Add(const AName, AValue: string): IToobitParams;
begin
  Push(AName, AValue);
  Result := Self;
end;

function TToobitParams.Add(const AName: string; AValue: Int64): IToobitParams;
begin
  Push(AName, IntToStr(AValue));
  Result := Self;
end;

function TToobitParams.AddIf(const AName, AValue: string): IToobitParams;
begin
  if AValue <> '' then
    Push(AName, AValue);
  Result := Self;
end;

function TToobitParams.AddPos(const AName: string; AValue: Int64): IToobitParams;
begin
  if AValue > 0 then
    Push(AName, IntToStr(AValue));
  Result := Self;
end;

function TToobitParams.Has(const AName: string): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to High(FNames) do
    if FNames[I] = AName then
    begin
      Result := True;
      Exit;
    end;
end;

function TToobitParams.Count: Integer;
begin
  Result := Length(FNames);
end;

function TToobitParams.Name(AIndex: Integer): string;
begin
  Result := FNames[AIndex];
end;

function TToobitParams.Value(AIndex: Integer): string;
begin
  Result := FValues[AIndex];
end;

function TToobitParams.ToRaw: string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to High(FNames) do
  begin
    if I > 0 then
      Result := Result + '&';
    Result := Result + FNames[I] + '=' + FValues[I];
  end;
end;

function TToobitParams.ToEncoded: string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to High(FNames) do
  begin
    if I > 0 then
      Result := Result + '&';
    Result := Result + UrlEncode(FNames[I]) + '=' + UrlEncode(FValues[I]);
  end;
end;

function NewParams: IToobitParams;
begin
  Result := TToobitParams.Create;
end;

end.
