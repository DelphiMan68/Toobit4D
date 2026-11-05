# Toobit4D.Json

Three small functions, so that the other units do not need to know whether the build uses `System.JSON` (Delphi) or `fpjson` (FPC).

## JsonField

```pascal
function JsonField(const AJson, AKey: string): string;
```
Returns a top-level field of a JSON object as text.

- String or number: the value without quotes.
- Nested object/array: its JSON text.
- `null`, missing key, invalid JSON, or a non-object root: `''`.
- Boolean: `true/false` on Delphi, `True/False` on FPC.
- It parses the whole document; for hot paths (WebSocket messages) use `JsonQuickString`.

```pascal
Key := JsonField(Resp, 'listenKey');
Price := JsonField(Resp, 'price');
```

## JsonQuickString

```pascal
function JsonQuickString(const AJson, AKey: string): string;
```
Fast scan without parsing: finds the first `"AKey" : "value"`. **String values only**; for a numeric value it returns `''`. Whitespace and newlines between tokens are allowed, but escape sequences inside the value (such as `\"`) are not processed. `Toobit4D.Stream` uses it to find `topic`, `symbol`, `e` and `eventType`.

## JsonQuote

```pascal
function JsonQuote(const S: string): string;
```
Turns a string into a valid quoted JSON literal (escapes `"`, `\`, `\b \t \n \f \r`, and other control characters as `\uXXXX`). Used to build compact JSON bodies (no newlines), because the Toobit signature is computed over the raw body.
