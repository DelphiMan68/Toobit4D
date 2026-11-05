# Toobit4D.Spot

Spot wrappers. Class `TToobitSpotApi` (available as `TToobit.Spot`). All methods return the raw JSON text. Conventions: `''` and `0` mean "do not send" (`-1` for `scale`).

## Types and helper functions

### `TToobitSpotOrder` (record)

| Field | Description |
|---|---|
| `Symbol` | e.g. `BTCUSDT` |
| `Side` | `TB_SIDE_BUY` / `TB_SIDE_SELL` |
| `OrderType` | `TB_TYPE_LIMIT` / `TB_TYPE_MARKET` / `TB_TYPE_LIMIT_MAKER` |
| `TimeInForce` | Optional |
| `Quantity` | Amount. **MARKET BUY: the amount in the quote asset** (e.g. USDT) |
| `Price` | For LIMIT and LIMIT_MAKER |
| `ClientOrderId` | Unique among open orders; mandatory for batch orders |

### `SpotOrder(...)`
```pascal
function SpotOrder(const ASymbol, ASide, AType, AQuantity: string; const APrice: string = '';
  const ATimeInForce: string = ''; const AClientOrderId: string = ''): TToobitSpotOrder;
```
Quick constructor for the record.

## Market data (public)

| Method | HTTP / path | Parameters / notes |
|---|---|---|
| `ServerTime` | GET `/api/v1/time` | |
| `ExchangeInfo` | GET `/api/v1/exchangeInfo` | Trading rules and symbols (`rateLimits` will be removed by Toobit in future) |
| `Depth(Symbol, Limit=0)` | GET `/quote/v1/depth` | Server default is 100; do not send `limit=0` (huge response) |
| `MergedDepth(Symbol, Scale=-1, Limit=0)` | GET `/quote/v1/depth/merged` | `scale` in 0..5 |
| `Trades(Symbol, Limit=0)` | GET `/quote/v1/trades` | Max 60 |
| `Klines(Symbol, Interval, StartTime=0, EndTime=0, Limit=0)` | GET `/quote/v1/klines` | Max 1000; without times only the latest candle is returned |
| `Ticker24h(Symbol='')` | GET `/quote/v1/ticker/24hr` | Weight 1 with a symbol, 40 without |
| `TickerPrice(Symbol='')` | GET `/quote/v1/ticker/price` | Without symbol: all symbols |
| `BookTicker(Symbol='')` | GET `/quote/v1/ticker/bookTicker` | |

## Trading (TRADE, signed)

| Method | HTTP / path | Notes |
|---|---|---|
| `TestOrder(Order)` | POST `/api/v1/spot/orderTest` | Validation only; the order does not reach the matching engine |
| `NewOrder(Order)` | POST `/api/v1/spot/order` | |
| `BatchOrders(Orders)` | POST `/api/v1/spot/batchOrders` | JSON body; 1 to 20 orders, one symbol, `ClientOrderId` required. In the response `code=0` only means the request was executed; the per-order result is in `result[]`. |
| `CancelOrder(OrderId, ClientOrderId='')` | DELETE `/api/v1/spot/order` | One of the two ids is required |
| `CancelAllOpenOrders(Symbol='', Side='')` | DELETE `/api/v1/spot/openOrders` | Weight 5 |
| `CancelOrdersByIds(Ids)` | DELETE `/api/v1/spot/cancelOrderByIds` | 1 to 100 ids; an empty `result` means all succeeded |

Order rate limit: 60 order requests per 2 seconds.

## Account and orders (USER_DATA)

| Method | HTTP / path |
|---|---|
| `QueryOrder(OrderId, OrigClientOrderId='')` | GET `/api/v1/spot/order` |
| `OpenOrders(Symbol='', OrderId='', Limit=0)` | GET `/api/v1/spot/openOrders` (all symbols when empty; max 1000) |
| `AllOrders(Symbol='', OrderId='', StartTime, EndTime, Limit)` | GET `/api/v1/spot/tradeOrders` (default: last 3 days) |
| `Account` | GET `/api/v1/account` (balances: `coin, total, free, locked`) |
| `AccountTrades(Symbol, StartTime, EndTime, FromId, ToId, Limit)` | GET `/api/v1/account/trades` (`Symbol` required) |
| `SubAccounts` | GET `/api/v1/account/subAccount` |
| `BalanceFlow(AccountType, Coin, FlowType, StartTime, EndTime, Limit)` | GET `/api/v1/account/balanceFlow` (`AccountType`: 1 spot, 3 contract; `FlowType` 51 = transfer) |
| `CheckApiKey` | GET `/api/v1/account/checkApiKey` (`master` / `spot` / `contract`) |
| `Transfer(FromUid, ToUid, FromAccountType, ToAccountType, Coin, Quantity, TransferId='')` | POST `/api/v1/subAccount/transfer`. Account types: `TB_ACC_*`. Reusing the same `TransferId` prevents duplicate transfers. The same endpoint moves funds between Spot and Futures. |

## Wallet (USER_DATA)

| Method | HTTP / path | Notes |
|---|---|---|
| `Withdraw(Coin, ClientOrderId, Address, Quantity, ChainType='', AddressExt='', AddressType='')` | POST `/api/v1/account/withdraw` | The address must already be in the account's address list. `AddressType`: `BLOCK_CHAIN` (default), `PHONE_NUMBER`, `EMAIL`, `UID` (the last three are internal transfers). `ChainType` defaults to `OMNI` for USDT. |
| `WithdrawOrders(Coin='', StartTime, EndTime, Limit)` | GET `/api/v1/account/withdrawOrders` | |
| `DepositAddress(Coin, ChainType)` | GET `/api/v1/account/deposit/address` | Both parameters required |
| `DepositOrders(Coin='', StartTime, EndTime, Limit)` | GET `/api/v1/account/depositOrders` | |

> Withdrawals move real funds. Create API keys with only the permissions you need and set an IP restriction.

## User data stream listenKey

| Method | HTTP / path |
|---|---|
| `CreateListenKey: string` | POST `/api/v1/userDataStream` (returns the listenKey itself) |
| `KeepAliveListenKey(Key)` | PUT `/api/v1/userDataStream` |
| `CloseListenKey(Key)` | DELETE `/api/v1/userDataStream` |

A listenKey is valid for 60 minutes. You normally do not call these directly; `TToobitUserStream` does it for you. According to the Toobit docs these endpoints require `timestamp`, so they are sent signed.

## Example

```pascal
O := SpotOrder('BTCUSDT', TB_SIDE_BUY, TB_TYPE_LIMIT, '0.001', '60000', TB_TIF_GTC, 'my-1');
Toobit.Spot.TestOrder(O);          // dry run first
Resp := Toobit.Spot.NewOrder(O);
Toobit.Spot.CancelOrder(JsonField(Resp, 'orderId'));

// market buy worth 50 USDT
Toobit.Spot.NewOrder(SpotOrder('BTCUSDT', TB_SIDE_BUY, TB_TYPE_MARKET, '50'));
```
