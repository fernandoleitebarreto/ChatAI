unit uQwenProvider;

interface

uses
  System.SysUtils, System.JSON,
  RESTRequest4D,
  uAIProvider,
  uAIModels;

type

  // ---------------------------------------------------------------------------
  // Qwen (via OpenRouter) provider implementation
  // Uses OpenAI-compatible Chat Completions format
  // ---------------------------------------------------------------------------
  TQwenProvider = class(TAIProviderBase)
  protected
    function BuildRequestBody(const APrompt: string): TJSONObject; override;
    function ExtractTextFromResponse(const AJson: TJSONObject): string; override;
    function GetBaseURL: string; override;
    function GetResource: string; override;
    procedure AddHeaders(const ARequest: IRequest); override;
  public
    constructor Create(const AApiKey: string); override;
  end;

implementation

{ TQwenProvider }

constructor TQwenProvider.Create(const AApiKey: string);
begin
  inherited Create(AApiKey);
  Model     := aptQwen.DefaultModel;
  MaxTokens := aptQwen.DefaultTokens;
end;

function TQwenProvider.GetBaseURL: string;
begin
  Result := aptQwen.BaseURL;
end;

function TQwenProvider.GetResource: string;
begin
  Result := aptQwen.Resource;
end;

procedure TQwenProvider.AddHeaders(const ARequest: IRequest);
begin
  ARequest
    .AddHeader('x-api-key',    ApiKey)
    .AddHeader('qwen-version', aptQwen.ApiVersion)
    .AddHeader('Content-Type', 'application/json');
end;

function TQwenProvider.BuildRequestBody(const APrompt: string): TJSONObject;
var
  LMessages: TJSONArray;
  LSystem  : TJSONObject;
  LUser    : TJSONObject;
begin
  LMessages := TJSONArray.Create;

  LSystem := TJSONObject.Create;
  LSystem.AddPair('role',    'system');
  LSystem.AddPair('content', SystemPrompt);
  LMessages.AddElement(LSystem);

  LUser := TJSONObject.Create;
  LUser.AddPair('role',    'user');
  LUser.AddPair('content', APrompt);
  LMessages.AddElement(LUser);

  Result := TJSONObject.Create;
  Result.AddPair('model',      Model);
  Result.AddPair('max_tokens', TJSONNumber.Create(MaxTokens));
  Result.AddPair('messages',   LMessages);
end;

function TQwenProvider.ExtractTextFromResponse(const AJson: TJSONObject): string;
var
  LChoices: TJSONArray;
  LMessage: TJSONObject;
begin
  // OpenAI-compatible response format: { "choices": [ { "message": { "content": "..." } } ] }
  LChoices := AJson.GetValue<TJSONArray>('choices');

  if (LChoices = nil) or (LChoices.Count = 0) then
    raise Exception.Create('Qwen API response does not contain choices.');

  LMessage := (LChoices.Items[0] as TJSONObject).GetValue<TJSONObject>('message');
  Result   := LMessage.GetValue<string>('content');
end;

end.
