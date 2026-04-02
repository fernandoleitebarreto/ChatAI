unit uChatGPT;

interface

uses
  System.SysUtils, System.Classes, System.JSON,
  System.Net.URLClient, System.Net.HttpClient;

type
  TChatGPT = class
  private
    FApiKey: string;
    FModel: string;
    FTemperature: Double;
    FMaxTokens: Integer;
    FMessages: TJSONArray;

    function BuildBodyJSON: string;
  public
    constructor Create(const AApiKey: string; const AModel: string = 'gpt-4o-mini');
    destructor Destroy; override;

    procedure ClearHistory;
    procedure AddSystem(const Content: string);
    procedure AddUser(const Content: string);
    procedure AddAssistant(const Content: string);

    // Returns the assistant response content and, optionally, the raw JSON
    function Send(out RawJSON: string): string; overload;
    function Send: string; overload;

    property Model: string read FModel write FModel;
    property Temperature: Double read FTemperature write FTemperature;      // 0..2
    property MaxTokens: Integer read FMaxTokens write FMaxTokens;            // 0 = omite
  end;

implementation

const
  CHAT_URL = 'https://api.openai.com/v1/chat/completions';


{
-- TEMPERATURE PARAMETER -------------------------------------------------------
Ranges from 0 to 2:
Lower values (0.0 to 0.3): Use when you want clear and consistent responses,
such as situations requiring precision or technical information.

Medium values (0.4 to 0.7): Provide a good balance between creativity and
predictability, useful for most applications like articles or support responses.

Higher values (0.8 to 1.0): Ideal when you want the model to be more
exploratory and less constrained, useful for tasks like poetry, fiction,
or creative idea generation.


-- MAXTOKENS PARAMETER ---------------------------------------------------------
The max_tokens parameter defines the maximum number of tokens the API response
can contain. A token is a piece of text (typically 3-4 characters on average).

Short responses (e.g. title, sentence): max_tokens = 50-100
Medium responses (e.g. paragraph, summary): max_tokens = 200-400
Long responses (e.g. text, code): max_tokens = 1000-2000

If set to 0, no limit will be applied.
}

constructor TChatGPT.Create(const AApiKey, AModel: string);
begin
  inherited Create;
  FApiKey := AApiKey;
  FModel := AModel;
  FTemperature := 0.7;
  FMaxTokens := 0;            // 0 = field is omitted
  FMessages := TJSONArray.Create;
end;

destructor TChatGPT.Destroy;
begin
  FMessages.Free;
  inherited;
end;

procedure TChatGPT.ClearHistory;
begin
  FMessages.Free;
  FMessages := TJSONArray.Create;
end;

procedure TChatGPT.AddSystem(const Content: string);
var o: TJSONObject;
begin
  o := TJSONObject.Create;
  o.AddPair('role', 'system');
  o.AddPair('content', Content);
  FMessages.AddElement(o);
end;

procedure TChatGPT.AddUser(const Content: string);
var o: TJSONObject;
begin
  o := TJSONObject.Create;
  o.AddPair('role', 'user');
  o.AddPair('content', Content);
  FMessages.AddElement(o);
end;

procedure TChatGPT.AddAssistant(const Content: string);
var o: TJSONObject;
begin
  o := TJSONObject.Create;
  o.AddPair('role', 'assistant');
  o.AddPair('content', Content);
  FMessages.AddElement(o);
end;

function TChatGPT.BuildBodyJSON: string;
var
  body: TJSONObject;
  msgsClone: TJSONValue;
begin
  body := TJSONObject.Create;
  try
    body.AddPair('model', FModel);

    // Clone the messages array so that freeing body does not free FMessages
    msgsClone := FMessages.Clone as TJSONValue;
    body.AddPair('messages', msgsClone);

    // Optional fields
    if FTemperature >= 0 then
      body.AddPair('temperature', TJSONNumber.Create(FTemperature));
    if FMaxTokens > 0 then
      body.AddPair('max_tokens', TJSONNumber.Create(FMaxTokens));

    Result := body.ToJSON;
  finally
    body.Free; // msgsClone is freed here; the original FMessages remains
  end;
end;

function TChatGPT.Send(out RawJSON: string): string;
var
  Http: THTTPClient;
  Resp: IHTTPResponse;
  SBody, SResp: string;
  JO, Choice, Msg: TJSONObject;
  Choices: TJSONArray;
  LStream: TStringStream;
begin
  Result := '';
  RawJSON := '';

  SBody := BuildBodyJSON;

  Http := THTTPClient.Create;
  try
    Http.ConnectionTimeout := 30000;
    Http.ResponseTimeout := 30000;
    Http.CustomHeaders['Authorization'] := 'Bearer ' + FApiKey;
    Http.CustomHeaders['Content-Type'] := 'application/json';

    LStream := TStringStream.Create(SBody, TEncoding.UTF8);
    try
      Resp := Http.Post(CHAT_URL, LStream);
    finally
      LStream.Free;
    end;

    SResp := Resp.ContentAsString(TEncoding.UTF8);
    RawJSON := SResp;

    if Resp.StatusCode <> 200 then
      raise Exception.CreateFmt('HTTP %d: %s', [Resp.StatusCode, SResp]);

    JO := TJSONObject(TJSONObject.ParseJSONValue(SResp));
    try
      if not Assigned(JO) then
        raise Exception.Create('Invalid JSON response');

      Choices := JO.GetValue('choices') as TJSONArray;
      if (Choices = nil) or (Choices.Count = 0) then
        raise Exception.Create('No choices in response');

      Choice := Choices.Items[0] as TJSONObject;
      Msg := Choice.GetValue('message') as TJSONObject;
      if (Msg = nil) or (Msg.GetValue('content') = nil) then
        raise Exception.Create('Response missing message.content');

      Result := Msg.GetValue('content').Value;

      // Optional: automatically add the response to the conversation history
      AddAssistant(Result);
    finally
      JO.Free;
    end;
  finally
    Http.Free;
  end;
end;

function TChatGPT.Send: string;
var Dummy: string;
begin
  Result := Send(Dummy);
end;

end.

