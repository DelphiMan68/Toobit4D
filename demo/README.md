# Toobit4D demos

The same two programs are provided for each compiler, in separate folders:

| Folder | Compiler | Programs |
|---|---|---|
| [`Delphi/`](Delphi/README.md) | Delphi | `ToobitDemo.dpr`, `ToobitTester.dpr` |
| [`FreePascal/`](FreePascal/README.md) | FreePascal / Lazarus | `ToobitDemo.lpr`, `ToobitTester.lpr` |

| Program | Purpose |
|---|---|
| `ToobitDemo` | Minimal example: self-test, one REST call, a short market stream. |
| `ToobitTester` | Interactive console tester that exercises most of the library. |

Both compilers use the same library sources in `../src`. The only differences between the program variants are the project header (`{$mode delphi}` and the HTTPS helper unit `opensslsockets` for FPC 3.2+) and the build instructions.

> Neither variant has been compiled yet. The FreePascal variants in particular are untested; please report any compiler error with its line number.

## Keys

Private tests need an API key. Prefer environment variables (the programs never print them):

```
set TOOBIT_API_KEY=...
set TOOBIT_SECRET_KEY=...
```

or choose "Enter API keys now" in the Settings group (what you type is echoed in the console). For the first runs use a **read-only** key.

## ToobitTester menu

Type the number of a test, `A` to run all safe tests with default answers, or `Q` to quit. Every test prints how long it took; failures are shown with HTTP status, API code and message.

| Group | Test | Keys | What it checks |
|---|---|---|---|
| Offline | Offline checks | no | HMAC-SHA256 vectors (RFC 4231 and others), SHA-256, parameter list, URL encoding, JSON helpers, order constructors |
| Offline | Error handling checks | partly | Client-side validation, signed call without keys, unknown symbol, fake credentials, stale timestamp |
| Connection | Synchronise clock | no | `SyncTime` and the stored offset |
| Public REST | Spot market data / exchangeInfo | no | Ticker, book ticker, 24h, depth, merged depth, trades, klines |
| Public REST | Futures market data / exchangeInfo | no | Ticker, mark price, funding rate, open interest, depth, trades, klines, risk limits |
| Private REST (read) | Spot: key check, account, open orders | yes | Signing end to end |
| Private REST (read) | Futures: balance, positions, orders | yes | Signing, `category`, leverage, commission, PnL |
| Private REST (read) | Spot TestOrder | yes | Order validation without a real order |
| Private REST (read) | listenKey create / keep-alive / close | yes | Spot and futures listenKey endpoints |
| Streams | Market stream | no | Subscriptions, unsubscribe, ping, reconnect (disconnect your network while it runs) |
| Streams | User-data stream | yes | listenKey handling and account events (trade in the app meanwhile) |
| [DANGER] | Spot / Futures order lifecycle | yes | Places a **real** limit order, queries it, cancels it |
| Settings | Keys, print length, `recvWindow`, `ParamMode`, futures category | no | Switch behaviour while testing |

### Safety rules of the tester

- The lifecycle tests never choose a price or quantity for you. You enter them, and you must type `YES` to continue. Pick a price far below the market and the smallest allowed quantity.
- If an order is placed but its `orderId` cannot be read from the reply, the program tells you to check your open orders manually.
- The order is cancelled in a `finally` block, so a failing query still tries to cancel it.
- `A` (run all safe tests) never runs the `[DANGER]` tests and never opens the user-data stream.

### Suggested first session

1. `1` Offline checks, which must all pass on your compiler.
2. `3` Synchronise clock, then `4` and `6` for public data.
3. With a read-only key: `8` and `9`.
4. `12` market stream for 15 seconds, then again while disabling and re-enabling the network.
5. Only then consider the `[DANGER]` tests, with tiny sizes.

Numbers in the menu can change if items are added; the program prints the current numbering every time.
