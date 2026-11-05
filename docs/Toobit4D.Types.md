# Toobit4D.Types

Constants, enumerated types and exceptions. Depends only on `SysUtils`.

## URLs

| Constant | Value |
|---|---|
| `TOOBIT_REST_URL` | `https://api.toobit.com` |
| `TOOBIT_WS_HOST` | `wss://stream.toobit.com` |
| `TOOBIT_WS_MARKET_URL` | `wss://stream.toobit.com/quote/ws/v1` |
| `TOOBIT_WS_USER_URL` | `wss://stream.toobit.com/api/v1/ws/` (+ listenKey) |

## Order side (`side`)

| Constant | Value | Use |
|---|---|---|
| `TB_SIDE_BUY` / `TB_SIDE_SELL` | `BUY` / `SELL` | Spot; cancelling futures orders by side |
| `TB_SIDE_BUY_OPEN` | `BUY_OPEN` | Futures v1: open long |
| `TB_SIDE_SELL_OPEN` | `SELL_OPEN` | Futures v1: open short |
| `TB_SIDE_BUY_CLOSE` | `BUY_CLOSE` | Futures v1: close short |
| `TB_SIDE_SELL_CLOSE` | `SELL_CLOSE` | Futures v1: close long |

## Order type (`type`)

| Constant | Value | Notes |
|---|---|---|
| `TB_TYPE_LIMIT` | `LIMIT` | Limit order |
| `TB_TYPE_MARKET` | `MARKET` | Spot only. On futures a market order is `LIMIT` + `priceType=MARKET` |
| `TB_TYPE_LIMIT_MAKER` | `LIMIT_MAKER` | Spot, maker only |
| `TB_TYPE_STOP` | `STOP` | Futures conditional (plan) order |

## Other constants

| Group | Constants |
|---|---|
| Time in force | `TB_TIF_GTC`, `TB_TIF_IOC`, `TB_TIF_FOK`, `TB_TIF_POST_ONLY` |
| Futures price type | `TB_PRICE_INPUT` (price you entered), `TB_PRICE_MARKET` (last price +/-5%) |
| Margin type | `TB_MARGIN_CROSS`, `TB_MARGIN_ISOLATED` |
| Position side | `TB_POS_LONG`, `TB_POS_SHORT` |
| Trigger source | `TB_TRIGGER_MARK` (`MARK_PRICE`), `TB_TRIGGER_LAST` (`CONTRACT_PRICE`) |
| Futures category | `TB_CATEGORY_USDC` (`USDC`; empty = USDT-M) |
| Account type (transfer) | `TB_ACC_MAIN`, `TB_ACC_FUTURES`, `TB_ACC_FUTURES_USDC`, `TB_ACC_COPY_TRADING` |
| Kline interval | `TB_INT_1M`, `3M`, `5M`, `15M`, `30M`, `1H`, `2H`, `4H`, `6H`, `8H`, `12H`, `1D`, `1W`, `TB_INT_1MO` (= `1M`, monthly) |

> The intervals accepted by the WebSocket kline stream are a little narrower than for REST (`3m` and `8h` are not listed for streams).

## Types

### `TToobitHttpMethod`
`hmGet, hmPost, hmPut, hmDelete`

### `TToobitSecurity`
| Value | Meaning |
|---|---|
| `tsNone` | Public endpoint |
| `tsApiKey` | `X-BB-APIKEY` header only (MARKET_DATA / USER_STREAM) |
| `tsSigned` | Header + `timestamp` + `recvWindow` + `signature` (TRADE / USER_DATA) |

### `TToobitParamMode`
How parameters are handed to RESTRequest4Delphi.

| Value | Behaviour |
|---|---|
| `pmAddParam` (default) | `request.AddParam(name, value)` in order |
| `pmInUrl` | Toobit4D builds the whole query string and appends it to the URL |

Requests that carry a JSON body always use `pmInUrl`.

## Exceptions

```
Exception
`- EToobitError                  generic library error (missing key, invalid argument, ...)
   |- EToobitHttpError           non-2xx HTTP response
   |  |- EToobitRateLimitError   HTTP 429
   |  `- EToobitServerError      HTTP 5xx
   `- EToobitWsError             WebSocket error (e.g. no listenKey obtained)
```

### `EToobitHttpError`
| Field | Description |
|---|---|
| `StatusCode: Integer` | HTTP status code |
| `ApiCode: string` | The `code` field of the error JSON, if present |
| `ApiMessage: string` | The `msg` field of the error JSON, if present |
| `Content: string` | Raw response body |

### `EToobitRateLimitError`
After a 429, reduce the request rate immediately. According to the Toobit docs the next allowed time is in the `X-Api-Limit-Reset-Timestamp` response header; this library does not expose response headers, so use a sensible back-off. Repeated 404/429 errors may lead to a temporary IP ban.

### `EToobitServerError`
Per the Toobit docs, after a 5xx the execution status is **unknown** and the request may have succeeded. Query the order/position before sending it again (use a unique `newClientOrderId`).

```pascal
try
  Toobit.Futures.NewOrder(O);
except
  on E: EToobitServerError do
    Toobit.Futures.QueryOrder('', O.ClientOrderId);   // was the order placed?
  on E: EToobitHttpError do
    Writeln(E.StatusCode, ' ', E.ApiCode, ' ', E.ApiMessage);
end;
```
