# Toobit4D Documentation

Delphi / FreePascal client library for the Toobit exchange API (Spot and Futures).
REST via RESTRequest4Delphi, WebSocket via WebSocket4D.

> **Status:** the code has not been compiled with Delphi/FPC yet (only the HMAC-SHA256 algorithm was cross-checked against Python's `hashlib`). Test first with a read-only key or very small order sizes.

## Unit index

| Unit | Document | Purpose |
|---|---|---|
| `Toobit4D` | [Toobit4D.md](Toobit4D.md) | Main class `TToobit` (entry point) |
| `Toobit4D.Types` | [Toobit4D.Types.md](Toobit4D.Types.md) | Constants, enums, exceptions |
| `Toobit4D.Utils` | [Toobit4D.Utils.md](Toobit4D.Utils.md) | SHA-256/HMAC, URL encoding, clocks, parameter list |
| `Toobit4D.Json` | [Toobit4D.Json.md](Toobit4D.Json.md) | JSON helper functions |
| `Toobit4D.Client` | [Toobit4D.Client.md](Toobit4D.Client.md) | REST core: signing, headers, errors |
| `Toobit4D.Spot` | [Toobit4D.Spot.md](Toobit4D.Spot.md) | Spot endpoints |
| `Toobit4D.Futures` | [Toobit4D.Futures.md](Toobit4D.Futures.md) | Futures endpoints (USDT-M / USDC-M) |
| `Toobit4D.Stream` | [Toobit4D.Stream.md](Toobit4D.Stream.md) | Market and user-data WebSocket streams |
| `Toobit4D.WS.Transport` | [Toobit4D.WS.Transport.md](Toobit4D.WS.Transport.md) | Abstract WebSocket transport |
| `Toobit4D.WS.WebSocket4D` | [Toobit4D.WS.WebSocket4D.md](Toobit4D.WS.WebSocket4D.md) | WebSocket4D adapter |
| `Toobit4D.inc` | (below) | Compiler settings |

## Dependency graph

```
Toobit4D --> Client --> Utils, Json, Types, (RESTRequest4D)
         |-> Spot, Futures --> Client
         '-> Stream --> Client, WS.Transport, WS.WebSocket4D --> (WebSocket4D)
```

## Installation

1. Add `Toobit4D/src`, `RESTRequest4Delphi/src` and `WebSocket4D/Source` to the compiler search path.
2. FPC: compile with `-Mdelphi`. For HTTPS under FPC the OpenSSL libraries must be next to the executable.
3. `Toobit4D.WS.WebSocket4D.pas` adapts `TWebSocket4DClient` to the library; nothing to configure. REST-only users can leave it (and `Toobit4D.Stream`) out of the project.
4. Every unit starts with `{$I Toobit4D.inc}`: it selects Delphi mode and `{$H+}` on FPC, and sets `{$Q-}{$R-}` on both compilers (required for the 32-bit wrap-around in SHA-256).

## Quick start

```pascal
uses Toobit4D, Toobit4D.Types, Toobit4D.Spot, Toobit4D.Futures;   // Pascal does not re-export units

var Toobit: TToobit;
begin
  Toobit := TToobit.Create('API_KEY', 'SECRET_KEY');
  try
    Toobit.Client.SyncTime;                       // synchronise the clock
    Writeln(Toobit.Spot.TickerPrice('BTCUSDT'));
    Writeln(Toobit.Futures.Balance);
  finally
    Toobit.Free;
  end;
end;
```

## Conventions shared by the whole library

- **Return values:** every endpoint method returns the raw JSON text of the response (`string`). Parse it with `JsonField` or your own JSON library.
- **Optional parameters:** an empty string `''` means "do not send". For optional numeric parameters `0` means "do not send" (`-1` for `scale`).
- **Order ids** (`orderId`) are always `string`.
- **Endpoint security:** `tsNone` = public, `tsApiKey` = `X-BB-APIKEY` header only, `tsSigned` = header + `timestamp` + `recvWindow` + `signature`.
- **Errors:** any non-2xx HTTP status is turned into an exception (see [Toobit4D.Types.md](Toobit4D.Types.md)).
- **Rate limits** (per Toobit docs): `REQUEST_WEIGHT` 3000 per minute and `ORDERS` 60 per 2 seconds. The library does not throttle for you; back off after an HTTP 429.

## Toobit4D.inc

```pascal
{$IFDEF FPC} {$MODE DELPHI} {$H+} {$ENDIF}
{$Q-}  // overflow checking off
{$R-}  // range checking off
```
