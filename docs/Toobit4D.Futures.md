# Toobit4D.Futures

Futures wrappers (API v1) for USDT-M and USDC-M. Class `TToobitFuturesApi` (available as `TToobit.Futures`). Symbols look like `BTC-SWAP-USDT`. Conventions: `''` and `0` mean "do not send".

## Category

```pascal
property Category: string;   // '' = USDT-M (default), TB_CATEGORY_USDC = USDC-M
```
Added automatically to every endpoint that has a `category` parameter. For USDC-M the symbols also end in `USDC` (e.g. `BTC-SWAP-USDC`).

## TToobitFuturesOrder (record)

| Field | Description |
|---|---|
| `Symbol` | e.g. `BTC-SWAP-USDT` |
| `Side` | `TB_SIDE_BUY_OPEN` / `SELL_OPEN` / `BUY_CLOSE` / `SELL_CLOSE` |
| `OrderType` | `TB_TYPE_LIMIT` or `TB_TYPE_STOP` |
| `Quantity` | Number of contracts |
| `ValueQuantity` | Alternative: order value in USDT (`Quantity` wins if both are set) |
| `Price` | For LIMIT with `PriceType=INPUT` |
| `PriceType` | `TB_PRICE_INPUT` / `TB_PRICE_MARKET` |
| `StopPrice` | Required for `STOP` |
| `TimeInForce` | LIMIT only: GTC/FOK/IOC/POST_ONLY |
| `ClientOrderId` | **Mandatory** (the library raises `EToobitError` without it) |
| `TakeProfit`, `TpTriggerBy`, `TpLimitPrice`, `TpOrderType` | Take profit attached to the order |
| `StopLoss`, `SlTriggerBy`, `SlLimitPrice`, `SlOrderType` | Stop loss attached to the order |

TP/SL fields are sent by `NewOrder` only, not by `BatchOrders`.

### Constructors
```pascal
function FuturesLimitOrder(const ASymbol, ASide, AQuantity, APrice, AClientOrderId: string;
  const ATimeInForce: string = ''): TToobitFuturesOrder;
function FuturesMarketOrder(const ASymbol, ASide, AQuantity, AClientOrderId: string): TToobitFuturesOrder;
```
`FuturesMarketOrder` follows the docs: `type=LIMIT` + `priceType=MARKET` (executed at last price +/-5%).

## Market data (public)

| Method | Path | Notes |
|---|---|---|
| `ServerTime` | GET `/api/v1/time` | |
| `ExchangeInfo` | GET `/api/v1/exchangeInfo` | The `contracts` list holds contract multipliers, risk limits and filters |
| `Depth(Symbol, Limit=0)` | GET `/quote/v1/depth` | Weight: up to 100 -> 1, 500 -> 5, 1000 -> 10 |
| `MergedDepth(Symbol, Scale=-1, Limit=0)` | GET `/quote/v1/depth/merged` | |
| `Trades(Symbol, Limit=0)` | GET `/quote/v1/trades` | Max 60 |
| `Klines(Symbol, Interval, StartTime, EndTime, Limit)` | GET `/quote/v1/klines` | |
| `IndexKlines(Symbol, Interval, From, To, Limit=0)` | GET `/quote/v1/index/klines` | `From/To` required; max 2000 |
| `IndexPriceComponents(Symbol)` | GET `/quote/v1/indexPriceComponents` | e.g. `BTCUSDT` |
| `MarkPriceKlines(Symbol, Interval, From, To, Limit=0)` | GET `/quote/v1/markPrice/klines` | |
| `MarkPrice(Symbol='')` | GET `/quote/v1/markPrice` | One object with a symbol, an array without. Limit: 5 requests per second |
| `FundingRate(Symbol='')` | GET `/api/v1/futures/fundingRate` | |
| `FundingRateHistory(Symbol, FromId=0, EndId=0, Limit=0)` | GET `/api/v1/futures/historyFundingRate` | |
| `OpenInterest(Symbol)` | GET `/quote/v1/openInterest` | |
| `LongShortRatio(Symbol, Period, Limit=0, StartTime=0, EndTime=0)` | GET `/quote/v1/globalLongShortAccountRatio` | `Period`: 5m ... 1d; only the last 30 days are available |
| `InsuranceFund(Symbol)` | GET `/api/v1/futures/insuranceBySymbol` | |
| `RiskLimits(Symbol)` | GET `/api/v1/futures/riskLimits` | |
| `Ticker24h(Symbol='', RealtimeInterval='')` | GET `/quote/v1/contract/ticker/24hr` | `24h`, `1d`, `1d+8`; weight 40 without a symbol |
| `TickerPrice(Symbol='')` | GET `/quote/v1/contract/ticker/price` | |
| `IndexPrice(Symbol='')` | GET `/quote/v1/index` | |
| `BookTicker(Symbol='')` | GET `/quote/v1/contract/ticker/bookTicker` | |

## Account settings (signed)

| Method | HTTP / path |
|---|---|
| `ChangeMarginType(Symbol, MarginType)` | POST `/api/v1/futures/marginType` (`TB_MARGIN_CROSS/ISOLATED`) |
| `ChangeLeverage(Symbol, Leverage)` | POST `/api/v1/futures/leverage` |
| `AccountLeverage(Symbol)` | GET `/api/v1/futures/accountLeverage` |
| `SubAccounts(UserId='', Email='')` | GET `/api/v1/subAccount/list` |
| `Balance` | GET `/api/v1/futures/balance` (`balance, availableBalance, positionMargin, orderMargin, crossUnRealizedPnl, coupon`) |
| `BalanceFlow(Symbol='', FlowType, FromId, EndId, StartTime, EndTime, Limit)` | GET `/api/v1/futures/balanceFlow` (`FlowType`: 10 fee, 32 funding fee, 28 realized PNL, 700 liquidation, 701 ADL) |
| `CommissionRate(Symbol)` | GET `/api/v1/futures/commissionRate` |
| `TodayPnl` | GET `/api/v1/futures/todayPnl` (UTC+0 based) |

Transfers between Spot and Futures are done with `Spot.Transfer` (same endpoint).

## Orders

| Method | HTTP / path | Notes |
|---|---|---|
| `NewOrder(Order)` | POST `/api/v1/futures/order` | `ClientOrderId` is mandatory |
| `BatchOrders(Orders)` | POST `/api/v1/futures/batchOrders` | JSON body, 1 to 10 orders, one symbol; basic fields only (symbol, side, type, price, quantity, valueQuantity, priceType, timeInForce). `code=200` only means the request was executed; per-order results are in `result[]`. |
| `QueryOrder(OrderId, OrigClientOrderId='', Type='')` | GET `/api/v1/futures/order` | Response shape depends on the order kind (LIMIT / STOP / STOP_PROFIT_LOSS) |
| `ModifyOrder(Type, OrderId, OrigClientOrderId, NewClientOrderId, Quantity, Price, PriceType, StopPrice, TriggerBy)` | POST `/api/v1/futures/order/update` | `Type`: `LIMIT` / `STOP` / `STOP_PROFIT_LOSS`. Only orders in `NEW` or `PARTIALLY_FILLED` (for conditional orders `ORDER_NEW`) can be modified. For trailing stops build the call yourself with `Client.Request`. |
| `CancelOrder(OrderId, OrigClientOrderId='', Type='', Symbol='')` | DELETE `/api/v1/futures/order` | |
| `CancelOpenOrdersBySide(Symbol, Side)` | DELETE `/api/v1/futures/batchOrders` | `Side` is `BUY` or `SELL` (not BUY_OPEN) |
| `CancelOrdersByIds(Ids)` | DELETE `/api/v1/futures/cancelOrderByIds` | 1 to 100 ids |
| `OpenOrders(Symbol='', OrderId='', Type='', Limit=0)` | GET `/api/v1/futures/openOrders` | `Type`: `LIMIT` / `STOP` / `STOP_PROFIT_LOSS` |
| `HistoryOrders(Symbol='', OrderId='', Type='', StartTime, EndTime, Limit)` | GET `/api/v1/futures/historyOrders` | Default: last 3 days |
| `UserTrades(Symbol, StartTime, EndTime, Limit, FromId='', ToId='')` | GET `/api/v1/futures/userTrades` | |

## Positions

| Method | HTTP / path | Notes |
|---|---|---|
| `Positions(Symbol='', Side='')` | GET `/api/v1/futures/positions` | `Side`: `LONG` / `SHORT` |
| `HistoryPositions(Symbol, MarginType, FromId, ToId, StartTime, EndTime, Limit)` | GET `/api/v1/futures/historyPositions` | Closed positions only |
| `SetTradingStop(Symbol, Side, TakeProfit, StopLoss, TpTriggerBy, SlTriggerBy, TpSize, SlSize, StopType, ActivePrice, FallbackType, FallbackQuantity)` | POST `/api/v1/futures/position/trading-stop` | Fixed: `TakeProfit` / `StopLoss` (+ sizes, which need the matching price). Trailing: `StopType='TRAILING_STOP'` + `FallbackType` (`RATE`/`PRICE`) + `FallbackQuantity` (> 0); `ActivePrice` optional; empty `SlSize` = whole position |
| `AutoAddMargin(Symbol, Side, Enable, Amount='')` | POST `/api/v1/futures/autoAddMargin` | With `Enable=True` an `Amount` (> 0) is required; not supported in copy-trading mode |
| `PositionMargin(Symbol, Side, Amount)` | POST `/api/v1/futures/positionMargin` | Increase (positive) or decrease (negative) isolated margin |
| `FlashClose(Symbol, Side, ClientOrderId='')` | POST `/api/v1/futures/flashClose` | Cancels the position's open orders first, then closes at market |
| `ReversePosition(Symbol, Side, Quantity='')` | POST `/api/v1/futures/reversePosition` | Empty `Quantity` = whole position; must not exceed the position |

## History files

| Method | HTTP / path | Notes |
|---|---|---|
| `DownloadApply(DownloadType, StartTime=0, EndTime=0, Symbol='')` | POST `/api/v1/account/download/apply` | `ORDER` or `FUNDING`; weight 1000 and a monthly quota shared with the web UI. `category` comes from `Category` (`USDT`/`USDC`). Only one file at a time. |
| `DownloadDetail(Id)` | GET `/api/v1/account/download/detail` | `downloadLink` is valid for 7 days |

## listenKey

| Method | HTTP / path |
|---|---|
| `CreateListenKey: string` | POST `/api/v1/listenKey` (returns the key itself) |
| `KeepAliveListenKey(Key)` | PUT `/api/v1/listenKey` |
| `CloseListenKey(Key)` | DELETE `/api/v1/listenKey` |

## Example

```pascal
F := Toobit.Futures;
F.ChangeMarginType('BTC-SWAP-USDT', TB_MARGIN_ISOLATED);
F.ChangeLeverage('BTC-SWAP-USDT', 10);

O := FuturesLimitOrder('BTC-SWAP-USDT', TB_SIDE_BUY_OPEN, '10', '60000',
  'ord-' + IntToStr(Toobit.Client.NowMs));
O.TakeProfit := '65000';
O.StopLoss   := '58000';
Writeln(F.NewOrder(O));

Writeln(F.Positions('BTC-SWAP-USDT'));
F.FlashClose('BTC-SWAP-USDT', TB_POS_LONG);
```
