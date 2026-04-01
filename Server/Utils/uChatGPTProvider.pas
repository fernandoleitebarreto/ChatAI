unit uChatGPTProvider;

interface

uses
  System.SysUtils, System.JSON,
  RESTRequest4D,
  uAIProvider,
  uAIModels;

type

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

implementation

{ TChatGPTProvider }

constructor TChatGPTProvider.Create(const AApiKey: string);
begin
  inherited Create(AApiKey);
  Model     := aptChatGPT.DefaultModel;
  MaxTokens := aptChatGPT.DefaultTokens;
end;

function TChatGPTProvider.GetBaseURL: string;
begin
  Result := aptChatGPT.BaseURL;
end;

function TChatGPTProvider.GetResource: string;
begin
  Result := aptChatGPT.Resource;
end;

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

end.
