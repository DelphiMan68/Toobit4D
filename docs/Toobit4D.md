# Toobit4D (main unit)

`uses Toobit4D;` gives you `TToobit`. Pascal does not re-export units that Toobit4D itself uses, so add the other units you need to your own `uses` clause: `Toobit4D.Types` (constants and exceptions), `Toobit4D.Spot` / `Toobit4D.Futures` (order records and constructors), `Toobit4D.Utils`, `Toobit4D.Json`, `Toobit4D.Client`, `Toobit4D.Stream`, `Toobit4D.WS.Transport`.

## TToobit

The entry point of the library. It creates, holds and frees `Client`, `Spot` and `Futures`.

```pascal
constructor Create(const AApiKey: string = ''; const ASecretKey: string = '');
destructor Destroy; override;
function NewMarketStream: TToobitMarketStream;
function NewUserStream(AKind: TToobitUserStreamKind): TToobitUserStream;
property Client: TToobitClient read;
property Spot: TToobitSpotApi read;
property Futures: TToobitFuturesApi read;
```

| Member | Description |
|---|---|
| `Create` | Keys are optional. Without keys only public endpoints work. You can set `Client.ApiKey` / `Client.SecretKey` later. |
| `NewMarketStream` | Creates a `TToobitMarketStream` with the default transport (WebSocket4D). **You own the result** and must `Free` it (`Stop` is called automatically). |
| `NewUserStream(AKind)` | Private stream, `usSpot` or `usFutures`. For futures, the current value of `Futures.Category` is copied into the stream at creation time. You own the result. |
| `Client` | REST core: `SyncTime`, `Request`, and settings such as `RecvWindow`. |
| `Spot` / `Futures` | Endpoint wrappers. |

Note: `TToobit` does not keep track of the streams it creates. Free the streams **before** freeing `TToobit`, because the user stream uses `Client` during `Stop` (to close the listenKey).

### Example

```pascal
Toobit := TToobit.Create(Key, Secret);
Toobit.Client.SyncTime;
Toobit.Futures.Category := TB_CATEGORY_USDC;   // work on USDC-M
US := Toobit.NewUserStream(usFutures);
US.OnMessage := Handler.OnMsg;
US.Start;
...
US.Free;
Toobit.Free;
```
