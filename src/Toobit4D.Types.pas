unit Toobit4D.Types;
{$I Toobit4D.inc}

interface

uses
  SysUtils;

const
  TOOBIT_REST_URL       = 'https://api.toobit.com';
  TOOBIT_WS_HOST        = 'wss://stream.toobit.com';
  TOOBIT_WS_MARKET_URL  = TOOBIT_WS_HOST + '/quote/ws/v1';
  TOOBIT_WS_USER_URL    = TOOBIT_WS_HOST + '/api/v1/ws/';   // + listenKey

  // ---- order side -------------------------------------------------------
  TB_SIDE_BUY        = 'BUY';         // spot / futures v2
  TB_SIDE_SELL       = 'SELL';
  TB_SIDE_BUY_OPEN   = 'BUY_OPEN';    // futures v1
  TB_SIDE_SELL_OPEN  = 'SELL_OPEN';
  TB_SIDE_BUY_CLOSE  = 'BUY_CLOSE';
  TB_SIDE_SELL_CLOSE = 'SELL_CLOSE';

  // ---- order type -------------------------------------------------------
  TB_TYPE_LIMIT       = 'LIMIT';
  TB_TYPE_MARKET      = 'MARKET';       // spot only; futures market = LIMIT + priceType MARKET
  TB_TYPE_LIMIT_MAKER = 'LIMIT_MAKER';
  TB_TYPE_STOP        = 'STOP';         // futures plan order

  // ---- time in force ----------------------------------------------------
  TB_TIF_GTC       = 'GTC';
  TB_TIF_IOC       = 'IOC';
  TB_TIF_FOK       = 'FOK';
  TB_TIF_POST_ONLY = 'POST_ONLY';

  // ---- futures misc -----------------------------------------------------
  TB_PRICE_INPUT     = 'INPUT';
  TB_PRICE_MARKET    = 'MARKET';
  TB_MARGIN_CROSS    = 'CROSS';
  TB_MARGIN_ISOLATED = 'ISOLATED';
  TB_POS_LONG        = 'LONG';
  TB_POS_SHORT       = 'SHORT';
  TB_TRIGGER_MARK    = 'MARK_PRICE';
  TB_TRIGGER_LAST    = 'CONTRACT_PRICE';
  TB_CATEGORY_USDC   = 'USDC';          // default (empty) = USDT-M

  // ---- account types (transfer) ----------------------------------------
  TB_ACC_MAIN         = 'MAIN';
  TB_ACC_FUTURES      = 'FUTURES';
  TB_ACC_FUTURES_USDC = 'FUTURES_USDC';
  TB_ACC_COPY_TRADING = 'COPY_TRADING';

  // ---- kline intervals --------------------------------------------------
  TB_INT_1M  = '1m';  TB_INT_3M = '3m';  TB_INT_5M = '5m';  TB_INT_15M = '15m';
  TB_INT_30M = '30m'; TB_INT_1H = '1h';  TB_INT_2H = '2h';  TB_INT_4H  = '4h';
  TB_INT_6H  = '6h';  TB_INT_8H = '8h';  TB_INT_12H = '12h'; TB_INT_1D = '1d';
  TB_INT_1W  = '1w';  TB_INT_1MO = '1M';

type
  TToobitHttpMethod = (hmGet, hmPost, hmPut, hmDelete);

  { tsNone   = public endpoint
    tsApiKey = X-BB-APIKEY header only (MARKET_DATA / USER_STREAM)
    tsSigned = header + timestamp + recvWindow + HMAC-SHA256 signature (TRADE / USER_DATA) }
  TToobitSecurity = (tsNone, tsApiKey, tsSigned);

  { How query/form parameters are handed to RESTRequest4Delphi.
    pmAddParam : request.AddParam(name, value) in order (default)
    pmInUrl    : the full query string is built by Toobit4D and appended to the URL
    Requests that carry a JSON body always use pmInUrl. }
  TToobitParamMode = (pmAddParam, pmInUrl);

  EToobitError = class(Exception);

  EToobitHttpError = class(EToobitError)
  public
    StatusCode: Integer;
    ApiCode: string;      // "code" field of the error JSON, if any
    ApiMessage: string;   // "msg" field of the error JSON, if any
    Content: string;      // raw response body
  end;

  { HTTP 429 - back off. }
  EToobitRateLimitError = class(EToobitHttpError);

  { HTTP 5xx - per the Toobit docs the execution status is UNKNOWN (the request
    may have succeeded). Query the order/position before retrying. }
  EToobitServerError = class(EToobitHttpError);

  EToobitWsError = class(EToobitError);

implementation

end.
