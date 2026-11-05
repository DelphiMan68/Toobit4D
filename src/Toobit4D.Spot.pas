unit Toobit4D.Spot;
{$I Toobit4D.inc}

{ Spot REST endpoints (market data, trading, account, wallet, listenKey).
  Conventions: '' means "parameter not sent"; for numeric optional parameters 0
  (or -1 for 'scale') means "not sent". Every method returns the raw JSON text. }

interface

uses
  SysUtils, Toobit4D.Types, Toobit4D.Utils, Toobit4D.Client;

type
  TToobitSpotOrder = record
    Symbol: string;
    Side: string;             // TB_SIDE_BUY / TB_SIDE_SELL
    OrderType: string;        // TB_TYPE_LIMIT / MARKET / LIMIT_MAKER
    TimeInForce: string;      // optional
    Quantity: string;         // MARKET BUY: amount in QUOTE asset (e.g. USDT)
    Price: string;            // LIMIT / LIMIT_MAKER
    ClientOrderId: string;    // required for batch orders
  end;

  TToobitSpotApi = class
  private
    FClient: TToobitClient;
    function Pub(const APath: string; AParams: IToobitParams): string;
    function Key(const APath: string; AParams: IToobitParams): string;
    function Sig(AMethod: TToobitHttpMethod; const APath: string; AParams: IToobitParams): string;
  public
    constructor Create(AClient: TToobitClient);

    { ---- market data (public) ---- }
    function ServerTime: string;
    function ExchangeInfo: string;
    function Depth(const ASymbol: string; ALimit: Integer = 0): string;
    function MergedDepth(const ASymbol: string; AScale: Integer = -1; ALimit: Integer = 0): string;
    function Trades(const ASymbol: string; ALimit: Integer = 0): string;
    function Klines(const ASymbol, AInterval: string; AStartTime: Int64 = 0;
      AEndTime: Int64 = 0; ALimit: Integer = 0): string;
    function Ticker24h(const ASymbol: string = ''): string;
    function TickerPrice(const ASymbol: string = ''): string;
    function BookTicker(const ASymbol: string = ''): string;

    { ---- trading (TRADE) ---- }
    function TestOrder(const AOrder: TToobitSpotOrder): string;
    function NewOrder(const AOrder: TToobitSpotOrder): string;
    { Up to 20 orders, same symbol, each with ClientOrderId. }
    function BatchOrders(const AOrders: array of TToobitSpotOrder): string;
    function CancelOrder(const AOrderId: string; const AClientOrderId: string = ''): string;
    function CancelAllOpenOrders(const ASymbol: string = ''; const ASide: string = ''): string;
    { Up to 100 ids. }
    function CancelOrdersByIds(const AOrderIds: array of string): string;

    { ---- account / orders (USER_DATA) ---- }
    function QueryOrder(const AOrderId: string; const AOrigClientOrderId: string = ''): string;
    function OpenOrders(const ASymbol: string = ''; const AOrderId: string = ''; ALimit: Integer = 0): string;
    function AllOrders(const ASymbol: string = ''; const AOrderId: string = '';
      AStartTime: Int64 = 0; AEndTime: Int64 = 0; ALimit: Integer = 0): string;
    function Account: string;
    function AccountTrades(const ASymbol: string; AStartTime: Int64 = 0; AEndTime: Int64 = 0;
      const AFromId: string = ''; const AToId: string = ''; ALimit: Integer = 0): string;
    function SubAccounts: string;
    function BalanceFlow(AAccountType: Integer = 0; const ACoin: string = ''; AFlowType: Integer = 0;
      AStartTime: Int64 = 0; AEndTime: Int64 = 0; ALimit: Integer = 0): string;
    function CheckApiKey: string;
    { Transfer between main/sub accounts and spot/futures. Account types: TB_ACC_* }
    function Transfer(const AFromUid, AToUid, AFromAccountType, AToAccountType, ACoin,
      AQuantity: string; const ATransferId: string = ''): string;

    { ---- wallet (USER_DATA) ---- }
    function Withdraw(const ACoin, AClientOrderId, AAddress, AQuantity: string;
      const AChainType: string = ''; const AAddressExt: string = ''; const AAddressType: string = ''): string;
    function WithdrawOrders(const ACoin: string = ''; AStartTime: Int64 = 0; AEndTime: Int64 = 0;
      ALimit: Integer = 0): string;
    function DepositAddress(const ACoin, AChainType: string): string;
    function DepositOrders(const ACoin: string = ''; AStartTime: Int64 = 0; AEndTime: Int64 = 0;
      ALimit: Integer = 0): string;

    { ---- user data stream (USER_STREAM) ---- }
    function CreateListenKey: string;      // returns the listenKey itself
    procedure KeepAliveListenKey(const AListenKey: string);
    procedure CloseListenKey(const AListenKey: string);
  end;

function SpotOrder(const ASymbol, ASide, AType, AQuantity: string; const APrice: string = '';
  const ATimeInForce: string = ''; const AClientOrderId: string = ''): TToobitSpotOrder;

implementation

uses
  Toobit4D.Json;

function SpotOrder(const ASymbol, ASide, AType, AQuantity, APrice, ATimeInForce,
  AClientOrderId: string): TToobitSpotOrder;
begin
  Result.Symbol := ASymbol;
  Result.Side := ASide;
  Result.OrderType := AType;
  Result.Quantity := AQuantity;
  Result.Price := APrice;
  Result.TimeInForce := ATimeInForce;
  Result.ClientOrderId := AClientOrderId;
end;

procedure OrderToParams(const O: TToobitSpotOrder; P: IToobitParams);
begin
  P.Add('symbol', O.Symbol).Add('side', O.Side).Add('type', O.OrderType)
   .AddIf('timeInForce', O.TimeInForce).Add('quantity', O.Quantity)
   .AddIf('price', O.Price).AddIf('newClientOrderId', O.ClientOrderId);
end;

function OrderToJson(const O: TToobitSpotOrder): string;
begin
  // compact JSON, no line breaks (required by the signing rules)
  Result := '{' + '"symbol":' + JsonQuote(O.Symbol) + ',"side":' + JsonQuote(O.Side) +
    ',"type":' + JsonQuote(O.OrderType);
  if O.TimeInForce <> '' then
    Result := Result + ',"timeInForce":' + JsonQuote(O.TimeInForce);
  Result := Result + ',"quantity":' + O.Quantity;
  if O.Price <> '' then
    Result := Result + ',"price":' + O.Price;
  Result := Result + ',"newClientOrderId":' + JsonQuote(O.ClientOrderId) + '}';
end;

function JoinStrings(const AItems: array of string): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to High(AItems) do
  begin
    if I > 0 then
      Result := Result + ',';
    Result := Result + AItems[I];
  end;
end;

{ TToobitSpotApi }

constructor TToobitSpotApi.Create(AClient: TToobitClient);
begin
  inherited Create;
  FClient := AClient;
end;

function TToobitSpotApi.Pub(const APath: string; AParams: IToobitParams): string;
begin
  Result := FClient.Request(hmGet, APath, AParams, tsNone);
end;

function TToobitSpotApi.Key(const APath: string; AParams: IToobitParams): string;
begin
  Result := FClient.Request(hmGet, APath, AParams, tsApiKey);
end;

function TToobitSpotApi.Sig(AMethod: TToobitHttpMethod; const APath: string;
  AParams: IToobitParams): string;
begin
  Result := FClient.Request(AMethod, APath, AParams, tsSigned);
end;

{ ---- market data ---- }

function TToobitSpotApi.ServerTime: string;
begin
  Result := Pub('/api/v1/time', nil);
end;

function TToobitSpotApi.ExchangeInfo: string;
begin
  Result := Pub('/api/v1/exchangeInfo', nil);
end;

function TToobitSpotApi.Depth(const ASymbol: string; ALimit: Integer): string;
begin
  Result := Pub('/quote/v1/depth', NewParams.Add('symbol', ASymbol).AddPos('limit', ALimit));
end;

function TToobitSpotApi.MergedDepth(const ASymbol: string; AScale, ALimit: Integer): string;
var
  P: IToobitParams;
begin
  P := NewParams.Add('symbol', ASymbol);
  if AScale >= 0 then
    P.Add('scale', AScale);
  P.AddPos('limit', ALimit);
  Result := Pub('/quote/v1/depth/merged', P);
end;

function TToobitSpotApi.Trades(const ASymbol: string; ALimit: Integer): string;
begin
  Result := Pub('/quote/v1/trades', NewParams.Add('symbol', ASymbol).AddPos('limit', ALimit));
end;

function TToobitSpotApi.Klines(const ASymbol, AInterval: string; AStartTime, AEndTime: Int64;
  ALimit: Integer): string;
begin
  Result := Pub('/quote/v1/klines', NewParams.Add('symbol', ASymbol).Add('interval', AInterval)
    .AddPos('startTime', AStartTime).AddPos('endTime', AEndTime).AddPos('limit', ALimit));
end;

function TToobitSpotApi.Ticker24h(const ASymbol: string): string;
begin
  Result := Pub('/quote/v1/ticker/24hr', NewParams.AddIf('symbol', ASymbol));
end;

function TToobitSpotApi.TickerPrice(const ASymbol: string): string;
begin
  Result := Pub('/quote/v1/ticker/price', NewParams.AddIf('symbol', ASymbol));
end;

function TToobitSpotApi.BookTicker(const ASymbol: string): string;
begin
  Result := Pub('/quote/v1/ticker/bookTicker', NewParams.AddIf('symbol', ASymbol));
end;

{ ---- trading ---- }

function TToobitSpotApi.TestOrder(const AOrder: TToobitSpotOrder): string;
var
  P: IToobitParams;
begin
  P := NewParams;
  OrderToParams(AOrder, P);
  Result := Sig(hmPost, '/api/v1/spot/orderTest', P);
end;

function TToobitSpotApi.NewOrder(const AOrder: TToobitSpotOrder): string;
var
  P: IToobitParams;
begin
  P := NewParams;
  OrderToParams(AOrder, P);
  Result := Sig(hmPost, '/api/v1/spot/order', P);
end;

function TToobitSpotApi.BatchOrders(const AOrders: array of TToobitSpotOrder): string;
var
  I: Integer;
  LBody: string;
begin
  if (Length(AOrders) = 0) or (Length(AOrders) > 20) then
    raise EToobitError.Create('BatchOrders accepts 1..20 orders.');
  LBody := '[';
  for I := 0 to High(AOrders) do
  begin
    if AOrders[I].ClientOrderId = '' then
      raise EToobitError.Create('Every batch order needs a ClientOrderId.');
    if I > 0 then
      LBody := LBody + ',';
    LBody := LBody + OrderToJson(AOrders[I]);
  end;
  LBody := LBody + ']';
  Result := FClient.Request(hmPost, '/api/v1/spot/batchOrders', nil, tsSigned, LBody);
end;

function TToobitSpotApi.CancelOrder(const AOrderId, AClientOrderId: string): string;
begin
  if (AOrderId = '') and (AClientOrderId = '') then
    raise EToobitError.Create('CancelOrder needs an order id or a client order id.');
  Result := Sig(hmDelete, '/api/v1/spot/order',
    NewParams.AddIf('orderId', AOrderId).AddIf('clientOrderId', AClientOrderId));
end;

function TToobitSpotApi.CancelAllOpenOrders(const ASymbol, ASide: string): string;
begin
  Result := Sig(hmDelete, '/api/v1/spot/openOrders',
    NewParams.AddIf('symbol', ASymbol).AddIf('side', ASide));
end;

function TToobitSpotApi.CancelOrdersByIds(const AOrderIds: array of string): string;
begin
  if (Length(AOrderIds) = 0) or (Length(AOrderIds) > 100) then
    raise EToobitError.Create('CancelOrdersByIds accepts 1..100 ids.');
  Result := Sig(hmDelete, '/api/v1/spot/cancelOrderByIds',
    NewParams.Add('ids', JoinStrings(AOrderIds)));
end;

{ ---- account ---- }

function TToobitSpotApi.QueryOrder(const AOrderId, AOrigClientOrderId: string): string;
begin
  if (AOrderId = '') and (AOrigClientOrderId = '') then
    raise EToobitError.Create('QueryOrder needs an order id or an original client order id.');
  Result := Sig(hmGet, '/api/v1/spot/order',
    NewParams.AddIf('orderId', AOrderId).AddIf('origClientOrderId', AOrigClientOrderId));
end;

function TToobitSpotApi.OpenOrders(const ASymbol, AOrderId: string; ALimit: Integer): string;
begin
  Result := Sig(hmGet, '/api/v1/spot/openOrders',
    NewParams.AddIf('orderId', AOrderId).AddIf('symbol', ASymbol).AddPos('limit', ALimit));
end;

function TToobitSpotApi.AllOrders(const ASymbol, AOrderId: string; AStartTime, AEndTime: Int64;
  ALimit: Integer): string;
begin
  Result := Sig(hmGet, '/api/v1/spot/tradeOrders',
    NewParams.AddIf('orderId', AOrderId).AddIf('symbol', ASymbol)
      .AddPos('startTime', AStartTime).AddPos('endTime', AEndTime).AddPos('limit', ALimit));
end;

function TToobitSpotApi.Account: string;
begin
  Result := Sig(hmGet, '/api/v1/account', nil);
end;

function TToobitSpotApi.AccountTrades(const ASymbol: string; AStartTime, AEndTime: Int64;
  const AFromId, AToId: string; ALimit: Integer): string;
begin
  Result := Sig(hmGet, '/api/v1/account/trades',
    NewParams.Add('symbol', ASymbol).AddPos('startTime', AStartTime).AddPos('endTime', AEndTime)
      .AddIf('fromId', AFromId).AddIf('toId', AToId).AddPos('limit', ALimit));
end;

function TToobitSpotApi.SubAccounts: string;
begin
  Result := Sig(hmGet, '/api/v1/account/subAccount', nil);
end;

function TToobitSpotApi.BalanceFlow(AAccountType: Integer; const ACoin: string; AFlowType: Integer;
  AStartTime, AEndTime: Int64; ALimit: Integer): string;
begin
  Result := Sig(hmGet, '/api/v1/account/balanceFlow',
    NewParams.AddPos('accountType', AAccountType).AddIf('coin', ACoin).AddPos('flowType', AFlowType)
      .AddPos('startTime', AStartTime).AddPos('endTime', AEndTime).AddPos('limit', ALimit));
end;

function TToobitSpotApi.CheckApiKey: string;
begin
  Result := Sig(hmGet, '/api/v1/account/checkApiKey', nil);
end;

function TToobitSpotApi.Transfer(const AFromUid, AToUid, AFromAccountType, AToAccountType, ACoin,
  AQuantity, ATransferId: string): string;
begin
  Result := Sig(hmPost, '/api/v1/subAccount/transfer',
    NewParams.AddIf('transferId', ATransferId).Add('fromUid', AFromUid).Add('toUid', AToUid)
      .Add('fromAccountType', AFromAccountType).Add('toAccountType', AToAccountType)
      .Add('coin', ACoin).Add('quantity', AQuantity));
end;

{ ---- wallet ---- }

function TToobitSpotApi.Withdraw(const ACoin, AClientOrderId, AAddress, AQuantity, AChainType,
  AAddressExt, AAddressType: string): string;
begin
  Result := Sig(hmPost, '/api/v1/account/withdraw',
    NewParams.Add('coin', ACoin).Add('clientOrderId', AClientOrderId).Add('address', AAddress)
      .AddIf('addressExt', AAddressExt).Add('quantity', AQuantity).AddIf('chainType', AChainType)
      .AddIf('addressType', AAddressType));
end;

function TToobitSpotApi.WithdrawOrders(const ACoin: string; AStartTime, AEndTime: Int64;
  ALimit: Integer): string;
begin
  Result := Sig(hmGet, '/api/v1/account/withdrawOrders',
    NewParams.AddIf('coin', ACoin).AddPos('startTime', AStartTime).AddPos('endTime', AEndTime)
      .AddPos('limit', ALimit));
end;

function TToobitSpotApi.DepositAddress(const ACoin, AChainType: string): string;
begin
  Result := Sig(hmGet, '/api/v1/account/deposit/address',
    NewParams.Add('coin', ACoin).Add('chainType', AChainType));
end;

function TToobitSpotApi.DepositOrders(const ACoin: string; AStartTime, AEndTime: Int64;
  ALimit: Integer): string;
begin
  Result := Sig(hmGet, '/api/v1/account/depositOrders',
    NewParams.AddIf('coin', ACoin).AddPos('startTime', AStartTime).AddPos('endTime', AEndTime)
      .AddPos('limit', ALimit));
end;

{ ---- listen key ---- }

function TToobitSpotApi.CreateListenKey: string;
begin
  // The docs list 'timestamp' as mandatory here, so the call is sent signed.
  Result := JsonField(Sig(hmPost, '/api/v1/userDataStream', nil), 'listenKey');
end;

procedure TToobitSpotApi.KeepAliveListenKey(const AListenKey: string);
begin
  Sig(hmPut, '/api/v1/userDataStream', NewParams.Add('listenKey', AListenKey));
end;

procedure TToobitSpotApi.CloseListenKey(const AListenKey: string);
begin
  Sig(hmDelete, '/api/v1/userDataStream', NewParams.Add('listenKey', AListenKey));
end;

end.
