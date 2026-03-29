unit uAIProvider;

interface

uses
  System.SysUtils, System.JSON,
  RESTRequest4D;

type

  // ---------------------------------------------------------------------------
  // Base interface for any AI provider
  // ---------------------------------------------------------------------------
  IAIProvider = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}']

    // Sends a prompt and returns JSON in the format:
    // { "type": "text"|"array", "data": ... }
    function Send(const APrompt: string): TJSONObject;

    // Common configuration getters and setters
    function GetModel: string;
    function GetMaxTokens: Integer;
    function GetSystemPrompt: string;
    procedure SetModel(const AValue: string);
    procedure SetMaxTokens(const AValue: Integer);
    procedure SetSystemPrompt(const AValue: string);

    property Model       : string  read GetModel        write SetModel;
    property MaxTokens   : Integer read GetMaxTokens    write SetMaxTokens;
    property SystemPrompt: string  read GetSystemPrompt write SetSystemPrompt;
  end;

  // ---------------------------------------------------------------------------
  // Abstract base class — implements the shared interface contract.
  // BuildRequestBody, ExtractTextFromResponse, GetBaseURL, GetResource and
  // AddHeaders are left abstract for each provider to specialise.
  // ---------------------------------------------------------------------------
  TAIProviderBase = class abstract(TInterfacedObject, IAIProvider)
  private
    FModel        : string;
    FMaxTokens    : Integer;
    FSystemPrompt : string;
    FApiKey       : string;

    function GetModel: string;
    function GetMaxTokens: Integer;
    function GetSystemPrompt: string;
    procedure SetModel(const AValue: string);
    procedure SetMaxTokens(const AValue: Integer);
    procedure SetSystemPrompt(const AValue: string);
  protected
    property ApiKey: string read FApiKey;

    // Each provider defines how to build the HTTP request body
    function BuildRequestBody(const APrompt: string): TJSONObject; virtual; abstract;

    // Each provider defines how to extract the text from the HTTP response
    function ExtractTextFromResponse(const AJson: TJSONObject): string; virtual; abstract;

    // Base URL and resource path for the provider endpoint
    function GetBaseURL: string; virtual; abstract;
    function GetResource: string; virtual; abstract;

    // Adds provider-specific HTTP headers (authentication, versioning, etc.)
    procedure AddHeaders(const ARequest: IRequest); virtual; abstract;

    // Parses the raw AI text into a structured TJSONObject:
    // { "type": "text"|"array", "data": ... }
    // Default behaviour: attempts JSON parse; falls back to a plain-text wrapper.
    // Can be overridden if needed.
    function ParseAIText(const AText: string): TJSONObject; virtual;
  public
    constructor Create(const AApiKey: string); virtual;

    function Send(const APrompt: string): TJSONObject;

    property Model       : string  read GetModel        write SetModel;
    property MaxTokens   : Integer read GetMaxTokens    write SetMaxTokens;
    property SystemPrompt: string  read GetSystemPrompt write SetSystemPrompt;
  end;

  // ---------------------------------------------------------------------------
  // OpenAI (ChatGPT) provider implementation
  // ---------------------------------------------------------------------------
  TChatGPTProvider = class(TAIProviderBase)
  protected
    function BuildRequestBody(const APrompt: string): TJSONObject; override;
    function ExtractTextFromResponse(const AJson: TJSONObject): string; override;
    function GetBaseURL: string; override;
    function GetResource: string; override;
    procedure AddHeaders(const ARequest: IRequest); override;
  public
    constructor Create(const AApiKey: string); override;
  end;

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

  // ---------------------------------------------------------------------------
  // Factory — creates the correct provider without the caller knowing the
  // concrete classes
  // ---------------------------------------------------------------------------
  TAIProviderType = (aptChatGPT, aptClaude);

  TAIProviderFactory = class
  public
    class function Create(const AType  : TAIProviderType;
                          const AApiKey: string): IAIProvider;
  end;

implementation

const
  // Shared system prompt: instructs any LLM to return JSON in the format
  // expected by the FrmIA client form
  SHARED_SYSTEM_PROMPT =
    'You are a business intelligence assistant integrated into an ERP system. ' +
    'Always respond EXCLUSIVELY in JSON format, with no text outside the JSON ' +
    'and no markdown code blocks. ' +
    'The JSON must always contain the keys "type" and "data". ' +
    'Use "type": "text" when the answer is descriptive — in that case "data" ' +
    'must be a string. ' +
    'Use "type": "array" when the answer is a list or table — in that case ' +
    '"data" must be a JSON array of objects that all share the same keys. ' +
    'Examples: ' +
    '{"type":"text","data":"Revenue grew 12% in the last quarter."} ' +
    '{"type":"array","data":[{"Product":"Widget","Sales":"150"},{"Product":"Gadget","Sales":"89"}]}';

  // ChatGPT endpoint
  CHATGPT_BASE_URL   = 'https://api.openai.com';
  CHATGPT_RESOURCE   = 'v1/chat/completions';
  CHATGPT_DEF_MODEL  = 'gpt-4o';
  CHATGPT_DEF_TOKENS = 1024;

  // Claude endpoint
  CLAUDE_BASE_URL    = 'https://api.anthropic.com';
  CLAUDE_RESOURCE    = 'v1/messages';
  CLAUDE_API_VERSION = '2023-06-01';
  CLAUDE_DEF_MODEL   = 'claude-sonnet-4-20250514';
  CLAUDE_DEF_TOKENS  = 1024;

{ TAIProviderBase }

constructor TAIProviderBase.Create(const AApiKey: string);
begin
  inherited Create;
  FApiKey       := AApiKey;
  FSystemPrompt := SHARED_SYSTEM_PROMPT;
end;

function TAIProviderBase.GetModel: string;        begin Result := FModel;        end;
function TAIProviderBase.GetMaxTokens: Integer;   begin Result := FMaxTokens;    end;
function TAIProviderBase.GetSystemPrompt: string; begin Result := FSystemPrompt; end;

procedure TAIProviderBase.SetModel(const AValue: string);        begin FModel        := AValue; end;
procedure TAIProviderBase.SetMaxTokens(const AValue: Integer);   begin FMaxTokens    := AValue; end;
procedure TAIProviderBase.SetSystemPrompt(const AValue: string); begin FSystemPrompt := AValue; end;

function TAIProviderBase.ParseAIText(const AText: string): TJSONObject;
var
  LParsed: TJSONValue;
begin
  LParsed := TJSONObject.ParseJSONValue(AText);

  if LParsed is TJSONObject then
    Result := LParsed as TJSONObject
  else
  begin
    // Safety fallback: the AI did not return valid JSON — wrap as plain text
    LParsed.Free;
    Result := TJSONObject.Create;
    Result.AddPair('type', 'text');
    Result.AddPair('data', AText);
  end;
end;

function TAIProviderBase.Send(const APrompt: string): TJSONObject;
var
  LBody    : TJSONObject;
  LRequest : IRequest;
  LResp    : IResponse;
  LRespJson: TJSONObject;
  LText    : string;
begin
  LBody := BuildRequestBody(APrompt);
  try
    LRequest := TRequest.New
      .BaseURL(GetBaseURL)
      .Resource(GetResource)
      .Accept('application/json')
      .AddBody(LBody.ToJSON);

    AddHeaders(LRequest);

    LResp := LRequest.Post;

    if LResp.StatusCode <> 200 then
      raise Exception.CreateFmt(
        'API error [HTTP %d]: %s',
        [LResp.StatusCode, LResp.Content]
      );

    LRespJson := TJSONObject.ParseJSONValue(
      TEncoding.UTF8.GetBytes(LResp.Content), 0
    ) as TJSONObject;

    try
      LText  := ExtractTextFromResponse(LRespJson);
      Result := ParseAIText(LText);
    finally
      LRespJson.Free;
    end;

  finally
    LBody.Free;
  end;
end;

{ TChatGPTProvider }

constructor TChatGPTProvider.Create(const AApiKey: string);
begin
  inherited Create(AApiKey);
  FModel     := CHATGPT_DEF_MODEL;
  FMaxTokens := CHATGPT_DEF_TOKENS;
end;

function TChatGPTProvider.GetBaseURL: string;  begin Result := CHATGPT_BASE_URL; end;
function TChatGPTProvider.GetResource: string; begin Result := CHATGPT_RESOURCE; end;

procedure TChatGPTProvider.AddHeaders(const ARequest: IRequest);
begin
  ARequest
    .AddHeader('Authorization', 'Bearer ' + ApiKey)
    .AddHeader('Content-Type',  'application/json');
end;

function TChatGPTProvider.BuildRequestBody(const APrompt: string): TJSONObject;
var
  LMessages: TJSONArray;
  LSystem  : TJSONObject;
  LUser    : TJSONObject;
begin
  LMessages := TJSONArray.Create;

  LSystem := TJSONObject.Create;
  LSystem.AddPair('role',    'system');
  LSystem.AddPair('content', FSystemPrompt);
  LMessages.AddElement(LSystem);

  LUser := TJSONObject.Create;
  LUser.AddPair('role',    'user');
  LUser.AddPair('content', APrompt);
  LMessages.AddElement(LUser);

  Result := TJSONObject.Create;
  Result.AddPair('model',      FModel);
  Result.AddPair('max_tokens', TJSONNumber.Create(FMaxTokens));
  Result.AddPair('messages',   LMessages);
end;

function TChatGPTProvider.ExtractTextFromResponse(const AJson: TJSONObject): string;
var
  LChoices: TJSONArray;
  LMessage: TJSONObject;
begin
  // Response format: { "choices": [ { "message": { "content": "..." } } ] }
  LChoices := AJson.GetValue<TJSONArray>('choices');

  if (LChoices = nil) or (LChoices.Count = 0) then
    raise Exception.Create('ChatGPT API response does not contain choices.');

  LMessage := (LChoices.Items[0] as TJSONObject).GetValue<TJSONObject>('message');
  Result   := LMessage.GetValue<string>('content');
end;

{ TClaudeProvider }

constructor TClaudeProvider.Create(const AApiKey: string);
begin
  inherited Create(AApiKey);
  FModel     := CLAUDE_DEF_MODEL;
  FMaxTokens := CLAUDE_DEF_TOKENS;
end;

function TClaudeProvider.GetBaseURL: string;  begin Result := CLAUDE_BASE_URL; end;
function TClaudeProvider.GetResource: string; begin Result := CLAUDE_RESOURCE; end;

procedure TClaudeProvider.AddHeaders(const ARequest: IRequest);
begin
  ARequest
    .AddHeader('x-api-key',         ApiKey)
    .AddHeader('anthropic-version', CLAUDE_API_VERSION)
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
  Result.AddPair('model',      FModel);
  Result.AddPair('max_tokens', TJSONNumber.Create(FMaxTokens));
  Result.AddPair('system',     FSystemPrompt);
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

{ TAIProviderFactory }

class function TAIProviderFactory.Create(const AType  : TAIProviderType;
                                         const AApiKey: string): IAIProvider;
begin
  case AType of
    aptChatGPT: Result := TChatGPTProvider.Create(AApiKey);
    aptClaude : Result := TClaudeProvider.Create(AApiKey);
  else
    raise Exception.Create('Unknown AI provider type.');
  end;
end;

end.
