# Toobit4D.Client

REST core: building requests, signing, the API-key header, and mapping errors to exceptions. All Spot and Futures wrappers and the streams go through `Request`. HTTP is performed by RESTRequest4Delphi (`TRequest.New ... IRequest/IResponse`).

## TToobitClient

```pascal
constructor Create(const AApiKey: string = ''; const ASecretKey: string = '');

function Request(AMethod: TToobitHttpMethod; const APath: string;
  AParams: IToobitParams = nil; ASecurity: TToobitSecurity = tsNone;
  const ABodyJson: string = ''): string;

function NowMs: Int64;
function SyncTime: Int64;
```

### Properties

| Property | Default | Description |
|---|---|---|
| `ApiKey`, `SecretKey` | from constructor | Sensitive; do not log them. Both are case sensitive. |
| `BaseUrl` | `https://api.toobit.com` | |
| `RecvWindow` | `5000` | Milliseconds; the documented maximum is 60000. A small value (5000 or less) is recommended. |
| `TimeOffset` | `0` | Difference between server and local clock in milliseconds. `SyncTime` fills it in. |
| `ParamMode` | `pmAddParam` | How parameters are handed to the HTTP engine (see below). |

### Request

The single gateway for all endpoints. It returns the JSON text of the response body.

| Parameter | Description |
|---|---|
| `AMethod` | `hmGet/hmPost/hmPut/hmDelete` |
| `APath` | e.g. `/api/v1/futures/order` |
| `AParams` | Parameter list; `nil` = empty |
| `ASecurity` | `tsNone/tsApiKey/tsSigned` |
| `ABodyJson` | Compact JSON body (no newlines); only for JSON endpoints such as `batchOrders` |

**Internal steps for `tsSigned`:**

1. If the API key or secret is empty: `EToobitError`.
2. If `timestamp` is missing it is set to `NowMs`; if `recvWindow` is missing it is set to `RecvWindow`.
3. String to sign = `AParams.ToRaw + ABodyJson` (no separator).
4. `signature = HMAC-SHA256(secret, string to sign)` as lower-case hex, added as the **last** parameter.
5. Sending: if `ParamMode = pmInUrl` or a JSON body is present, the encoded query string goes into the URL; otherwise parameters are added with `AddParam` in order.
6. Headers: `X-BB-APIKEY` for `tsApiKey` and `tsSigned`, plus `Accept: application/json`.
7. POST without a JSON body uses `application/x-www-form-urlencoded`; with a body it uses `application/json`.
8. A non-2xx status is turned into an exception (table below).

**Error mapping:**

| HTTP | Exception |
|---|---|
| 429 | `EToobitRateLimitError` |
| 500 and above | `EToobitServerError` (execution status unknown) |
| other non-2xx | `EToobitHttpError` (with `ApiCode` and `ApiMessage` from the JSON) |

Network errors (connection lost, etc.) are the HTTP engine's own exceptions and pass through unchanged.

> Assumption: the signature is computed over the **decoded** values (raw `k=v`), as in the phone-number example of the Toobit docs, which is signed with a plain space. If you get signature errors on parameters containing special characters, change `ParamMode` or report it.

### NowMs
`ToobitUtcNowMs + TimeOffset`; the value used for `timestamp`.

### SyncTime
Calls `GET /api/v1/time`, assumes the server stamped the reply half-way through the round trip, stores the result in `TimeOffset` and returns it. If your system clock drifts, call it before signed requests and repeat every few hours. Raises `EToobitError` if the response has no `serverTime`.

## ParamMode

- `pmAddParam`: the normal RESTRequest4Delphi path. GET parameters go in the query, POST parameters are sent as a form.
- `pmInUrl`: everything goes in the URL. Try this if the HTTP engine changes parameter order or encoding and signatures are rejected.

## Example: an endpoint without a wrapper

```pascal
// API v2: GET /api/v2/account/balance-flow
Resp := Toobit.Client.Request(hmGet, '/api/v2/account/balance-flow',
  NewParams.Add('accountType', 'FUTURES').Add('limit', 50), tsSigned);
```

> Signed JSON-body endpoints (such as `/api/v2/futures/batch-orders`) are also possible through `ABodyJson`; the body must be exactly the signed string and contain no newlines.
