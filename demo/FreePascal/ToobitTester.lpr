program ToobitTester;
{$mode delphi}{$H+}
{$APPTYPE CONSOLE}

{ Interactive console tester for Toobit4D (FreePascal).

  Build from this folder (Windows):
      fpc -Mdelphi -Fu..\..\src -Fu<RESTRequest4Delphi>\src -Fu<WebSocket4D>\Source ToobitTester.lpr
  or create a Lazarus "Program" project from this file and add the same three folders as
  "Other unit files" (Project > Project Options > Paths).

  HTTPS needs the OpenSSL DLLs (libssl / libcrypto, matching your FPC version) next to the .exe.

  Keys (only needed for the private tests) are read from the environment variables
      TOOBIT_API_KEY      TOOBIT_SECRET_KEY
  or can be typed in from the menu. Keys are never printed.

  Tests marked [DANGER] place a REAL order (far from the market, then cancel it). They ask for
  confirmation and require YOU to supply symbol, quantity and price. Use tiny sizes. }

uses
  {$IF FPC_FULLVERSION >= 30200}opensslsockets,{$ENDIF}  // HTTPS for fphttpclient (FPC 3.2+)
  SysUtils, Classes, SyncObjs,
  Toobit4D, Toobit4D.Types, Toobit4D.Utils, Toobit4D.Json, Toobit4D.Client,
  Toobit4D.Spot, Toobit4D.Futures, Toobit4D.Stream;

type
  TTestProc = procedure;

  TTestItem = record
    Group: string;
    Title: string;
    Proc: TTestProc;
    NeedKeys: Boolean;
    Danger: Boolean;
    InAll: Boolean;       // part of "run all safe tests"
  end;

  { Collects stream events from the worker threads. }
  TStreamProbe = class
  private
    FLock: TCriticalSection;
    FCounts: TStringList;
  public
    constructor Create;
    destructor Destroy; override;
    procedure OnMsg(Sender: TObject; const ATopic, ASymbol, AJson: string);
    procedure OnConnected(Sender: TObject);
    procedure OnDisconnected(Sender: TObject);
    procedure OnError(Sender: TObject; const AMessage: string);
    procedure Report;
  end;

var
  Toobit: TToobit;
  Items: array of TTestItem;
  MaxPrint: Integer = 700;
  UseDefaults: Boolean = False;
  GPass, GFail: Integer;

{ ------------------------------------------------------------------ helpers -- }

function Ask(const APrompt, ADefault: string): string;
begin
  if UseDefaults then
  begin
    Writeln(APrompt, ' -> ', ADefault, ' (default)');
    Result := ADefault;
    Exit;
  end;
  Write(APrompt);
  if ADefault <> '' then
    Write(' [', ADefault, ']');
  Write(': ');
  Readln(Result);
  Result := Trim(Result);
  if Result = '' then
    Result := ADefault;
end;

function Confirm(const AMessage: string): Boolean;
begin
  Writeln;
  Writeln('!!! ', AMessage);
  Result := Ask('Type YES (capital letters) to continue', '') = 'YES';
end;

function HasKeys: Boolean;
begin
  Result := (Toobit.Client.ApiKey <> '') and (Toobit.Client.SecretKey <> '');
end;

procedure Show(const ATitle, AJson: string);
begin
  Writeln('--- ', ATitle, ' (', Length(AJson), ' chars)');
  if Length(AJson) > MaxPrint then
    Writeln(Copy(AJson, 1, MaxPrint), ' ...[truncated]')
  else
    Writeln(AJson);
end;

procedure Check(const AName: string; ACondition: Boolean);
begin
  if ACondition then
  begin
    Inc(GPass);
    Writeln('  PASS  ', AName);
  end
  else
  begin
    Inc(GFail);
    Writeln('  FAIL  ', AName);
  end;
end;

procedure Wait(ASeconds: Integer);
var
  T0: Int64;
begin
  T0 := ToobitTickMs;
  while ToobitTickMs - T0 < Int64(ASeconds) * 1000 do
    Sleep(200);
end;

function Stamp: string;
begin
  Result := FormatDateTime('hh:nn:ss', Now);
end;

{ ----------------------------------------------------------- stream probe -- }

constructor TStreamProbe.Create;
begin
  inherited Create;
  FLock := TCriticalSection.Create;
  FCounts := TStringList.Create;
end;

destructor TStreamProbe.Destroy;
begin
  FCounts.Free;
  FLock.Free;
  inherited;
end;

procedure TStreamProbe.OnMsg(Sender: TObject; const ATopic, ASymbol, AJson: string);
var
  LKey: string;
  N: Integer;
begin
  LKey := ATopic;
  if LKey = '' then
    LKey := '(no topic)';
  FLock.Enter;
  try
    N := StrToIntDef(FCounts.Values[LKey], 0) + 1;
    FCounts.Values[LKey] := IntToStr(N);
    if N <= 2 then      // print only the first two frames of each topic
      Writeln('  [', Stamp, '] ', LKey, ' ', ASymbol, ' ', Copy(AJson, 1, MaxPrint));
  finally
    FLock.Leave;
  end;
end;

procedure TStreamProbe.OnConnected(Sender: TObject);
begin
  FLock.Enter;
  try
    Writeln('  [', Stamp, '] CONNECTED');
  finally
    FLock.Leave;
  end;
end;

procedure TStreamProbe.OnDisconnected(Sender: TObject);
begin
  FLock.Enter;
  try
    Writeln('  [', Stamp, '] DISCONNECTED');
  finally
    FLock.Leave;
  end;
end;

procedure TStreamProbe.OnError(Sender: TObject; const AMessage: string);
begin
  FLock.Enter;
  try
    Writeln('  [', Stamp, '] ERROR: ', AMessage);
  finally
    FLock.Leave;
  end;
end;

procedure TStreamProbe.Report;
var
  I: Integer;
begin
  FLock.Enter;
  try
    Writeln('--- frames received per topic:');
    if FCounts.Count = 0 then
      Writeln('  (none)');
    for I := 0 to FCounts.Count - 1 do
      Writeln('  ', FCounts.Names[I], ': ', FCounts.ValueFromIndex[I]);
  finally
    FLock.Leave;
  end;
end;

{ ------------------------------------------------------------ offline tests -- }

procedure TestOffline;
var
  P: IToobitParams;
begin
  Writeln('Offline checks (no network, no keys):');
  Check('HMAC RFC 4231 case 2 (ToobitSelfTest)', ToobitSelfTest);
  Check('HMAC RFC 4231 case 1',
    HmacSha256Hex(StringOfChar(#11, 20), 'Hi There') =
    'b0344c61d8db38535ca8afceaf0bf12b881dc200c9833da726e9376c2e32cff7');
  Check('HMAC key longer than the block size',
    HmacSha256Hex(StringOfChar('k', 100), 'The quick brown fox') =
    '4932d9be9aab7ee4618b6390795b1c7468d4cb30043784bac4d195907d9433d9');
  Check('HMAC empty key and message',
    HmacSha256Hex('', '') =
    'b613679a0814d9ec772f95d778c35fc5ff1697c493715653c6c712144292c5ad');
  Check('HMAC typical signed string',
    HmacSha256Hex('secret', 'symbol=BTCUSDT&timestamp=1700000000000&recvWindow=5000') =
    '898122a528961a351a3a8321656401f94a9273b6b8a3eee071845e9c573a755e');
  Check('SHA-256("abc") as lower-case hex',
    BytesToHexLower(Sha256Bytes(Utf8Bytes('abc'))) =
    'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad');

  P := NewParams.Add('symbol', 'BTCUSDT').Add('note', 'a b&c').AddIf('skip', '')
    .AddPos('zero', 0).AddPos('five', 5);
  Check('Params.ToRaw (skips empty / non-positive)', P.ToRaw = 'symbol=BTCUSDT&note=a b&c&five=5');
  Check('Params.ToEncoded', P.ToEncoded = 'symbol=BTCUSDT&note=a%20b%26c&five=5');
  Check('Params.Has / Count', P.Has('note') and (not P.Has('skip')) and (P.Count = 3));
  Check('UrlEncode', UrlEncode('A-z_0.~ /') = 'A-z_0.~%20%2F');

  Check('JsonQuote escapes quote and backslash', JsonQuote('a"b\c') = '"a\"b\\c"');
  Check('JsonField string value', JsonField('{"a":1,"b":"x"}', 'b') = 'x');
  Check('JsonField number value', JsonField('{"a":1,"b":"x"}', 'a') = '1');
  Check('JsonField missing key / invalid JSON',
    (JsonField('{"a":1}', 'z') = '') and (JsonField('not json', 'a') = ''));
  Check('JsonQuickString',
    JsonQuickString('{"topic": "trade","symbol":"BTCUSDT"}', 'symbol') = 'BTCUSDT');

  Check('Client.NowMs is plausible', Toobit.Client.NowMs > 1700000000000);
  Check('SpotOrder() fills the record',
    (SpotOrder('BTCUSDT', TB_SIDE_BUY, TB_TYPE_LIMIT, '1', '2').Price = '2'));
  Check('FuturesMarketOrder() = LIMIT + MARKET price type',
    (FuturesMarketOrder('BTC-SWAP-USDT', TB_SIDE_BUY_OPEN, '1', 'x').PriceType = TB_PRICE_MARKET) and
    (FuturesMarketOrder('BTC-SWAP-USDT', TB_SIDE_BUY_OPEN, '1', 'x').OrderType = TB_TYPE_LIMIT));

  Writeln;
  Writeln('Offline result: ', GPass, ' passed, ', GFail, ' failed');
  if GFail > 0 then
    raise Exception.Create('Offline checks failed');
end;

procedure TestErrors;
var
  Fake, NoKeys: TToobitClient;
begin
  Writeln('Error handling checks:');

  // 1) client-side validation (offline)
  try
    Toobit.Spot.CancelOrder('');
    Check('CancelOrder(empty) raises EToobitError', False);
  except
    on E: EToobitError do
      Check('CancelOrder(empty) raises EToobitError', True);
  end;

  // 2) signed endpoint without keys (offline)
  NoKeys := TToobitClient.Create;
  try
    try
      NoKeys.Request(hmGet, '/api/v1/account', nil, tsSigned);
      Check('Signed call without keys raises EToobitError', False);
    except
      on E: EToobitError do
        Check('Signed call without keys raises EToobitError', True);
    end;
  finally
    NoKeys.Free;
  end;

  // 3) invalid symbol on a public endpoint (network)
  try
    Show('Spot.TickerPrice("NOTASYMBOL999")', Toobit.Spot.TickerPrice('NOTASYMBOL999'));
    Writeln('  INFO  the server answered without an HTTP error for an unknown symbol');
  except
    on E: EToobitHttpError do
      Writeln('  INFO  HTTP ', E.StatusCode, ' code=', E.ApiCode, ' msg=', E.ApiMessage);
  end;

  // 4) bad credentials (network)
  Fake := TToobitClient.Create('fakeApiKey', 'fakeSecretKey');
  try
    Fake.SyncTime;
    try
      Fake.Request(hmGet, '/api/v1/account', nil, tsSigned);
      Check('Fake credentials are rejected', False);
    except
      on E: EToobitHttpError do
      begin
        Check('Fake credentials are rejected (EToobitHttpError)', True);
        Writeln('  INFO  HTTP ', E.StatusCode, ' code=', E.ApiCode, ' msg=', E.ApiMessage);
      end;
    end;
  finally
    Fake.Free;
  end;

  // 5) stale timestamp (network, needs real keys)
  if HasKeys then
  begin
    try
      Toobit.Client.Request(hmGet, '/api/v1/account',
        NewParams.Add('timestamp', Toobit.Client.NowMs - 600000), tsSigned);
      Check('Stale timestamp is rejected', False);
    except
      on E: EToobitHttpError do
      begin
        Check('Stale timestamp is rejected (EToobitHttpError)', True);
        Writeln('  INFO  HTTP ', E.StatusCode, ' code=', E.ApiCode, ' msg=', E.ApiMessage);
      end;
    end;
  end
  else
    Writeln('  SKIP  stale timestamp check (needs API keys)');

  Writeln;
  Writeln('Error checks so far: ', GPass, ' passed, ', GFail, ' failed (counters are cumulative)');
end;

{ ------------------------------------------------------------ settings -- }

procedure EnterKeys;
begin
  Writeln('NOTE: what you type is echoed in the console. Prefer the environment variables.');
  Toobit.Client.ApiKey := Ask('API key', '');
  Toobit.Client.SecretKey := Ask('Secret key', '');
  Writeln('Keys set: ', HasKeys);
end;

procedure SetPrintLimit;
begin
  MaxPrint := StrToIntDef(Ask('Max characters printed per response', IntToStr(MaxPrint)), MaxPrint);
end;

procedure SetRecvWindow;
begin
  Toobit.Client.RecvWindow := StrToIntDef(Ask('recvWindow in ms (max 60000)',
    IntToStr(Toobit.Client.RecvWindow)), Toobit.Client.RecvWindow);
  Writeln('recvWindow = ', Toobit.Client.RecvWindow);
end;

procedure ToggleParamMode;
begin
  if Toobit.Client.ParamMode = pmAddParam then
    Toobit.Client.ParamMode := pmInUrl
  else
    Toobit.Client.ParamMode := pmAddParam;
  if Toobit.Client.ParamMode = pmAddParam then
    Writeln('ParamMode = pmAddParam (default)')
  else
    Writeln('ParamMode = pmInUrl');
end;

procedure ToggleCategory;
begin
  if Toobit.Futures.Category = '' then
    Toobit.Futures.Category := TB_CATEGORY_USDC
  else
    Toobit.Futures.Category := '';
  if Toobit.Futures.Category = '' then
    Writeln('Futures category = USDT-M (symbols like BTC-SWAP-USDT)')
  else
    Writeln('Futures category = USDC-M (symbols like BTC-SWAP-USDC)');
end;

procedure TestSyncTime;
begin
  Writeln('Offset (server - local): ', Toobit.Client.SyncTime, ' ms');
  Writeln('Client.NowMs = ', Toobit.Client.NowMs);
end;

{ ----------------------------------------------------- public: spot / futures -- }

procedure TestSpotPublic;
var
  S: string;
begin
  S := Ask('Spot symbol', 'BTCUSDT');
  Show('Spot.ServerTime', Toobit.Spot.ServerTime);
  Show('Spot.TickerPrice', Toobit.Spot.TickerPrice(S));
  Show('Spot.BookTicker', Toobit.Spot.BookTicker(S));
  Show('Spot.Ticker24h', Toobit.Spot.Ticker24h(S));
  Show('Spot.Depth(5)', Toobit.Spot.Depth(S, 5));
  Show('Spot.MergedDepth(scale 2, 5)', Toobit.Spot.MergedDepth(S, 2, 5));
  Show('Spot.Trades(3)', Toobit.Spot.Trades(S, 3));
  Show('Spot.Klines(1m x 3)', Toobit.Spot.Klines(S, TB_INT_1M, 0, 0, 3));
end;

procedure TestSpotExchangeInfo;
var
  J: string;
begin
  J := Toobit.Spot.ExchangeInfo;
  Show('Spot.ExchangeInfo', J);
  Writeln('timezone=', JsonField(J, 'timezone'), ' serverTime=', JsonField(J, 'serverTime'));
end;

procedure TestFuturesPublic;
var
  S: string;
begin
  S := Ask('Futures symbol', 'BTC-SWAP-USDT');
  Show('Futures.TickerPrice', Toobit.Futures.TickerPrice(S));
  Show('Futures.BookTicker', Toobit.Futures.BookTicker(S));
  Show('Futures.Ticker24h', Toobit.Futures.Ticker24h(S));
  Show('Futures.MarkPrice', Toobit.Futures.MarkPrice(S));
  Show('Futures.FundingRate', Toobit.Futures.FundingRate(S));
  Show('Futures.OpenInterest', Toobit.Futures.OpenInterest(S));
  Show('Futures.Depth(5)', Toobit.Futures.Depth(S, 5));
  Show('Futures.Trades(3)', Toobit.Futures.Trades(S, 3));
  Show('Futures.Klines(1m x 3)', Toobit.Futures.Klines(S, TB_INT_1M, 0, 0, 3));
  Show('Futures.RiskLimits', Toobit.Futures.RiskLimits(S));
end;

procedure TestFuturesExchangeInfo;
var
  J: string;
begin
  J := Toobit.Futures.ExchangeInfo;
  Show('Futures.ExchangeInfo', J);
end;

{ ------------------------------------------------- private, read-only calls -- }

procedure TestSpotPrivate;
begin
  Show('Spot.CheckApiKey', Toobit.Spot.CheckApiKey);
  Show('Spot.Account', Toobit.Spot.Account);
  Show('Spot.OpenOrders', Toobit.Spot.OpenOrders('', '', 5));
  Show('Spot.BalanceFlow(limit 3)', Toobit.Spot.BalanceFlow(0, '', 0, 0, 0, 3));
end;

procedure TestFuturesPrivate;
var
  S: string;
begin
  S := Ask('Futures symbol (for commission / leverage)', 'BTC-SWAP-USDT');
  Show('Futures.Balance', Toobit.Futures.Balance);
  Show('Futures.Positions', Toobit.Futures.Positions);
  Show('Futures.OpenOrders', Toobit.Futures.OpenOrders('', '', '', 5));
  Show('Futures.CommissionRate', Toobit.Futures.CommissionRate(S));
  Show('Futures.AccountLeverage', Toobit.Futures.AccountLeverage(S));
  Show('Futures.TodayPnl', Toobit.Futures.TodayPnl);
end;

procedure TestSpotDryRun;
var
  Sym, Qty, Price: string;
begin
  Writeln('Spot.TestOrder validates the order but never reaches the matching engine.');
  Sym := Ask('Symbol', 'BTCUSDT');
  Qty := Ask('Quantity', '0.001');
  Price := Ask('Limit price', '10000');
  Show('Spot.TestOrder', Toobit.Spot.TestOrder(
    SpotOrder(Sym, TB_SIDE_BUY, TB_TYPE_LIMIT, Qty, Price, TB_TIF_GTC,
      't4d-' + IntToStr(Toobit.Client.NowMs))));
end;

{ -------------------------------------------- DANGER: real order lifecycle -- }

procedure TestSpotOrderLifecycle;
var
  Sym, Qty, Price, Resp, Id: string;
begin
  Writeln('Places a REAL spot LIMIT BUY, queries it, then cancels it.');
  Sym := Ask('Symbol', 'BTCUSDT');
  Show('Current price', Toobit.Spot.TickerPrice(Sym));
  Writeln('Choose a price FAR BELOW the market so the order cannot fill.');
  Qty := Ask('Quantity (meet the symbol minimums)', '');
  Price := Ask('Limit price', '');
  if (Qty = '') or (Price = '') then
  begin
    Writeln('Quantity and price are required.');
    Exit;
  end;
  Resp := Toobit.Spot.NewOrder(SpotOrder(Sym, TB_SIDE_BUY, TB_TYPE_LIMIT, Qty, Price,
    TB_TIF_GTC, 't4d-' + IntToStr(Toobit.Client.NowMs)));
  Show('Spot.NewOrder', Resp);
  Id := JsonField(Resp, 'orderId');
  if Id = '' then
  begin
    Writeln('No orderId in the response - check your open orders manually!');
    Exit;
  end;
  try
    Sleep(500);
    Show('Spot.QueryOrder', Toobit.Spot.QueryOrder(Id));
    Show('Spot.OpenOrders', Toobit.Spot.OpenOrders(Sym, '', 5));
  finally
    Show('Spot.CancelOrder', Toobit.Spot.CancelOrder(Id));
  end;
  Sleep(500);
  Show('Spot.QueryOrder (after cancel)', Toobit.Spot.QueryOrder(Id));
end;

procedure TestFuturesOrderLifecycle;
var
  Sym, Qty, Price, Resp, Id, Cid: string;
begin
  Writeln('Places a REAL futures LIMIT BUY_OPEN, queries it, then cancels it.');
  Sym := Ask('Symbol', 'BTC-SWAP-USDT');
  Show('Current price', Toobit.Futures.TickerPrice(Sym));
  Writeln('Choose a price FAR BELOW the market so the order cannot fill.');
  Qty := Ask('Quantity in contracts (meet the symbol minimums)', '');
  Price := Ask('Limit price', '');
  if (Qty = '') or (Price = '') then
  begin
    Writeln('Quantity and price are required.');
    Exit;
  end;
  Cid := 't4d-' + IntToStr(Toobit.Client.NowMs);
  Resp := Toobit.Futures.NewOrder(FuturesLimitOrder(Sym, TB_SIDE_BUY_OPEN, Qty, Price, Cid, TB_TIF_GTC));
  Show('Futures.NewOrder', Resp);
  Id := JsonField(Resp, 'orderId');
  if Id = '' then
  begin
    Writeln('No orderId in the response - check your open orders manually!');
    Exit;
  end;
  try
    Sleep(500);
    Show('Futures.QueryOrder', Toobit.Futures.QueryOrder(Id));
    Show('Futures.OpenOrders', Toobit.Futures.OpenOrders(Sym, '', '', 5));
  finally
    Show('Futures.CancelOrder', Toobit.Futures.CancelOrder(Id));
  end;
  Sleep(500);
  Show('Futures.HistoryOrders (latest)', Toobit.Futures.HistoryOrders(Sym, '', '', 0, 0, 3));
end;

{ ------------------------------------------------------------------ streams -- }

procedure TestMarketStream;
var
  Probe: TStreamProbe;
  MS: TToobitMarketStream;
  Kind, Sym: string;
  Secs: Integer;
  IsFutures: Boolean;
begin
  Kind := LowerCase(Ask('Market (spot / futures)', 'spot'));
  IsFutures := Kind = 'futures';
  if IsFutures then
    Sym := Ask('Symbol', 'BTC-SWAP-USDT')
  else
    Sym := Ask('Symbol', 'BTCUSDT');
  Secs := StrToIntDef(Ask('Seconds to listen (disconnect your network to test reconnect)', '15'), 15);

  Probe := TStreamProbe.Create;
  MS := Toobit.NewMarketStream;
  try
    MS.OnMessage := Probe.OnMsg;
    MS.OnConnected := Probe.OnConnected;
    MS.OnDisconnected := Probe.OnDisconnected;
    MS.OnError := Probe.OnError;

    MS.SubscribeTrades([Sym]);
    MS.SubscribeKline([Sym], TB_INT_1M, 2);
    MS.SubscribeTicker([Sym]);
    MS.SubscribeDepth([Sym]);
    if IsFutures then
    begin
      MS.SubscribeBookTicker([Sym]);
      MS.SubscribeMarkPrice([Sym]);
    end;

    MS.Start;
    Writeln('Listening for ', Secs, ' s ...');
    Wait(Secs);
    Probe.Report;

    Writeln('Unsubscribing from depth and listening 3 s more ...');
    MS.Unsubscribe('depth', [Sym]);
    Wait(3);
    Probe.Report;
    Writeln('Connected = ', MS.Connected, ', Active = ', MS.Active);
  finally
    MS.Free;          // stops the worker thread
    Probe.Free;
  end;
end;

procedure TestUserStream;
var
  Probe: TStreamProbe;
  US: TToobitUserStream;
  Kind: string;
  Secs: Integer;
begin
  Kind := LowerCase(Ask('Account (spot / futures)', 'spot'));
  Secs := StrToIntDef(Ask('Seconds to listen', '60'), 60);
  Writeln('While this runs, place / cancel an order (or change a balance) in the Toobit app');
  Writeln('to see events such as executionReport or contractExecutionReport.');

  Probe := TStreamProbe.Create;
  if Kind = 'futures' then
    US := Toobit.NewUserStream(usFutures)
  else
    US := Toobit.NewUserStream(usSpot);
  try
    US.OnMessage := Probe.OnMsg;
    US.OnConnected := Probe.OnConnected;
    US.OnDisconnected := Probe.OnDisconnected;
    US.OnError := Probe.OnError;
    US.Start;
    Writeln('Listening for ', Secs, ' s ...');
    Wait(Secs);
    if US.ListenKey <> '' then
      Writeln('listenKey obtained: ', Copy(US.ListenKey, 1, 6), '...');
    Probe.Report;
  finally
    US.Free;          // closes the listenKey
    Probe.Free;
  end;
end;

procedure TestListenKeyRest;
var
  K: string;
begin
  K := Toobit.Spot.CreateListenKey;
  Writeln('Spot listenKey created: ', Copy(K, 1, 6), '...');
  Toobit.Spot.KeepAliveListenKey(K);
  Writeln('Spot listenKey kept alive');
  Toobit.Spot.CloseListenKey(K);
  Writeln('Spot listenKey closed');

  K := Toobit.Futures.CreateListenKey;
  Writeln('Futures listenKey created: ', Copy(K, 1, 6), '...');
  Toobit.Futures.KeepAliveListenKey(K);
  Writeln('Futures listenKey kept alive');
  Toobit.Futures.CloseListenKey(K);
  Writeln('Futures listenKey closed');
end;

{ ---------------------------------------------------------------------- menu -- }

procedure AddItem(const AGroup, ATitle: string; AProc: TTestProc;
  ANeedKeys, ADanger, AInAll: Boolean);
begin
  SetLength(Items, Length(Items) + 1);
  with Items[High(Items)] do
  begin
    Group := AGroup;
    Title := ATitle;
    Proc := AProc;
    NeedKeys := ANeedKeys;
    Danger := ADanger;
    InAll := AInAll;
  end;
end;

procedure BuildMenu;
begin
  //       group                  title                                        proc                   keys   danger inAll
  AddItem('Offline',              'Offline checks (HMAC, params, JSON)',       TestOffline,           False, False, True);
  AddItem('Offline',              'Error handling checks',                     TestErrors,            False, False, True);
  AddItem('Connection',           'Synchronise clock with the server',         TestSyncTime,          False, False, True);
  AddItem('Public REST',          'Spot market data',                          TestSpotPublic,        False, False, True);
  AddItem('Public REST',          'Spot exchangeInfo',                         TestSpotExchangeInfo,  False, False, True);
  AddItem('Public REST',          'Futures market data',                       TestFuturesPublic,     False, False, True);
  AddItem('Public REST',          'Futures exchangeInfo',                      TestFuturesExchangeInfo, False, False, True);
  AddItem('Private REST (read)',  'Spot: key check, account, open orders',     TestSpotPrivate,       True,  False, True);
  AddItem('Private REST (read)',  'Futures: balance, positions, orders',       TestFuturesPrivate,    True,  False, True);
  AddItem('Private REST (read)',  'Spot TestOrder (dry run, no real order)',   TestSpotDryRun,        True,  False, False);
  AddItem('Private REST (read)',  'listenKey create / keep-alive / close',     TestListenKeyRest,     True,  False, True);
  AddItem('Streams',              'Market stream (+ unsubscribe, reconnect)',  TestMarketStream,      False, False, True);
  AddItem('Streams',              'User-data stream',                          TestUserStream,        True,  False, False);
  AddItem('[DANGER] real orders', 'Spot: place LIMIT far from market, cancel', TestSpotOrderLifecycle, True,  True,  False);
  AddItem('[DANGER] real orders', 'Futures: place LIMIT far from market, cancel', TestFuturesOrderLifecycle, True, True, False);
  AddItem('Settings',             'Enter API keys now',                        EnterKeys,             False, False, False);
  AddItem('Settings',             'Set printed response length',               SetPrintLimit,         False, False, False);
  AddItem('Settings',             'Set recvWindow',                            SetRecvWindow,         False, False, False);
  AddItem('Settings',             'Toggle ParamMode (AddParam / InUrl)',       ToggleParamMode,       False, False, False);
  AddItem('Settings',             'Toggle futures category (USDT-M / USDC-M)', ToggleCategory,        False, False, False);
end;

function RunItem(AIndex: Integer): Boolean;
var
  T0: Int64;
begin
  Result := True;
  if Items[AIndex].NeedKeys and not HasKeys then
  begin
    Writeln('SKIPPED: needs TOOBIT_API_KEY and TOOBIT_SECRET_KEY (or "Enter API keys now").');
    Exit;
  end;
  if Items[AIndex].Danger and
     not Confirm('This test places a REAL order on your Toobit account. Use tiny sizes.') then
  begin
    Writeln('Cancelled.');
    Exit;
  end;

  Writeln;
  Writeln('=== ', Items[AIndex].Title);
  T0 := ToobitTickMs;
  try
    Items[AIndex].Proc;
  except
    on E: EToobitRateLimitError do
    begin
      Result := False;
      Writeln('RATE LIMIT (HTTP 429): back off before trying again. ', E.Message);
    end;
    on E: EToobitServerError do
    begin
      Result := False;
      Writeln('SERVER ERROR HTTP ', E.StatusCode, ' - the order state may be UNKNOWN: ', E.Message);
    end;
    on E: EToobitHttpError do
    begin
      Result := False;
      Writeln('HTTP ERROR ', E.StatusCode, ' code=', E.ApiCode, ' msg=', E.ApiMessage);
      Writeln('  body: ', Copy(E.Content, 1, MaxPrint));
    end;
    on E: Exception do
    begin
      Result := False;
      Writeln('EXCEPTION ', E.ClassName, ': ', E.Message);
    end;
  end;
  Writeln('=== finished in ', ToobitTickMs - T0, ' ms', '  [', Stamp, ']');
end;

procedure RunAllSafe;
var
  I, Ok, Failed, Skipped: Integer;
  Failures: string;
begin
  Writeln('Running every non-dangerous, non-interactive test with default answers ...');
  UseDefaults := True;
  Ok := 0; Failed := 0; Skipped := 0; Failures := '';
  try
    for I := 0 to High(Items) do
      if Items[I].InAll then
      begin
        if Items[I].NeedKeys and not HasKeys then
        begin
          Inc(Skipped);
          Continue;
        end;
        if RunItem(I) then
          Inc(Ok)
        else
        begin
          Inc(Failed);
          Failures := Failures + '  - ' + Items[I].Title + sLineBreak;
        end;
      end;
  finally
    UseDefaults := False;
  end;
  Writeln;
  Writeln('############ SUMMARY ############');
  Writeln('Passed: ', Ok, '   Failed: ', Failed, '   Skipped (no keys): ', Skipped);
  if Failures <> '' then
  begin
    Writeln('Failed tests:');
    Write(Failures);
  end;
end;

procedure PrintMenu;
var
  I: Integer;
  LastGroup: string;
begin
  Writeln;
  Writeln('Toobit4D tester   keys: ', HasKeys, '   futures category: ',
    IntToStr(Ord(Toobit.Futures.Category <> '')), ' (0 = USDT-M, 1 = USDC-M)');
  LastGroup := '';
  for I := 0 to High(Items) do
  begin
    if Items[I].Group <> LastGroup then
    begin
      Writeln;
      Writeln(' ', Items[I].Group);
      LastGroup := Items[I].Group;
    end;
    Write('   ', Format('%2d', [I + 1]), '  ', Items[I].Title);
    if Items[I].NeedKeys then
      Write('  (keys)');
    Writeln;
  end;
  Writeln;
  Writeln('    A  run all safe tests with default answers      Q  quit');
end;

var
  Choice: string;
  N: Integer;
begin
  Toobit := TToobit.Create(GetEnvironmentVariable('TOOBIT_API_KEY'),
    GetEnvironmentVariable('TOOBIT_SECRET_KEY'));
  try
    BuildMenu;
    if HasKeys then
    begin
      try
        Toobit.Client.SyncTime;
        Writeln('Keys loaded from the environment; clock offset ', Toobit.Client.TimeOffset, ' ms.');
      except
        on E: Exception do
          Writeln('Clock sync failed: ', E.Message);
      end;
    end
    else
      Writeln('No keys in the environment: public and offline tests only.');

    repeat
      PrintMenu;
      Write('Choice: ');
      Readln(Choice);
      Choice := UpperCase(Trim(Choice));
      if Choice = 'Q' then
        Break
      else if Choice = 'A' then
        RunAllSafe
      else
      begin
        N := StrToIntDef(Choice, 0);
        if (N >= 1) and (N <= Length(Items)) then
          RunItem(N - 1)
        else
          Writeln('Unknown choice.');
      end;
    until False;
  finally
    Toobit.Free;
  end;
end.
