unit uClaude;

/// //////////////////////////////////////////////////////////////////////////
{
  Unit uClaude
  Integration with the Anthropic API (Claude)
}
/// //////////////////////////////////////////////////////////////////////////

interface

uses
  System.SysUtils, System.Classes, System.JSON,
  RESTRequest4D;

type
  TClaude = class
  private
    FApiKey: string;
    FModel: string;
    FMaxTokens: Integer;
    FSystemPrompt: string;

    function BuildRequestBody(const APrompt: string): TJSONObject;
    function ParseResponse(const AJson: TJSONObject): TJSONObject;
  public
    constructor Create(const AApiKey: string);

    function Send(const APrompt: string): TJSONObject;

    property Model: string read FModel write FModel;
    property MaxTokens: Integer read FMaxTokens write FMaxTokens;
    property SystemPrompt: string read FSystemPrompt write FSystemPrompt;
  end;

implementation

const
  CLAUDE_API_URL = 'https://api.anthropic.com';
  CLAUDE_RESOURCE = 'v1/messages';
  CLAUDE_VERSION = '2023-06-01';
  DEFAULT_MODEL = 'claude-sonnet-4-20250514';
  DEFAULT_MAX_TOKENS = 1024;

  // Default system prompt that instructs Claude to return structured JSON
  // so that the client (FrmAI) can decide how to display it: text or table
  DEFAULT_SYSTEM_PROMPT =
    'You are a business intelligence assistant integrated into an ERP system. ' +
    'Always respond EXCLUSIVELY in JSON format, with no text outside the JSON ' +
    'and no markdown code blocks. ' +
    'The JSON must always contain the keys "type" and "data". ' +
    'Use "type": "text" when the answer is descriptive — in that case ' +
    '"data" must be a string. ' +
    'Use "type": "array" when the answer is a list/table — in that case ' +
    '"data" must be an array of JSON objects with the same keys in every item. ' +
    'Examples: ' +
    '{"type":"text","data":"Revenue grew 12% in the last quarter."} ' +
    '{"type":"array","data":[{"Product":"Widget","Sales":"150"},{"Product":"Gadget","Sales":"89"}]}';

  { TClaude }

constructor TClaude.Create(const AApiKey: string);
begin
  inherited Create;
  FApiKey := AApiKey;
  FModel := DEFAULT_MODEL;
  FMaxTokens := DEFAULT_MAX_TOKENS;
  FSystemPrompt := DEFAULT_SYSTEM_PROMPT;
end;

function TClaude.BuildRequestBody(const APrompt: string): TJSONObject;
var
  LMessages: TJSONArray;
  LMessage: TJSONObject;
begin
  // Build the request body according to the Anthropic Messages API
  // Docs: https://docs.anthropic.com/en/api/messages

  LMessages := TJSONArray.Create;

  LMessage := TJSONObject.Create;
  LMessage.AddPair('role', 'user');
  LMessage.AddPair('content', APrompt);
  LMessages.AddElement(LMessage);

  Result := TJSONObject.Create;
  Result.AddPair('model', FModel);
  Result.AddPair('max_tokens', TJSONNumber.Create(FMaxTokens));
  Result.AddPair('system', FSystemPrompt);
  Result.AddPair('messages', LMessages);
end;

function TClaude.ParseResponse(const AJson: TJSONObject): TJSONObject;
var
  LContent: TJSONArray;
  LFirstBlock: TJSONObject;
  LText: string;
  LParsed: TJSONValue;
begin
  // The API response has the format:
  // { "content": [ { "type": "text", "text": "..." } ], ... }

  LContent := AJson.GetValue<TJSONArray>('content');

  if (LContent = nil) or (LContent.Count = 0) then
    raise Exception.Create('Claude API response contains no content.');

  LFirstBlock := LContent.Items[0] as TJSONObject;
  LText := LFirstBlock.GetValue<string>('text');

  // The system prompt instructs Claude to return pure JSON.
  // Parse the received text into a TJSONObject.
  LParsed := TJSONObject.ParseJSONValue(LText);

  if not(LParsed is TJSONObject) then
  begin
    // Safety: if for any reason the response is not JSON, wrap it as text
    LParsed.Free;
    Result := TJSONObject.Create;
    Result.AddPair('type', 'text');
    Result.AddPair('data', LText);
  end
  else
    Result := LParsed as TJSONObject;
end;

function TClaude.Send(const APrompt: string): TJSONObject;
var
  LBody: TJSONObject;
  LResp: IResponse;
  LRespJson: TJSONObject;
begin
  LBody := BuildRequestBody(APrompt);
  try
    LResp := TRequest.New.BaseURL(CLAUDE_API_URL).Resource(CLAUDE_RESOURCE)
      .AddHeader('x-api-key', FApiKey).AddHeader('anthropic-version',
      CLAUDE_VERSION).AddHeader('content-type', 'application/json')
      .Accept('application/json').AddBody(LBody.ToJSON).Post;

    if LResp.StatusCode <> 200 then
      raise Exception.CreateFmt('Claude API error [HTTP %d]: %s',
        [LResp.StatusCode, LResp.Content]);

    LRespJson := TJSONObject.ParseJSONValue
      (TEncoding.UTF8.GetBytes(LResp.Content), 0) as TJSONObject;

    try
      Result := ParseResponse(LRespJson);
    finally
      LRespJson.Free;
    end;

  finally
    LBody.Free;
  end;
end;

end.
