# Toobit4D.Stream

WebSocket streams: market data (public) and user data (private). Features:

- Automatic reconnect after a delay (`ReconnectDelayMs`, default 3 s) and **automatic re-subscription**
- Client heartbeat `{"ping": <ms>}` every `PingIntervalMs` (default 20 s). The server keeps a silent client for about 5 minutes.
- Automatic `{"pong":...}` reply if the server sends `{"ping":...}`; ping/pong frames are not delivered to `OnMessage`.
- User stream: creates the listenKey, renews it every 30 minutes, closes it on `Stop`

> **Threading:** events are raised on a library worker thread (or on the transport's receive thread). Synchronise (`TThread.Queue` / `Synchronize`) before touching VCL/LCL controls.

## Event types

```pascal
TToobitStreamMessageEvent = procedure(Sender: TObject; const ATopic, ASymbol, AJson: string) of object;
TToobitStreamNotifyEvent  = procedure(Sender: TObject) of object;
TToobitStreamErrorEvent   = procedure(Sender: TObject; const AMessage: string) of object;
```

`ATopic`: for the market stream the topic name (`trade`, `kline`, `realtimes`, `depth`, `diffDepth`, `markPrice`, `bookTicker`, `wholeRealTime`, `wholeBookTicker`, `index`); for the user stream the event type (`e` or `eventType`). `ASymbol` may be empty. `AJson` is the unmodified received frame.

## TToobitStreamBase (shared base)

```pascal
constructor Create(ATransport: TToobitWsTransport = nil);
procedure Start;
procedure Stop;
property Active, Connected: Boolean;           // read-only
property PingIntervalMs, ReconnectDelayMs: Integer;
property OnMessage, OnConnected, OnDisconnected, OnError;
```

| Member | Description |
|---|---|
| `Create(nil)` | Creates the default WebSocket4D transport and **owns** it. A transport you pass in is not freed by the stream. |
| `Start` | Starts the worker thread: connect -> resubscribe -> ping/keep-alive loop -> on disconnect, wait and start over. Calling it more than once has no effect. |
| `Stop` | Stops the thread, disconnects the transport and runs `Cleanup` (for the user stream: closes the listenKey). `Destroy` calls `Stop` itself. If the transport's `Connect` blocks, `Stop` waits until it returns. |
| `Active` | The worker thread is running. |
| `Connected` | The socket is open. |
| `OnConnected` | After every successful connection, before re-subscribing. |
| `OnDisconnected` | When an open connection was lost. |
| `OnError` | Transport errors, connection timeout (15 s), listenKey failure, keep-alive failure. |

Note: `Subscribe*` methods can be called before or after `Start`; before a connection exists they are only recorded and sent after connecting.

## TToobitMarketStream

Default URL: `wss://stream.toobit.com/quote/ws/v1` (changeable through `Url`).

```pascal
procedure Subscribe(const ATopic: string; const ASymbols: array of string; ALimit: Integer = 0);
procedure Unsubscribe(const ATopic: string; const ASymbols: array of string);
```
Generic form: `ATopic` is any topic from the docs (e.g. `kline_5m`). Several symbols are joined with commas into one message. `ALimit` applies to klines only (number of historical candles, max 2000; the server default is 1).

| Method | Topic | Market |
|---|---|---|
| `SubscribeTrades(Symbols)` | `trade` | both |
| `SubscribeKline(Symbols, Interval, Limit=0)` | `kline_<interval>` | both |
| `SubscribeTicker(Symbols)` | `realtimes` | both (24h ticker, every second) |
| `SubscribeDepth(Symbols)` | `depth` | both (snapshot every 300 ms) |
| `SubscribeDiffDepth(Symbols)` | `diffDepth` | both (quantity `0` removes that level) |
| `SubscribeBookTicker(Symbols)` | `bookTicker` | futures |
| `SubscribeMarkPrice(Symbols)` | `markPrice` | futures |
| `SubscribeIndex(Symbols)` | `index` | futures (e.g. `BTCUSDT`) |
| `SubscribeAllTickers` | `wholeRealTime` | futures, all symbols |
| `SubscribeAllBookTickers` | `wholeBookTicker` | futures, all symbols |

Subscriptions are stored under the key `topic|symbols`; repeating the same key replaces it. `Unsubscribe` removes the entry and sends `cancel`; call it with the same symbol combination that was used to subscribe.

Data frames carry `"f": true` on the first push (initial snapshot). For `trade`, the server first sends the 60 most recent trades.

### Example

```pascal
procedure THandler.OnMsg(Sender: TObject; const ATopic, ASymbol, AJson: string);
begin
  if ATopic = 'trade' then ... else if ATopic = 'kline' then ...
end;

MS := Toobit.NewMarketStream;
MS.OnMessage := H.OnMsg;
MS.Start;
MS.SubscribeTrades(['BTCUSDT', 'ETHUSDT']);
MS.SubscribeKline(['BTCUSDT'], TB_INT_1M, 100);
...
MS.Free;
```

## TToobitUserStream

```pascal
constructor Create(AClient: TToobitClient; AKind: TToobitUserStreamKind; ATransport: TToobitWsTransport = nil);
property Category: string;      // futures: '' = USDT-M, 'USDC' = USDC-M
property ListenKey: string;     // read-only
```
`TToobitUserStreamKind`: `usSpot`, `usFutures`.

**Lifecycle:** on every connection (including each reconnect) a listenKey is obtained (`POST /api/v1/userDataStream` or `/api/v1/listenKey`), the stream connects to `wss://stream.toobit.com/api/v1/ws/<listenKey>`, the key is renewed with `PUT` every 30 minutes, and closed with `DELETE` in `Stop`. No manual subscription is needed; all account events arrive automatically. If no listenKey can be obtained, `EToobitWsError` is reported through `OnError` and the attempt is repeated.

### User events (value of `ATopic`)

| ATopic | Market | Content |
|---|---|---|
| `outboundAccountInfo` | Spot | Balance change: array `B` with `a` (asset), `f` (free), `l` (locked) |
| `executionReport` | Spot | Order update (`X` status, `i` order id, `z` cumulative filled quantity, `Z` cumulative quote value; average price = `Z/z`) |
| `ticketInfo` | both | A fill (trade) |
| `outboundContractAccountInfo` | Futures | Balance |
| `outboundContractPositionInfo` | Futures | Position (`s` symbol, `S` side, `p` average entry price, `f` liquidation price, `up` unrealised PnL, `v` leverage) |
| `contractExecutionReport` | Futures | Order (`mt` margin type, `rp` cumulative realised PnL of a closing order) |
| `planExecutionReport` | Futures | Conditional / TP / SL orders (`planOrderType`, `status`, `triggerPrice`) |
| `listenKeyWillExpire` | Futures | Expiry warning, sent every minute from 5 minutes before expiry. The library renews automatically. |

Messages can arrive out of order; per the docs, order them by the event-time field `E`. Spot and futures payloads are JSON arrays, except `planExecutionReport` and `listenKeyWillExpire`, which are objects.

### Example

```pascal
US := Toobit.NewUserStream(usFutures);
US.OnMessage := H.OnUserMsg;
US.OnError := H.OnErr;
US.Start;
// ... application runs
US.Free;   // closes the listenKey
```

## Recommended usage patterns

- Use one `TToobitMarketStream` for all market data (instead of many connections).
- For a trading bot, take order state from the user stream and use the REST `Query*` calls only to reconcile after a disconnect or a 5xx.
- After `OnConnected` on the user stream, read `OpenOrders` / `Positions` once over REST to recover events missed while disconnected (the stream does not replay past events).
