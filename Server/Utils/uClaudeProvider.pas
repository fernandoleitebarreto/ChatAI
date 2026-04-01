unit uClaudeProvider;

interface

uses
  System.SysUtils, System.JSON,
  RESTRequest4D,
  uAIProvider,
  uAIModels;

type

  // ---------------------------------------------------------------------------
  // Anthropic (Claude) provider implementation
  // ---------------------------------------------------------------------------
  TClaudeProvider = class(TAIProviderBase)
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

{ TClaudeProvider }

constructor TClaudeProvider.Create(const AApiKey: string);
begin
  inherited Create(AApiKey);
  Model     := aptClaude.DefaultModel;
  MaxTokens := aptClaude.DefaultTokens;
end;

function TClaudeProvider.GetBaseURL: string;
begin
  Result := aptClaude.BaseURL;
end;

function TClaudeProvider.GetResource: string;
begin
  Result := aptClaude.Resource;
end;

procedure TClaudeProvider.AddHeaders(const ARequest: IRequest);
begin
  ARequest
    .AddHeader('x-api-key',         ApiKey)
    .AddHeader('anthropic-version', aptClaude.ApiVersion)
    .AddHeader('Content-Type',      'application/json');
end;

function TClaudeProvider.BuildRequestBody(const APrompt: string): TJSONObject;
var
  LMessages: TJSONArray;
  LUser    : TJSONObject;
begin
  LMessages := TJSONArray.Create;

  LUser := TJSONObject.Create;
  LUser.AddPair('role',    'user');
  LUser.AddPair('content', APrompt);
  LMessages.AddElement(LUser);

  // Claude receives the system prompt as a top-level field, not inside messages
  Result := TJSONObject.Create;
  Result.AddPair('model',      Model);
  Result.AddPair('max_tokens', TJSONNumber.Create(MaxTokens));
  Result.AddPair('system',     SystemPrompt);
  Result.AddPair('messages',   LMessages);
end;

function TClaudeProvider.ExtractTextFromResponse(const AJson: TJSONObject): string;
var
  LContent   : TJSONArray;
  LFirstBlock: TJSONObject;
begin
  // Response format: { "content": [ { "type": "text", "text": "..." } ] }
  LContent := AJson.GetValue<TJSONArray>('content');

  if (LContent = nil) or (LContent.Count = 0) then
    raise Exception.Create('Claude API response does not contain content blocks.');

  LFirstBlock := LContent.Items[0] as TJSONObject;
  Result      := LFirstBlock.GetValue<string>('text');
end;

end.
