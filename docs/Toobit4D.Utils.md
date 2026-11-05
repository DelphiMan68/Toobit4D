# Toobit4D.Utils

Helpers with no third-party dependencies: SHA-256 and HMAC in pure Pascal (identical on Delphi and FPC), URL encoding, the UTC clock and the ordered parameter list used for request signing.

## IToobitParams

Ordered name/value list with automatic reference counting (interface). **The order in which parameters are added is the order in which they are signed and sent**, because Toobit verifies the signature against that order. All add methods return `Self` (fluent style).

```pascal
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
```

| Method | Description |
|---|---|
| `Add` | Always adds the parameter. |
| `AddIf` | Adds only if `AValue <> ''`. |
| `AddPos` | Adds only if `AValue > 0`. |
| `Has` | Whether a name is already present (e.g. to avoid adding `timestamp` twice). |
| `Count / Name / Value` | Index access (0-based). |
| `ToRaw` | `a=1&b=2` without encoding: **exactly the string that is signed**. |
| `ToEncoded` | Same order, names and values percent-encoded: what goes on the wire. |

## Functions

| Function | Description |
|---|---|
| `NewParams: IToobitParams` | Creates an empty list. |
| `Utf8Bytes(S): TBytes` | String to bytes. Delphi uses `TEncoding.UTF8`; FPC copies the bytes as they are (Toobit parameters are ASCII). |
| `BytesToHexLower(B): string` | **Lower-case** hex (Toobit requires lower-case signatures). |
| `Sha256Bytes(AData): TBytes` | SHA-256 (32 bytes). |
| `HmacSha256Hex(AKey, AMessage): string` | HMAC-SHA256 as lower-case hex; keys longer than 64 bytes are hashed first, as the standard requires. |
| `UrlEncode(S): string` | Leaves `A-Za-z0-9-_.~` untouched; everything else becomes `%XX` (upper-case hex, over UTF-8). |
| `ToobitUtcNowMs: Int64` | UTC time in milliseconds since the epoch (local clock, no server offset). |
| `ToobitTickMs: Int64` | Monotonic millisecond tick (`GetTickCount64`) for measuring intervals. |
| `ToobitSelfTest: Boolean` | RFC 4231 test case 2 for HMAC; call it once at program start. |

## Notes

- UTC time: Delphi uses `TTimeZone.Local.ToUniversalTime(Now)`, FPC uses `NowUTC`; `DateTimeToUnix` receives UTC.
- `ToobitTickMs` uses `Winapi.Windows` on Delphi (Windows only).
- The SHA-256 code relies on 32-bit wrap-around; do not remove `{$Q-}{$R-}` from `Toobit4D.inc`.

## Example

```pascal
if not ToobitSelfTest then raise Exception.Create('HMAC broken');

P := NewParams.Add('symbol', 'BTCUSDT').AddPos('limit', 0).Add('timestamp', 1700000000000);
Sig := HmacSha256Hex(Secret, P.ToRaw);     // signs: symbol=BTCUSDT&timestamp=1700000000000
```
