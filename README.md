<div align="center">
  <img src="Images/banner.png" alt="Toobit4D — A dependency-light Toobit exchange API client for Delphi and FreePascal" width="100%" />
</div>

# Toobit4D

**A dependency-light Toobit exchange API client for Delphi and FreePascal.**

Toobit4D wraps the public Toobit REST and WebSocket API (Spot and USDT-M / USDC-M Futures) in a small set of Pascal units: HMAC-SHA256 request signing, server-clock synchronisation, ordered parameter handling, typed exceptions for HTTP failures, order/market/account/wallet/position endpoint wrappers, and WebSocket streams with automatic ping, reconnect, re-subscription and listenKey keep-alive. HTTP is delegated to [RESTRequest4Delphi](https://github.com/viniciussanchez/RESTRequest4Delphi) and WebSocket to [WebSocket4D](https://github.com/DelphiMan68/WebSocket4D). Cryptography (SHA-256, HMAC) is implemented in pure Pascal, so the signing code is identical on both compilers and needs no OpenSSL or third-party hash unit. Thread-safety guarantees are component-specific: a `TToobitClient` holds no shared mutable state apart from its configuration properties, so set `ApiKey`, `SecretKey`, `RecvWindow`, `TimeOffset` and `ParamMode` before sharing it, and create one stream object per connection.

> **Project status:** early-stage, source-first library. It was written against the public Toobit documentation and has **not yet been compiled with Delphi or FreePascal**; only the SHA-256/HMAC algorithm was cross-checked against a reference implementation (Python `hashlib`). Compile it with your own toolchain, run `ToobitSelfTest`, and test with a read-only key or tiny order sizes before trading real funds. Do not treat this release as production-certified.

## Feature overview

| Capability | What it does | Important boundary |
|---|---|---|
| Request signing | HMAC-SHA256 over the exact parameter string, lower-case hex, `signature` always last | Signature is computed over raw (decoded) values; see [Client docs](docs/Toobit4D.Client.md) |
| Clock synchronisation | `SyncTime` stores the server/local offset used for every `timestamp` | Call it again from time to time if the system clock drifts |
| Spot REST | Market data, orders (single, test, batch, cancel), account, balance flow, sub-accounts, transfers, wallet (withdraw / deposit) | Responses are raw JSON text, not typed models |
| Futures REST (USDT-M / USDC-M) | Market data, funding, index/mark price, orders (new, batch, modify, cancel, query), positions, leverage, margin, TP/SL, flash close, reverse | Batch orders send basic fields only; TP/SL attach to single orders |
| Escape hatch | `TToobitClient.Request` calls any endpoint with any security level and optional JSON body | You build parameters and parse the result yourself |
| Market streams | trade, kline, ticker, depth, diffDepth, bookTicker, markPrice, index, all-tickers, all-book-tickers | No local order-book maintenance; you apply diffs yourself |
| User-data streams | Spot and Futures account, order, position and fill events | The stream does not replay events missed while disconnected |
| Heartbeat | Client `{"ping": ...}` frames and automatic `{"pong": ...}` replies | Interval is fixed per stream instance (`PingIntervalMs`) |
| Reconnect | Worker thread reconnects after `ReconnectDelayMs` and re-sends all subscriptions | Fixed delay; no exponential back-off |
| listenKey management | Create, renew every 30 minutes, close on `Stop` | Needs a valid signed REST call at every (re)connect |
| Error model | HTTP 429 -> `EToobitRateLimitError`, 5xx -> `EToobitServerError`, other -> `EToobitHttpError` with code and message | Network-level errors are the HTTP engine's own exceptions |
| Transport abstraction | `TToobitWsTransport` isolates the WebSocket library in one unit | The bundled adapter is written against `WebSocket4D.pas` as supplied by its author; re-check it if you update that library |
| Self-test | `ToobitSelfTest` verifies HMAC-SHA256 against RFC 4231 | Verifies the crypto only, not the network code |

## Repository structure

```
Toobit4D/
|-- src/                              # Shared Delphi/FPC units
|   |-- Toobit4D.inc                  # Compiler settings
|   |-- Toobit4D.pas                  # Facade: TToobit
|   |-- Toobit4D.Types.pas            # Constants, enums, exceptions
|   |-- Toobit4D.Utils.pas            # SHA-256 / HMAC, URL encoding, clocks, parameter list
|   |-- Toobit4D.Json.pas             # JSON helpers (System.JSON / fpjson)
|   |-- Toobit4D.Client.pas           # REST core: signing, headers, errors
|   |-- Toobit4D.Spot.pas             # Spot endpoints
|   |-- Toobit4D.Futures.pas          # Futures endpoints
|   |-- Toobit4D.Stream.pas           # Market and user-data streams
|   |-- Toobit4D.WS.Transport.pas     # Abstract WebSocket transport
|   `-- Toobit4D.WS.WebSocket4D.pas   # WebSocket4D adapter
|-- demo/
|   |-- Delphi/                       # ToobitDemo.dpr, ToobitTester.dpr
|   |-- FreePascal/                   # ToobitDemo.lpr, ToobitTester.lpr (same programs for FPC/Lazarus)
|   `-- README.md                     # Tester menu, keys and safety rules
|-- docs/                             # One document per unit + index
`-- README.md
```

## Requirements

| Component | Requirement |
|---|---|
| Delphi | A version that ships `System.JSON`, `System.DateUtils` and `TBytes` (XE7 or later recommended) |
| FreePascal | 3.0 or later, compiled in Delphi mode (`-Mdelphi`); 3.2 recommended |
| REST | [RESTRequest4Delphi](https://github.com/viniciussanchez/RESTRequest4Delphi) (any of its engines; under FPC the default is `fphttpclient`, and HTTPS needs the OpenSSL libraries next to the executable) |
| WebSocket | [WebSocket4D](https://github.com/DelphiMan68/WebSocket4D) (Windows 8 or later) or your own `TToobitWsTransport` descendant |
| Platform | REST works wherever RESTRequest4Delphi works. The WebSocket streams, as shipped, are Windows only. |

## Installation

1. Clone or download the three projects.
2. Add these folders to the project search path:
   - `Toobit4D/src`
   - `RESTRequest4Delphi/src`
   - `WebSocket4D/Source`
3. **WebSocket adapter:** `src/Toobit4D.WS.WebSocket4D.pas` maps `TWebSocket4DClient` (`OnConnect`, `OnDisconnect`, `OnTextMessage`, `OnError`) onto `TToobitWsTransport`. If you only need REST, you can leave the adapter out of the project and never use `Toobit4D.Stream`. If you use another WebSocket library, derive from `TToobitWsTransport` instead (see [Transport docs](docs/Toobit4D.WS.Transport.md)).
4. Add the units you need to your `uses` clause. Pascal does not re-export units, so `uses Toobit4D;` alone only gives you `TToobit`; add `Toobit4D.Types` (constants, exceptions), `Toobit4D.Spot` / `Toobit4D.Futures` (order records and helpers such as `SpotOrder`, `FuturesLimitOrder`), `Toobit4D.Utils` (`ToobitSelfTest`, `NewParams`), `Toobit4D.Json` (`JsonField`), `Toobit4D.Client` and `Toobit4D.Stream` as required.

Free Pascal command line:

```
fpc -Mdelphi -Fu./src -Fu<RESTRequest4Delphi>/src -Fu<WebSocket4D>/Source ./demo/FreePascal/ToobitDemo.lpr
```

## Quick start

### Public market data (no keys)

```pascal
uses
  SysUtils,
  Toobit4D, Toobit4D.Types, Toobit4D.Utils, Toobit4D.Spot, Toobit4D.Futures;

var
  Toobit: TToobit;
begin
  if not ToobitSelfTest then
    raise Exception.Create('HMAC self-test failed on this compiler');

  Toobit := TToobit.Create;           // keys are optional for public endpoints
  try
    Writeln(Toobit.Spot.TickerPrice('BTCUSDT'));
    Writeln(Toobit.Futures.FundingRate('BTC-SWAP-USDT'));
  finally
    Toobit.Free;
  end;
end.
```

### Signed requests: balances and orders

```pascal
Toobit := TToobit.Create('API_KEY', 'SECRET_KEY');
try
  Toobit.Client.SyncTime;                         // align timestamps with the server

  // Spot: dry-run, then real order
  O := SpotOrder('BTCUSDT', TB_SIDE_BUY, TB_TYPE_LIMIT, '0.001', '60000', TB_TIF_GTC, 'my-order-1');
  Toobit.Spot.TestOrder(O);
  Writeln(Toobit.Spot.NewOrder(O));

  // Futures: leverage, limit order with TP/SL
  Toobit.Futures.ChangeLeverage('BTC-SWAP-USDT', 10);
  F := FuturesLimitOrder('BTC-SWAP-USDT', TB_SIDE_BUY_OPEN, '10', '60000', 'fut-order-1');
  F.TakeProfit := '65000';
  F.StopLoss := '58000';
  Writeln(Toobit.Futures.NewOrder(F));
  Writeln(Toobit.Futures.Positions('BTC-SWAP-USDT'));
finally
  Toobit.Free;
end;
```

### Handling errors

```pascal
try
  Toobit.Futures.NewOrder(F);
except
  on E: EToobitRateLimitError do
    Sleep(2000);                                   // back off, then retry later
  on E: EToobitServerError do
    // HTTP 5xx: the order state is UNKNOWN - query it before retrying
    Writeln(Toobit.Futures.QueryOrder('', F.ClientOrderId));
  on E: EToobitHttpError do
    Writeln(E.StatusCode, ' ', E.ApiCode, ' ', E.ApiMessage);
end;
```

### WebSocket market stream

```pascal
type
  THandler = class
    procedure OnMsg(Sender: TObject; const ATopic, ASymbol, AJson: string);
  end;

procedure THandler.OnMsg(Sender: TObject; const ATopic, ASymbol, AJson: string);
begin
  Writeln(ATopic, ' ', ASymbol, ' ', Copy(AJson, 1, 100));   // runs on a worker thread
end;

var
  MS: TToobitMarketStream;
begin
  MS := Toobit.NewMarketStream;
  try
    MS.OnMessage := Handler.OnMsg;
    MS.Start;
    MS.SubscribeTrades(['BTCUSDT', 'ETHUSDT']);
    MS.SubscribeKline(['BTCUSDT'], TB_INT_1M, 100);
    Readln;
  finally
    MS.Free;                                        // Stop is called automatically
  end;
end;
```

### Private user-data stream

```pascal
US := Toobit.NewUserStream(usFutures);              // or usSpot
US.OnMessage := Handler.OnUserMsg;                  // ATopic: contractExecutionReport, outboundContractPositionInfo, ...
US.Start;                                           // listenKey is created, renewed and closed for you
...
US.Free;
```

## Architecture overview

```
 your code
    |
 TToobit  (facade)
    |-- Client  : TToobitClient   -- sign + send -> RESTRequest4Delphi -> Toobit REST
    |-- Spot    : TToobitSpotApi    ---+
    |-- Futures : TToobitFuturesApi ---+--> Client.Request(method, path, params, security, body)
    |
    '-- streams : TToobitMarketStream / TToobitUserStream
                       |-- worker thread: connect -> resubscribe -> ping / keep-alive -> reconnect
                       '-- TToobitWsTransport  --(adapter)--> WebSocket4D
```

Every REST call, including your own, ends in `TToobitClient.Request`, which:

1. adds `timestamp` and `recvWindow` for signed endpoints,
2. signs `parameters + optional JSON body` with HMAC-SHA256 and appends `signature` last,
3. sends the request with the `X-BB-APIKEY` header,
4. returns the response text, or raises a typed exception for non-2xx statuses.

## API coverage

### Spot

| Area | Methods |
|---|---|
| Market data | `ServerTime`, `ExchangeInfo`, `Depth`, `MergedDepth`, `Trades`, `Klines`, `Ticker24h`, `TickerPrice`, `BookTicker` |
| Trading | `TestOrder`, `NewOrder`, `BatchOrders`, `CancelOrder`, `CancelAllOpenOrders`, `CancelOrdersByIds` |
| Account | `QueryOrder`, `OpenOrders`, `AllOrders`, `Account`, `AccountTrades`, `SubAccounts`, `BalanceFlow`, `CheckApiKey`, `Transfer` |
| Wallet | `Withdraw`, `WithdrawOrders`, `DepositAddress`, `DepositOrders` |
| User stream | `CreateListenKey`, `KeepAliveListenKey`, `CloseListenKey` |

### Futures (USDT-M / USDC-M, API v1)

| Area | Methods |
|---|---|
| Market data | `Depth`, `MergedDepth`, `Trades`, `Klines`, `IndexKlines`, `IndexPriceComponents`, `MarkPriceKlines`, `MarkPrice`, `FundingRate`, `FundingRateHistory`, `OpenInterest`, `LongShortRatio`, `InsuranceFund`, `RiskLimits`, `Ticker24h`, `TickerPrice`, `IndexPrice`, `BookTicker` |
| Account settings | `ChangeMarginType`, `ChangeLeverage`, `AccountLeverage`, `Balance`, `BalanceFlow`, `CommissionRate`, `TodayPnl`, `SubAccounts` |
| Orders | `NewOrder`, `BatchOrders`, `QueryOrder`, `ModifyOrder`, `CancelOrder`, `CancelOpenOrdersBySide`, `CancelOrdersByIds`, `OpenOrders`, `HistoryOrders`, `UserTrades` |
| Positions | `Positions`, `HistoryPositions`, `SetTradingStop`, `AutoAddMargin`, `PositionMargin`, `FlashClose`, `ReversePosition` |
| Files | `DownloadApply`, `DownloadDetail` |
| User stream | `CreateListenKey`, `KeepAliveListenKey`, `CloseListenKey` |

### WebSocket

| Stream | Topics / events |
|---|---|
| `TToobitMarketStream` | `trade`, `kline_<interval>`, `realtimes`, `depth`, `diffDepth`, `bookTicker`, `markPrice`, `index`, `wholeRealTime`, `wholeBookTicker` |
| `TToobitUserStream` (Spot) | `outboundAccountInfo`, `executionReport`, `ticketInfo` |
| `TToobitUserStream` (Futures) | `outboundContractAccountInfo`, `outboundContractPositionInfo`, `contractExecutionReport`, `planExecutionReport`, `ticketInfo`, `listenKeyWillExpire` |

Full parameter tables and notes for every method are in [`docs/`](docs/README.md).

## API summary

### `TToobit`
- `Create(ApiKey, SecretKey)`: keys optional.
- `Client`, `Spot`, `Futures`: the three sub-objects (owned by `TToobit`).
- `NewMarketStream`, `NewUserStream(Kind)`: create streams; **you own and free them**, before freeing `TToobit`.

### `TToobitClient`
- `ApiKey`, `SecretKey`, `BaseUrl`: credentials and endpoint.
- `RecvWindow` (default 5000 ms, max 60000), `TimeOffset`, `ParamMode` (`pmAddParam` / `pmInUrl`).
- `SyncTime`: measures and stores the server clock offset.
- `Request(Method, Path, Params, Security, BodyJson)`: the low-level gateway.

### `TToobitFuturesApi.Category`
`''` selects USDT-M (default); `TB_CATEGORY_USDC` selects USDC-M for every call that accepts `category`.

### Parameter conventions
- Empty string `''` means "do not send"; for optional numeric parameters `0` means "do not send" (`-1` for `scale`).
- Order ids are `string` (they are 19-digit values).
- Futures v1 orders use the combined `side` values `BUY_OPEN`, `SELL_OPEN`, `BUY_CLOSE`, `SELL_CLOSE`.
- A futures market order is `LIMIT` + `priceType=MARKET`; a spot market BUY takes the amount in the **quote** asset.

## Signing and timing semantics - read before use

- **Signature input:** `name=value&name=value` in the exact order the parameters are sent, plus the raw JSON body for JSON endpoints (no `&` between them). `signature` is never part of the signed text and is always the last parameter.
- **`timestamp` / `recvWindow`:** a signed request is rejected if it is more than `recvWindow` ms old or more than 1 s in the server's future. Call `SyncTime` after start-up and keep `RecvWindow` small.
- **Parameter transport:** by default parameters are handed to RESTRequest4Delphi through `AddParam`. If your HTTP engine reorders or re-encodes parameters and signatures are rejected, set `Client.ParamMode := pmInUrl`. JSON-body calls always put parameters in the URL.
- **Encoding assumption:** the signature is computed over the raw (not percent-encoded) values, matching the example in the Toobit docs that signs a phone number containing a space. This is the single assumption most worth verifying against the live API.
- **Rate limits:** the documented limits are 3000 request weight per minute and 60 order requests per 2 seconds. Toobit4D does not throttle; after HTTP 429 you must back off. Repeated failing requests (e.g. HTTP 404/429) can lead to a temporary IP ban.

## Production safety notes

- **HTTP 5xx means "unknown", not "failed".** Per the Toobit docs the request may have been executed. `EToobitServerError` exists to remind you: query the order or position (use a unique `newClientOrderId`) before retrying a trade.
- Never retry order creation blindly; always attach a unique client order id so duplicates can be detected.
- Create API keys with the minimum permissions required, enable the IP restriction on the exchange, and never commit keys to source control or write them to logs.
- Withdrawals move real funds; do not give a trading bot's key withdrawal permission unless you need it.
- Stream events are raised on a worker thread. Synchronise before touching VCL/LCL controls, and keep handlers short; a slow handler delays that stream's message processing.
- A user stream does not replay events missed during a disconnect. After `OnConnected`, read `OpenOrders` / `Positions` over REST once to reconcile.
- Streams are not connection pools: use one market stream for all symbols rather than many sockets.
- Test on small sizes first; the library has not been verified against the live exchange.

## Known limitations

- Responses are raw JSON strings; there are no typed response models yet.
- Wrappers cover the v1 endpoints listed above. The v2 endpoints (user API v2, spot/futures account v2, JSON-body futures v2), copy-trading (leader / follower) and affiliate endpoints are **not** wrapped; call them through `Client.Request`.
- `Futures.BatchOrders` sends basic order fields only; `ModifyOrder` covers LIMIT and STOP basics (build trailing-stop modifications with `Client.Request`).
- No built-in rate limiter or retry policy, and response headers (such as `X-Api-Limit-Reset-Timestamp`) are not exposed.
- The WebSocket reconnect delay is fixed, and no local order book is maintained for `depth` / `diffDepth`.
- The bundled WebSocket adapter targets WebSocket4D, whose client is WinHTTP based, and has not been compiled or run against the live stream yet.
- ASCII parameters are assumed on FPC (strings are signed byte-for-byte).

## Compatibility

The units share one source tree between modern Delphi and FreePascal in Delphi mode and have no third-party dependencies apart from the two libraries named above. Actual compatibility depends on compiler version, RTL and target platform. Compile the demo and run `ToobitSelfTest` with the exact toolchains you plan to support, and report any compiler-specific issues.

## Documentation

| Document | Contents |
|---|---|
| [docs/README.md](docs/README.md) | Index, installation, shared conventions |
| [docs/Toobit4D.md](docs/Toobit4D.md) | `TToobit` facade |
| [docs/Toobit4D.Types.md](docs/Toobit4D.Types.md) | Constants, enums, exception hierarchy |
| [docs/Toobit4D.Utils.md](docs/Toobit4D.Utils.md) | SHA-256 / HMAC, parameter list, clocks |
| [docs/Toobit4D.Json.md](docs/Toobit4D.Json.md) | JSON helpers |
| [docs/Toobit4D.Client.md](docs/Toobit4D.Client.md) | Signing, `Request`, error mapping |
| [docs/Toobit4D.Spot.md](docs/Toobit4D.Spot.md) | Every Spot method |
| [docs/Toobit4D.Futures.md](docs/Toobit4D.Futures.md) | Every Futures method |
| [docs/Toobit4D.Stream.md](docs/Toobit4D.Stream.md) | Market and user streams, event tables |
| [docs/Toobit4D.WS.Transport.md](docs/Toobit4D.WS.Transport.md) | Writing a custom transport |
| [docs/Toobit4D.WS.WebSocket4D.md](docs/Toobit4D.WS.WebSocket4D.md) | How the WebSocket4D adapter works |

Upstream API reference: <https://api-docs.toobit.com>.

