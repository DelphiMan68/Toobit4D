unit Toobit4D.Json;
{$I Toobit4D.inc}

{ Tiny JSON helpers so the rest of the library does not care whether it is
  built with System.JSON (Delphi) or fpjson (FreePascal). }

interface

uses
  SysUtils;

{ Returns the top-level field AKey of a JSON object as text.
  Nested objects/arrays are returned as JSON text. '' if missing or invalid. }
function JsonField(const AJson, AKey: string): string;

{ Very fast scan for the first  "AKey":"value"  pair (string values only).
  No parsing - used on the hot WebSocket path for topic/symbol detection. }
function JsonQuickString(const AJson, AKey: string): string;

{ JSON string literal incl. quotes, with escaping. }
function JsonQuote(const S: string): string;

implementation

uses
  {$IFDEF FPC} fpjson, jsonparser {$ELSE} System.JSON {$ENDIF};

function JsonField(const AJson, AKey: string): string;
{$IFDEF FPC}
var
  LData, LField: TJSONData;
begin
  Result := '';
  if AJson = '' then Exit;
  try
    LData := GetJSON(AJson);
  except
    Exit;
  end;
  try
    if LData is TJSONObject then
    begin
      LField := TJSONObject(LData).Find(AKey);
      if LField <> nil then
        case LField.JSONType of
          jtNull: Result := '';
          jtObject, jtArray: Result := LField.AsJSON;
        else
          Result := LField.AsString;
        end;
    end;
  finally
    LData.Free;
  end;
end;
{$ELSE}
var
  LValue, LField: TJSONValue;
begin
  Result := '';
  if AJson = '' then Exit;
  LValue := TJSONObject.ParseJSONValue(AJson);
  if LValue = nil then Exit;
  try
    if LValue is TJSONObject then
    begin
      LField := TJSONObject(LValue).Values[AKey];
      if (LField <> nil) and not (LField is TJSONNull) then
      begin
        if LField is TJSONString then   // TJSONNumber derives from TJSONString
          Result := TJSONString(LField).Value
        else
          Result := LField.ToString;
      end;
    end;
  finally
    LValue.Free;
  end;
end;
{$ENDIF}

function JsonQuickString(const AJson, AKey: string): string;
var
  LNeedle: string;
  P, L: Integer;
begin
  Result := '';
  LNeedle := '"' + AKey + '"';
  P := Pos(LNeedle, AJson);
  if P = 0 then Exit;
  Inc(P, Length(LNeedle));
  L := Length(AJson);
  while (P <= L) and (AJson[P] in [' ', #9, #13, #10]) do Inc(P);
  if (P > L) or (AJson[P] <> ':') then Exit;
  Inc(P);
  while (P <= L) and (AJson[P] in [' ', #9, #13, #10]) do Inc(P);
  if (P > L) or (AJson[P] <> '"') then Exit;
  Inc(P);
  while (P <= L) and (AJson[P] <> '"') do
  begin
    Result := Result + AJson[P];
    Inc(P);
  end;
end;

function JsonQuote(const S: string): string;
var
  I: Integer;
  C: Char;
begin
  Result := '"';
  for I := 1 to Length(S) do
  begin
    C := S[I];
    case C of
      '"':  Result := Result + '\"';
      '\':  Result := Result + '\\';
      #8:   Result := Result + '\b';
      #9:   Result := Result + '\t';
      #10:  Result := Result + '\n';
      #12:  Result := Result + '\f';
      #13:  Result := Result + '\r';
    else
      if C < ' ' then
        Result := Result + '\u' + IntToHex(Ord(C), 4)
      else
        Result := Result + C;
    end;
  end;
  Result := Result + '"';
end;

end.
