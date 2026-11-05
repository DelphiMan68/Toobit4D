# Toobit4D.WS.Transport

The abstract class `TToobitWsTransport`. `Toobit4D.Stream` talks only to this class, so the WebSocket library is isolated in **one small unit** that you can replace.

## Event types

```pascal
TToobitWsNotifyEvent = procedure(Sender: TObject) of object;
TToobitWsTextEvent   = procedure(Sender: TObject; const AText: string) of object;
```

## TToobitWsTransport

| Member | Kind | Description |
|---|---|---|
| `Connect(AUrl)` | abstract | Starts the connection. Must call `DoOpen` once the socket is usable. May block. |
| `Send(AText)` | abstract | Sends one text frame. |
| `Disconnect` | abstract | Closes the connection; must be safe to call repeatedly and must call `DoClose`. |
| `OnOpen` | event | The socket is ready. |
| `OnClose` | event | The socket closed. |
| `OnMessage` | event | Every received text frame. |
| `OnError` | event | An error message. |
| `DoOpen / DoClose / DoMessage / DoError` | protected | For implementers: raise the events (if assigned). |

## Contract for a new transport

1. After `Connect`, call `DoOpen` **exactly once** on success.
2. Every received text frame goes to `DoMessage`.
3. Any disconnect (by either side) goes to `DoClose`. The stream uses it to decide when to reconnect.
4. `Connect` must be usable again after `Disconnect` (the stream calls `Connect` on the same object when reconnecting).
5. `DoMessage` may be raised from any thread; the stream is thread-safe.
6. Binary or compressed frames are not needed; the library requests `binary:false`.

## Example: custom transport

```pascal
type
  TMyTransport = class(TToobitWsTransport)
    procedure Connect(const AUrl: string); override;
    procedure Send(const AText: string); override;
    procedure Disconnect; override;
  end;

Stream := TToobitMarketStream.Create(TMyTransport.Create);   // the stream does not own it; free it yourself
```

Note: when you pass your own transport to a stream, the stream does not own it and will not free it.
