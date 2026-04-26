unit uAIProvider;

interface

uses
  System.SysUtils, System.JSON,
  RESTRequest4D,
  uAIModels,
  uAIProviderIntf;

type

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
  // Factory — creates the correct provider without the caller knowing the
  // concrete classes
  // ---------------------------------------------------------------------------
  TAIProviderFactory = class
  public
    class function Create(const AType  : TAIProviderType;
                          const AApiKey: string): IAIProvider;
  end;

implementation

uses
  uChatGPTProvider, uClaudeProvider, uQwenProvider;

const
  // Shared system prompt: instructs any LLM to return JSON in the format
  // expected by the FrmAI client form
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


{ TAIProviderBase }

constructor TAIProviderBase.Create(const AApiKey: string);
begin
  inherited Create;
  FApiKey       := AApiKey;
  FSystemPrompt := SHARED_SYSTEM_PROMPT;
end;

function TAIProviderBase.GetModel: string;
begin
  Result := FModel;
end;

function TAIProviderBase.GetMaxTokens: Integer;
begin
  Result := FMaxTokens;
end;

function TAIProviderBase.GetSystemPrompt: string;
begin
  Result := FSystemPrompt;
end;

procedure TAIProviderBase.SetModel(const AValue: string);
begin
  FModel := AValue;
end;

procedure TAIProviderBase.SetMaxTokens(const AValue: Integer);
begin
  FMaxTokens := AValue;
end;

procedure TAIProviderBase.SetSystemPrompt(const AValue: string);
begin
  FSystemPrompt := AValue;
end;

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

{ TAIProviderFactory }

class function TAIProviderFactory.Create(const AType  : TAIProviderType;
                                         const AApiKey: string): IAIProvider;
begin
  case AType of
    aptChatGPT: Result := TChatGPTProvider.Create(AApiKey);
    aptClaude : Result := TClaudeProvider.Create(AApiKey);
    aptQwen   : Result := TQwenProvider.Create(AApiKey);
  else
    raise Exception.Create('Unknown AI provider type.');
  end;
end;

end.
