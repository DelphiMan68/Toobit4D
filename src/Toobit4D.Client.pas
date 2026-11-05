unit Toobit4D.Client;
{$I Toobit4D.inc}

{ Core REST client: signing, headers, error mapping.
  HTTP is done with RESTRequest4Delphi (https://github.com/viniciussanchez/RESTRequest4Delphi). }

interface

uses
  SysUtils, RESTRequest4D, Toobit4D.Types, Toobit4D.Utils;

type
  TToobitClient = class
  private
    FApiKey: string;
    FSecretKey: string;
    FBaseUrl: string;
    FRecvWindow: Int64;
    FTimeOffset: Int64;
    FParamMode: TToobitParamMode;
    procedure RaiseHttpError(AStatus: Integer; const AContent: string);
  public
    constructor Create(const AApiKey: string = ''; const ASecretKey: string = '');

    { Low level entry point - every endpoint of the library goes through here.
      Use it directly for endpoints that have no wrapper yet (v2, copy trading, affiliate...).
      Returns the raw JSON text of the response body. }
    function Request(AMethod: TToobitHttpMethod; const APath: string;
      AParams: IToobitParams = nil; ASecurity: TToobitSecurity = tsNone;
      const ABodyJson: string = ''): string;

    { Milliseconds since epoch, corrected by the server offset (see SyncTime). }
    function NowMs: Int64;
    { Calls GET /api/v1/time and stores (serverTime - localTime). Returns the offset in ms. }
    function SyncTime: Int64;

    property ApiKey: string read FApiKey write FApiKey;
    property SecretKey: string read FSecretKey write FSecretKey;
    property BaseUrl: string read FBaseUrl write FBaseUrl;
    { Default 5000, the documented maximum is 60000. }
    property RecvWindow: Int64 read FRecvWindow write FRecvWindow;
    property TimeOffset: Int64 read FTimeOffset write FTimeOffset;
    property ParamMode: TToobitParamMode read FParamMode write FParamMode;
  end;

implementation

uses
  Toobit4D.Json;

constructor TToobitClient.Create(const AApiKey, ASecretKey: string);
begin
  inherited Create;
  FApiKey := AApiKey;
  FSecretKey := ASecretKey;
  FBaseUrl := TOOBIT_REST_URL;
  FRecvWindow := 5000;
  FTimeOffset := 0;
  FParamMode := pmAddParam;
end;

function TToobitClient.NowMs: Int64;
begin
  Result := ToobitUtcNowMs + FTimeOffset;
end;

function TToobitClient.SyncTime: Int64;
var
  LJson: string;
  LServer, LBefore, LAfter: Int64;
begin
  LBefore := ToobitUtcNowMs;
  LJson := Request(hmGet, '/api/v1/time');
  LAfter := ToobitUtcNowMs;
  LServer := StrToInt64Def(JsonField(LJson, 'serverTime'), 0);
  if LServer = 0 then
    raise EToobitError.Create('Unexpected /api/v1/time response: ' + LJson);
  // assume the server stamped the reply half-way through the round trip
  FTimeOffset := LServer - (LBefore + (LAfter - LBefore) div 2);
  Result := FTimeOffset;
end;

procedure TToobitClient.RaiseHttpError(AStatus: Integer; const AContent: string);
var
  LErr: EToobitHttpError;
  LCode, LMsg: string;
begin
  LCode := JsonField(AContent, 'code');
  LMsg := JsonField(AContent, 'msg');

  if AStatus = 429 then
    LErr := EToobitRateLimitError.Create('Toobit rate limit hit (HTTP 429). Back off before retrying.')
  else if AStatus >= 500 then
    LErr := EToobitServerError.Create(Format(
      'Toobit server error (HTTP %d). The execution status is UNKNOWN - verify the order/position before retrying. %s',
      [AStatus, LMsg]))
  else if LMsg <> '' then
    LErr := EToobitHttpError.Create(Format('Toobit API error %s: %s (HTTP %d)', [LCode, LMsg, AStatus]))
  else
    LErr := EToobitHttpError.Create(Format('Toobit HTTP error %d: %s', [AStatus, AContent]));

  LErr.StatusCode := AStatus;
  LErr.ApiCode := LCode;
  LErr.ApiMessage := LMsg;
  LErr.Content := AContent;
  raise LErr;
end;

function TToobitClient.Request(AMethod: TToobitHttpMethod; const APath: string;
  AParams: IToobitParams; ASecurity: TToobitSecurity; const ABodyJson: string): string;
var
  LReq: IRequest;
  LResp: IResponse;
  LUrl, LSig: string;
  I: Integer;
begin
  if AParams = nil then
    AParams := NewParams;

  if (ASecurity <> tsNone) and (FApiKey = '') then
    raise EToobitError.Create('This endpoint requires an API key.');

  if ASecurity = tsSigned then
  begin
    if FSecretKey = '' then
      raise EToobitError.Create('This endpoint requires a secret key.');
    if not AParams.Has('timestamp') then
      AParams.Add('timestamp', NowMs);
    if not AParams.Has('recvWindow') then
      AParams.Add('recvWindow', FRecvWindow);
    // string to sign = query/form parameters + raw JSON body (no separator);
    // 'signature' itself is never part of the signed text and is always last.
    LSig := HmacSha256Hex(FSecretKey, AParams.ToRaw + ABodyJson);
    AParams.Add('signature', LSig);
  end;

  if (FParamMode = pmInUrl) or (ABodyJson <> '') then
  begin
    LUrl := FBaseUrl + APath;
    if AParams.Count > 0 then
      LUrl := LUrl + '?' + AParams.ToEncoded;
    LReq := TRequest.New.BaseURL(LUrl);
  end
  else
  begin
    LReq := TRequest.New.BaseURL(FBaseUrl + APath);
    for I := 0 to AParams.Count - 1 do
      LReq.AddParam(AParams.Name(I), AParams.Value(I));
  end;

  if ASecurity <> tsNone then
    LReq.AddHeader('X-BB-APIKEY', FApiKey);
  LReq.Accept('application/json');

  case AMethod of
    hmGet:
      LResp := LReq.Get;
    hmPost:
      begin
        if ABodyJson <> '' then
          LReq.ContentType('application/json').AddBody(ABodyJson)
        else
          LReq.ContentType('application/x-www-form-urlencoded');
        LResp := LReq.Post;
      end;
    hmPut:
      begin
        LReq.ContentType('application/x-www-form-urlencoded');
        LResp := LReq.Put;
      end;
    hmDelete:
      LResp := LReq.Delete;
  end;

  Result := LResp.Content;
  if (LResp.StatusCode < 200) or (LResp.StatusCode >= 300) then
    RaiseHttpError(LResp.StatusCode, Result);
end;

end.
