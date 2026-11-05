unit Toobit4D.Futures;
{$I Toobit4D.inc}

{ USDT-M / USDC-M futures REST endpoints (API v1).
  Symbols look like BTC-SWAP-USDT. Set Category := TB_CATEGORY_USDC to work on the
  USDC-M account (it is added to every call that supports the 'category' parameter).
  '' = parameter not sent; for numeric optionals 0 (or -1) = not sent.
  All methods return the raw JSON text. }

interface

uses
  SysUtils, Toobit4D.Types, Toobit4D.Utils, Toobit4D.Client;

type
  TToobitFuturesOrder = record
    Symbol: string;
    Side: string;            // TB_SIDE_BUY_OPEN / SELL_OPEN / BUY_CLOSE / SELL_CLOSE
    OrderType: string;       // TB_TYPE_LIMIT or TB_TYPE_STOP
    Quantity: string;        // number of contracts
    ValueQuantity: string;   // alternative: order value in USDT (Quantity wins if both are set)
    Price: string;           // LIMIT + INPUT
    PriceType: string;       // TB_PRICE_INPUT / TB_PRICE_MARKET (market order = LIMIT + MARKET)
    StopPrice: string;       // required for STOP
    TimeInForce: string;     // GTC / FOK / IOC / POST_ONLY (LIMIT only)
    ClientOrderId: string;   // REQUIRED by the API
    TakeProfit: string;
    TpTriggerBy: string;
    TpLimitPrice: string;
    TpOrderType: string;
    StopLoss: string;
    SlTriggerBy: string;
    SlLimitPrice: string;
    SlOrderType: string;
  end;

  TToobitFuturesApi = class
  private
    FClient: TToobitClient;
    FCategory: string;
    function Pub(const APath: string; AParams: IToobitParams): string;
    function Sig(AMethod: TToobitHttpMethod; const APath: string; AParams: IToobitParams): string;
    function Cat(AParams: IToobitParams): IToobitParams;
  public
    constructor Create(AClient: TToobitClient);

    { '' = USDT-M (default), TB_CATEGORY_USDC = USDC-M }
    property Category: string read FCategory write FCategory;

    { ---- market data (public) ---- }
    function ServerTime: string;
    function ExchangeInfo: string;
    function Depth(const ASymbol: string; ALimit: Integer = 0): string;
    function MergedDepth(const ASymbol: string; AScale: Integer = -1; ALimit: Integer = 0): string;
    function Trades(const ASymbol: string; ALimit: Integer = 0): string;
    function Klines(const ASymbol, AInterval: string; AStartTime: Int64 = 0;
      AEndTime: Int64 = 0; ALimit: Integer = 0): string;
    function IndexKlines(const ASymbol, AInterval: string; AFrom, ATo: Int64; ALimit: Integer = 0): string;
    function IndexPriceComponents(const ASymbol: string): string;
    function MarkPriceKlines(const ASymbol, AInterval: string; AFrom, ATo: Int64; ALimit: Integer = 0): string;
    function MarkPrice(const ASymbol: string = ''): string;
    function FundingRate(const ASymbol: string = ''): string;
    function FundingRateHistory(const ASymbol: string; AFromId: Int64 = 0; AEndId: Int64 = 0;
      ALimit: Integer = 0): string;
    function OpenInterest(const ASymbol: string): string;
    { APeriod: 5m,15m,30m,1h,2h,4h,6h,12h,1d }
    function LongShortRatio(const ASymbol, APeriod: string; ALimit: Integer = 0;
      AStartTime: Int64 = 0; AEndTime: Int64 = 0): string;
    function InsuranceFund(const ASymbol: string): string;
    function RiskLimits(const ASymbol: string): string;
    { ARealtimeInterval: '', '24h', '1d', '1d+8' }
    function Ticker24h(const ASymbol: string = ''; const ARealtimeInterval: string = ''): string;
    function TickerPrice(const ASymbol: string = ''): string;
    function IndexPrice(const ASymbol: string = ''): string;
    function BookTicker(const ASymbol: string = ''): string;

    { ---- account settings (TRADE / USER_DATA) ---- }
    function ChangeMarginType(const ASymbol, AMarginType: string): string;
    function ChangeLeverage(const ASymbol: string; ALeverage: Integer): string;
    function AccountLeverage(const ASymbol: string): string;
    function SubAccounts(const AUserId: string = ''; const AEmail: string = ''): string;
    function Balance: string;
    function BalanceFlow(const ASymbol: string = ''; AFlowType: Integer = 0; AFromId: Int64 = 0;
      AEndId: Int64 = 0; AStartTime: Int64 = 0; AEndTime: Int64 = 0; ALimit: Integer = 0): string;
    function CommissionRate(const ASymbol: string): string;
    function TodayPnl: string;

    { ---- orders (TRADE / USER_DATA) ---- }
    function NewOrder(const AOrder: TToobitFuturesOrder): string;
    { Up to 10 orders, same symbol, JSON body. }
    function BatchOrders(const AOrders: array of TToobitFuturesOrder): string;
    function QueryOrder(const AOrderId: string; const AOrigClientOrderId: string = '';
      const AType: string = ''): string;
    { Basic modification (LIMIT / STOP). For trailing stops build the call yourself
      with TToobitClient.Request(hmPost, '/api/v1/futures/order/update', ...). }
    function ModifyOrder(const AType, AOrderId: string; const AOrigClientOrderId: string = '';
      const ANewClientOrderId: string = ''; const AQuantity: string = ''; const APrice: string = '';
      const APriceType: string = ''; const AStopPrice: string = ''; const ATriggerBy: string = ''): string;
    function CancelOrder(const AOrderId: string; const AOrigClientOrderId: string = '';
      const AType: string = ''; const ASymbol: string = ''): string;
    { Cancels all open orders of ASymbol on one side ('BUY' or 'SELL'). }
    function CancelOpenOrdersBySide(const ASymbol, ASide: string): string;
    { Up to 100 ids. }
    function CancelOrdersByIds(const AOrderIds: array of string): string;
    { AType: '' (LIMIT), TB_TYPE_STOP, 'STOP_PROFIT_LOSS' }
    function OpenOrders(const ASymbol: string = ''; const AOrderId: string = '';
      const AType: string = ''; ALimit: Integer = 0): string;
    function HistoryOrders(const ASymbol: string = ''; const AOrderId: string = '';
      const AType: string = ''; AStartTime: Int64 = 0; AEndTime: Int64 = 0; ALimit: Integer = 0): string;
    function UserTrades(const ASymbol: string; AStartTime: Int64 = 0; AEndTime: Int64 = 0;
      ALimit: Integer = 0; const AFromId: string = ''; const AToId: string = ''): string;

    { ---- positions ---- }
    function Positions(const ASymbol: string = ''; const ASide: string = ''): string;
    function HistoryPositions(const ASymbol: string = ''; const AMarginType: string = '';
      AFromId: Int64 = 0; AToId: Int64 = 0; AStartTime: Int64 = 0; AEndTime: Int64 = 0;
      ALimit: Integer = 0): string;
    { Fixed TP/SL: pass ATakeProfit / AStopLoss (+ sizes). Trailing: AStopType = 'TRAILING_STOP'
      with AFallbackType ('RATE'|'PRICE') and AFallbackQuantity. }
    function SetTradingStop(const ASymbol, ASide: string; const ATakeProfit: string = '';
      const AStopLoss: string = ''; const ATpTriggerBy: string = ''; const ASlTriggerBy: string = '';
      const ATpSize: string = ''; const ASlSize: string = ''; const AStopType: string = '';
      const AActivePrice: string = ''; const AFallbackType: string = '';
      const AFallbackQuantity: string = ''): string;
    function AutoAddMargin(const ASymbol, ASide: string; AEnable: Boolean; const AAmount: string = ''): string;
    function PositionMargin(const ASymbol, ASide, AAmount: string): string;
    function FlashClose(const ASymbol, ASide: string; const AClientOrderId: string = ''): string;
    function ReversePosition(const ASymbol, ASide: string; const AQuantity: string = ''): string;

    { ---- history files ---- }
    { ADownloadType: 'ORDER' | 'FUNDING' }
    function DownloadApply(const ADownloadType: string; AStartTime: Int64 = 0; AEndTime: Int64 = 0;
      const ASymbol: string = ''): string;
    function DownloadDetail(AId: Int64): string;

    { ---- user data stream (USER_STREAM) ---- }
    function CreateListenKey: string;      // returns the listenKey itself
    procedure KeepAliveListenKey(const AListenKey: string);
    procedure CloseListenKey(const AListenKey: string);
  end;

function FuturesLimitOrder(const ASymbol, ASide, AQuantity, APrice, AClientOrderId: string;
  const ATimeInForce: string = ''): TToobitFuturesOrder;
function FuturesMarketOrder(const ASymbol, ASide, AQuantity, AClientOrderId: string): TToobitFuturesOrder;

implementation

uses
  Toobit4D.Json;

procedure ClearOrder(var O: TToobitFuturesOrder);
begin
  O.Symbol := ''; O.Side := ''; O.OrderType := ''; O.Quantity := ''; O.ValueQuantity := '';
  O.Price := ''; O.PriceType := ''; O.StopPrice := ''; O.TimeInForce := ''; O.ClientOrderId := '';
  O.TakeProfit := ''; O.TpTriggerBy := ''; O.TpLimitPrice := ''; O.TpOrderType := '';
  O.StopLoss := ''; O.SlTriggerBy := ''; O.SlLimitPrice := ''; O.SlOrderType := '';
end;

function FuturesLimitOrder(const ASymbol, ASide, AQuantity, APrice, AClientOrderId,
  ATimeInForce: string): TToobitFuturesOrder;
begin
  ClearOrder(Result);
  Result.Symbol := ASymbol;
  Result.Side := ASide;
  Result.OrderType := TB_TYPE_LIMIT;
  Result.PriceType := TB_PRICE_INPUT;
  Result.Quantity := AQuantity;
  Result.Price := APrice;
  Result.ClientOrderId := AClientOrderId;
  Result.TimeInForce := ATimeInForce;
end;

function FuturesMarketOrder(const ASymbol, ASide, AQuantity, AClientOrderId: string): TToobitFuturesOrder;
begin
  // futures market order = type LIMIT + priceType MARKET
  ClearOrder(Result);
  Result.Symbol := ASymbol;
  Result.Side := ASide;
  Result.OrderType := TB_TYPE_LIMIT;
  Result.PriceType := TB_PRICE_MARKET;
  Result.Quantity := AQuantity;
  Result.ClientOrderId := AClientOrderId;
end;

procedure OrderToParams(const O: TToobitFuturesOrder; const ACategory: string; P: IToobitParams);
begin
  P.Add('symbol', O.Symbol).Add('side', O.Side).Add('type', O.OrderType)
   .AddIf('quantity', O.Quantity).AddIf('valueQuantity', O.ValueQuantity)
   .AddIf('price', O.Price).AddIf('priceType', O.PriceType).AddIf('stopPrice', O.StopPrice)
   .AddIf('timeInForce', O.TimeInForce).Add('newClientOrderId', O.ClientOrderId)
   .AddIf('takeProfit', O.TakeProfit).AddIf('tpTriggerBy', O.TpTriggerBy)
   .AddIf('tpLimitPrice', O.TpLimitPrice).AddIf('tpOrderType', O.TpOrderType)
   .AddIf('stopLoss', O.StopLoss).AddIf('slTriggerBy', O.SlTriggerBy)
   .AddIf('slLimitPrice', O.SlLimitPrice).AddIf('slOrderType', O.SlOrderType)
   .AddIf('category', ACategory);
end;

function OrderToJson(const O: TToobitFuturesOrder): string;
begin
  // compact JSON; batch body supports the basic order fields
  Result := '{"newClientOrderId":' + JsonQuote(O.ClientOrderId) +
    ',"symbol":' + JsonQuote(O.Symbol) + ',"side":' + JsonQuote(O.Side) +
    ',"type":' + JsonQuote(O.OrderType);
  if O.Price <> '' then Result := Result + ',"price":' + O.Price;
  if O.Quantity <> '' then Result := Result + ',"quantity":' + O.Quantity;
  if O.ValueQuantity <> '' then Result := Result + ',"valueQuantity":' + O.ValueQuantity;
  if O.PriceType <> '' then Result := Result + ',"priceType":' + JsonQuote(O.PriceType);
  if O.TimeInForce <> '' then Result := Result + ',"timeInForce":' + JsonQuote(O.TimeInForce);
  Result := Result + '}';
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

{ TToobitFuturesApi }

constructor TToobitFuturesApi.Create(AClient: TToobitClient);
begin
  inherited Create;
  FClient := AClient;
  FCategory := '';
end;

function TToobitFuturesApi.Pub(const APath: string; AParams: IToobitParams): string;
begin
  Result := FClient.Request(hmGet, APath, AParams, tsNone);
end;

function TToobitFuturesApi.Sig(AMethod: TToobitHttpMethod; const APath: string;
  AParams: IToobitParams): string;
begin
  Result := FClient.Request(AMethod, APath, AParams, tsSigned);
end;

function TToobitFuturesApi.Cat(AParams: IToobitParams): IToobitParams;
begin
  Result := AParams.AddIf('category', FCategory);
end;

{ ---- market data ---- }

function TToobitFuturesApi.ServerTime: string;
begin
  Result := Pub('/api/v1/time', nil);
end;

function TToobitFuturesApi.ExchangeInfo: string;
begin
  Result := Pub('/api/v1/exchangeInfo', nil);
end;

function TToobitFuturesApi.Depth(const ASymbol: string; ALimit: Integer): string;
begin
  Result := Pub('/quote/v1/depth', NewParams.Add('symbol', ASymbol).AddPos('limit', ALimit));
end;

function TToobitFuturesApi.MergedDepth(const ASymbol: string; AScale, ALimit: Integer): string;
var
  P: IToobitParams;
begin
  P := NewParams.Add('symbol', ASymbol);
  if AScale >= 0 then
    P.Add('scale', AScale);
  P.AddPos('limit', ALimit);
  Result := Pub('/quote/v1/depth/merged', P);
end;

function TToobitFuturesApi.Trades(const ASymbol: string; ALimit: Integer): string;
begin
  Result := Pub('/quote/v1/trades', NewParams.Add('symbol', ASymbol).AddPos('limit', ALimit));
end;

function TToobitFuturesApi.Klines(const ASymbol, AInterval: string; AStartTime, AEndTime: Int64;
  ALimit: Integer): string;
begin
  Result := Pub('/quote/v1/klines', NewParams.Add('symbol', ASymbol).Add('interval', AInterval)
    .AddPos('startTime', AStartTime).AddPos('endTime', AEndTime).AddPos('limit', ALimit));
end;

function TToobitFuturesApi.IndexKlines(const ASymbol, AInterval: string; AFrom, ATo: Int64;
  ALimit: Integer): string;
begin
  Result := Pub('/quote/v1/index/klines', NewParams.Add('symbol', ASymbol).Add('interval', AInterval)
    .Add('from', AFrom).Add('to', ATo).AddPos('limit', ALimit));
end;

function TToobitFuturesApi.IndexPriceComponents(const ASymbol: string): string;
begin
  Result := Pub('/quote/v1/indexPriceComponents', NewParams.Add('symbol', ASymbol));
end;

function TToobitFuturesApi.MarkPriceKlines(const ASymbol, AInterval: string; AFrom, ATo: Int64;
  ALimit: Integer): string;
begin
  Result := Pub('/quote/v1/markPrice/klines', NewParams.Add('symbol', ASymbol).Add('interval', AInterval)
    .Add('from', AFrom).Add('to', ATo).AddPos('limit', ALimit));
end;

function TToobitFuturesApi.MarkPrice(const ASymbol: string): string;
begin
  // documented limit: 5 requests / second
  Result := Pub('/quote/v1/markPrice', NewParams.AddIf('symbol', ASymbol));
end;

function TToobitFuturesApi.FundingRate(const ASymbol: string): string;
begin
  Result := Pub('/api/v1/futures/fundingRate', NewParams.AddIf('symbol', ASymbol));
end;

function TToobitFuturesApi.FundingRateHistory(const ASymbol: string; AFromId, AEndId: Int64;
  ALimit: Integer): string;
begin
  Result := Pub('/api/v1/futures/historyFundingRate', NewParams.Add('symbol', ASymbol)
    .AddPos('fromId', AFromId).AddPos('endId', AEndId).AddPos('limit', ALimit));
end;

function TToobitFuturesApi.OpenInterest(const ASymbol: string): string;
begin
  Result := Pub('/quote/v1/openInterest', NewParams.Add('symbol', ASymbol));
end;

function TToobitFuturesApi.LongShortRatio(const ASymbol, APeriod: string; ALimit: Integer;
  AStartTime, AEndTime: Int64): string;
begin
  Result := Pub('/quote/v1/globalLongShortAccountRatio', NewParams.Add('symbol', ASymbol)
    .Add('period', APeriod).AddPos('limit', ALimit).AddPos('startTime', AStartTime)
    .AddPos('endTime', AEndTime));
end;

function TToobitFuturesApi.InsuranceFund(const ASymbol: string): string;
begin
  Result := Pub('/api/v1/futures/insuranceBySymbol', NewParams.Add('symbol', ASymbol));
end;

function TToobitFuturesApi.RiskLimits(const ASymbol: string): string;
begin
  Result := Pub('/api/v1/futures/riskLimits', NewParams.Add('symbol', ASymbol));
end;

function TToobitFuturesApi.Ticker24h(const ASymbol, ARealtimeInterval: string): string;
begin
  Result := Pub('/quote/v1/contract/ticker/24hr',
    NewParams.AddIf('symbol', ASymbol).AddIf('realtimeInterval', ARealtimeInterval));
end;

function TToobitFuturesApi.TickerPrice(const ASymbol: string): string;
begin
  Result := Pub('/quote/v1/contract/ticker/price', NewParams.AddIf('symbol', ASymbol));
end;

function TToobitFuturesApi.IndexPrice(const ASymbol: string): string;
begin
  Result := Pub('/quote/v1/index', NewParams.AddIf('symbol', ASymbol));
end;

function TToobitFuturesApi.BookTicker(const ASymbol: string): string;
begin
  Result := Pub('/quote/v1/contract/ticker/bookTicker', NewParams.AddIf('symbol', ASymbol));
end;

{ ---- account settings ---- }

function TToobitFuturesApi.ChangeMarginType(const ASymbol, AMarginType: string): string;
begin
  Result := Sig(hmPost, '/api/v1/futures/marginType',
    Cat(NewParams.Add('symbol', ASymbol).Add('marginType', AMarginType)));
end;

function TToobitFuturesApi.ChangeLeverage(const ASymbol: string; ALeverage: Integer): string;
begin
  Result := Sig(hmPost, '/api/v1/futures/leverage',
    Cat(NewParams.Add('symbol', ASymbol).Add('leverage', ALeverage)));
end;

function TToobitFuturesApi.AccountLeverage(const ASymbol: string): string;
begin
  Result := Sig(hmGet, '/api/v1/futures/accountLeverage', Cat(NewParams.Add('symbol', ASymbol)));
end;

function TToobitFuturesApi.SubAccounts(const AUserId, AEmail: string): string;
begin
  Result := Sig(hmGet, '/api/v1/subAccount/list',
    NewParams.AddIf('userId', AUserId).AddIf('email', AEmail));
end;

function TToobitFuturesApi.Balance: string;
begin
  Result := Sig(hmGet, '/api/v1/futures/balance', Cat(NewParams));
end;

function TToobitFuturesApi.BalanceFlow(const ASymbol: string; AFlowType: Integer; AFromId, AEndId,
  AStartTime, AEndTime: Int64; ALimit: Integer): string;
begin
  Result := Sig(hmGet, '/api/v1/futures/balanceFlow',
    Cat(NewParams.AddIf('symbol', ASymbol).AddPos('flowType', AFlowType).AddPos('fromId', AFromId)
      .AddPos('endId', AEndId).AddPos('startTime', AStartTime).AddPos('endTime', AEndTime)
      .AddPos('limit', ALimit)));
end;

function TToobitFuturesApi.CommissionRate(const ASymbol: string): string;
begin
  Result := Sig(hmGet, '/api/v1/futures/commissionRate', NewParams.Add('symbol', ASymbol));
end;

function TToobitFuturesApi.TodayPnl: string;
begin
  Result := Sig(hmGet, '/api/v1/futures/todayPnl', Cat(NewParams));
end;

{ ---- orders ---- }

function TToobitFuturesApi.NewOrder(const AOrder: TToobitFuturesOrder): string;
var
  P: IToobitParams;
begin
  if AOrder.ClientOrderId = '' then
    raise EToobitError.Create('Futures orders need a ClientOrderId (newClientOrderId is mandatory).');
  P := NewParams;
  OrderToParams(AOrder, FCategory, P);
  Result := Sig(hmPost, '/api/v1/futures/order', P);
end;

function TToobitFuturesApi.BatchOrders(const AOrders: array of TToobitFuturesOrder): string;
var
  I: Integer;
  LBody: string;
begin
  if (Length(AOrders) = 0) or (Length(AOrders) > 10) then
    raise EToobitError.Create('BatchOrders accepts 1..10 orders.');
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
  Result := FClient.Request(hmPost, '/api/v1/futures/batchOrders',
    NewParams.AddIf('category', FCategory), tsSigned, LBody);
end;

function TToobitFuturesApi.QueryOrder(const AOrderId, AOrigClientOrderId, AType: string): string;
begin
  if (AOrderId = '') and (AOrigClientOrderId = '') then
    raise EToobitError.Create('QueryOrder needs an order id or an original client order id.');
  Result := Sig(hmGet, '/api/v1/futures/order',
    Cat(NewParams.AddIf('orderId', AOrderId).AddIf('origClientOrderId', AOrigClientOrderId)
      .AddIf('type', AType)));
end;

function TToobitFuturesApi.ModifyOrder(const AType, AOrderId, AOrigClientOrderId, ANewClientOrderId,
  AQuantity, APrice, APriceType, AStopPrice, ATriggerBy: string): string;
begin
  if (AOrderId = '') and (AOrigClientOrderId = '') then
    raise EToobitError.Create('ModifyOrder needs an order id or an original client order id.');
  Result := Sig(hmPost, '/api/v1/futures/order/update',
    Cat(NewParams.AddIf('orderId', AOrderId).AddIf('origClientOrderId', AOrigClientOrderId)
      .AddIf('newClientOrderId', ANewClientOrderId).Add('type', AType)
      .AddIf('quantity', AQuantity).AddIf('price', APrice).AddIf('priceType', APriceType)
      .AddIf('stopPrice', AStopPrice).AddIf('triggerBy', ATriggerBy)));
end;

function TToobitFuturesApi.CancelOrder(const AOrderId, AOrigClientOrderId, AType,
  ASymbol: string): string;
begin
  if (AOrderId = '') and (AOrigClientOrderId = '') then
    raise EToobitError.Create('CancelOrder needs an order id or an original client order id.');
  Result := Sig(hmDelete, '/api/v1/futures/order',
    Cat(NewParams.AddIf('orderId', AOrderId).AddIf('origClientOrderId', AOrigClientOrderId)
      .AddIf('type', AType).AddIf('symbol', ASymbol)));
end;

function TToobitFuturesApi.CancelOpenOrdersBySide(const ASymbol, ASide: string): string;
begin
  Result := Sig(hmDelete, '/api/v1/futures/batchOrders',
    Cat(NewParams.Add('symbol', ASymbol).Add('side', ASide)));
end;

function TToobitFuturesApi.CancelOrdersByIds(const AOrderIds: array of string): string;
begin
  if (Length(AOrderIds) = 0) or (Length(AOrderIds) > 100) then
    raise EToobitError.Create('CancelOrdersByIds accepts 1..100 ids.');
  Result := Sig(hmDelete, '/api/v1/futures/cancelOrderByIds',
    Cat(NewParams.Add('ids', JoinStrings(AOrderIds))));
end;

function TToobitFuturesApi.OpenOrders(const ASymbol, AOrderId, AType: string; ALimit: Integer): string;
begin
  Result := Sig(hmGet, '/api/v1/futures/openOrders',
    Cat(NewParams.AddIf('symbol', ASymbol).AddIf('orderId', AOrderId).AddIf('type', AType)
      .AddPos('limit', ALimit)));
end;

function TToobitFuturesApi.HistoryOrders(const ASymbol, AOrderId, AType: string; AStartTime,
  AEndTime: Int64; ALimit: Integer): string;
begin
  Result := Sig(hmGet, '/api/v1/futures/historyOrders',
    Cat(NewParams.AddIf('symbol', ASymbol).AddIf('orderId', AOrderId).AddIf('type', AType)
      .AddPos('startTime', AStartTime).AddPos('endTime', AEndTime).AddPos('limit', ALimit)));
end;

function TToobitFuturesApi.UserTrades(const ASymbol: string; AStartTime, AEndTime: Int64;
  ALimit: Integer; const AFromId, AToId: string): string;
begin
  Result := Sig(hmGet, '/api/v1/futures/userTrades',
    Cat(NewParams.Add('symbol', ASymbol).AddPos('startTime', AStartTime).AddPos('endTime', AEndTime)
      .AddPos('limit', ALimit).AddIf('fromId', AFromId).AddIf('toId', AToId)));
end;

{ ---- positions ---- }

function TToobitFuturesApi.Positions(const ASymbol, ASide: string): string;
begin
  Result := Sig(hmGet, '/api/v1/futures/positions',
    Cat(NewParams.AddIf('symbol', ASymbol).AddIf('side', ASide)));
end;

function TToobitFuturesApi.HistoryPositions(const ASymbol, AMarginType: string; AFromId, AToId,
  AStartTime, AEndTime: Int64; ALimit: Integer): string;
begin
  Result := Sig(hmGet, '/api/v1/futures/historyPositions',
    Cat(NewParams.AddIf('symbol', ASymbol).AddIf('marginType', AMarginType)
      .AddPos('fromId', AFromId).AddPos('toId', AToId).AddPos('startTime', AStartTime)
      .AddPos('endTime', AEndTime).AddPos('limit', ALimit)));
end;

function TToobitFuturesApi.SetTradingStop(const ASymbol, ASide, ATakeProfit, AStopLoss,
  ATpTriggerBy, ASlTriggerBy, ATpSize, ASlSize, AStopType, AActivePrice, AFallbackType,
  AFallbackQuantity: string): string;
begin
  Result := Sig(hmPost, '/api/v1/futures/position/trading-stop',
    Cat(NewParams.Add('symbol', ASymbol).Add('side', ASide).AddIf('takeProfit', ATakeProfit)
      .AddIf('stopLoss', AStopLoss).AddIf('tpTriggerBy', ATpTriggerBy)
      .AddIf('slTriggerBy', ASlTriggerBy).AddIf('tpSize', ATpSize).AddIf('slSize', ASlSize)
      .AddIf('stopType', AStopType).AddIf('activePrice', AActivePrice)
      .AddIf('fallbackType', AFallbackType).AddIf('fallbackQuantity', AFallbackQuantity)));
end;

function TToobitFuturesApi.AutoAddMargin(const ASymbol, ASide: string; AEnable: Boolean;
  const AAmount: string): string;
var
  P: IToobitParams;
begin
  P := NewParams.Add('symbol', ASymbol).Add('side', ASide);
  if AEnable then
    P.Add('enable', 'ON').AddIf('amount', AAmount)
  else
    P.Add('enable', 'OFF');
  Result := Sig(hmPost, '/api/v1/futures/autoAddMargin', P);
end;

function TToobitFuturesApi.PositionMargin(const ASymbol, ASide, AAmount: string): string;
begin
  Result := Sig(hmPost, '/api/v1/futures/positionMargin',
    Cat(NewParams.Add('symbol', ASymbol).Add('side', ASide).Add('amount', AAmount)));
end;

function TToobitFuturesApi.FlashClose(const ASymbol, ASide, AClientOrderId: string): string;
begin
  Result := Sig(hmPost, '/api/v1/futures/flashClose',
    Cat(NewParams.Add('symbol', ASymbol).Add('side', ASide).AddIf('clientOrderId', AClientOrderId)));
end;

function TToobitFuturesApi.ReversePosition(const ASymbol, ASide, AQuantity: string): string;
begin
  Result := Sig(hmPost, '/api/v1/futures/reversePosition',
    Cat(NewParams.Add('symbol', ASymbol).Add('side', ASide).AddIf('quantity', AQuantity)));
end;

{ ---- history files ---- }

function TToobitFuturesApi.DownloadApply(const ADownloadType: string; AStartTime, AEndTime: Int64;
  const ASymbol: string): string;
var
  P: IToobitParams;
begin
  P := NewParams.Add('downloadType', ADownloadType);
  if FCategory <> '' then
    P.Add('category', FCategory);   // this endpoint takes USDT | USDC
  P.AddPos('startTime', AStartTime).AddPos('endTime', AEndTime).AddIf('symbol', ASymbol);
  Result := Sig(hmPost, '/api/v1/account/download/apply', P);
end;

function TToobitFuturesApi.DownloadDetail(AId: Int64): string;
begin
  Result := Sig(hmGet, '/api/v1/account/download/detail', NewParams.Add('id', AId));
end;

{ ---- listen key ---- }

function TToobitFuturesApi.CreateListenKey: string;
begin
  Result := JsonField(Sig(hmPost, '/api/v1/listenKey', Cat(NewParams)), 'listenKey');
end;

procedure TToobitFuturesApi.KeepAliveListenKey(const AListenKey: string);
begin
  Sig(hmPut, '/api/v1/listenKey', Cat(NewParams.Add('listenKey', AListenKey)));
end;

procedure TToobitFuturesApi.CloseListenKey(const AListenKey: string);
begin
  Sig(hmDelete, '/api/v1/listenKey', Cat(NewParams.Add('listenKey', AListenKey)));
end;

end.
