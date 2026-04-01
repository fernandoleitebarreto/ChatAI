unit uAIModels;
interface
uses
  System.SysUtils;
type
  // ---------------------------------------------------------------------------
  // Provider type enum and helper
  // ---------------------------------------------------------------------------
  TAIProviderType = (aptChatGPT, aptClaude);
  TAIProviderTypeHelper = record helper for TAIProviderType
    function Name: string;
    function BaseURL: string;
    function Resource: string;
    function DefaultModel: string;
    function DefaultTokens: Integer;
    function ApiVersion: string;
    class function Default: TAIProviderType; static;
    class function FromName(const AName: string): TAIProviderType; static;
  end;

  // ---------------------------------------------------------------------------
  // OpenAI (ChatGPT) models
  // ---------------------------------------------------------------------------
  TChatGPTModel = (cgmGPT4o, cgmGPT4oMini, cgmGPT4Turbo, cgmO3Mini);
  TChatGPTModelHelper = record helper for TChatGPTModel
    function Name: string;
    function ApiName: string;
    class function Default: TChatGPTModel; static;
    class function FromApiName(const AName: string): TChatGPTModel; static;
  end;

  // ---------------------------------------------------------------------------
  // Anthropic (Claude) models
  // ---------------------------------------------------------------------------
  TClaudeModel = (cmSonnet4, cmOpus4, cmHaiku35);
  TClaudeModelHelper = record helper for TClaudeModel
    function Name: string;
    function ApiName: string;
    class function Default: TClaudeModel; static;
    class function FromApiName(const AName: string): TClaudeModel; static;
  end;

implementation

{ TAIProviderTypeHelper }
function TAIProviderTypeHelper.Name: string;
begin
  case Self of
    aptChatGPT: Result := 'ChatGPT';
    aptClaude : Result := 'Claude';
  else
    Result := 'Unknown';
  end;
end;

function TAIProviderTypeHelper.BaseURL: string;
begin
  case Self of
    aptChatGPT: Result := 'https://api.openai.com';
    aptClaude : Result := 'https://api.anthropic.com';
  else
    Result := '';
  end;
end;

function TAIProviderTypeHelper.Resource: string;
begin
  case Self of
    aptChatGPT: Result := 'v1/chat/completions';
    aptClaude : Result := 'v1/messages';
  else
    Result := '';
  end;
end;

class function TAIProviderTypeHelper.Default: TAIProviderType;
begin
  Result := aptClaude;
end;

function TAIProviderTypeHelper.DefaultModel: string;
begin
  case Self of
    aptChatGPT: Result := TChatGPTModel.Default.ApiName;
    aptClaude : Result := TClaudeModel.Default.ApiName;
  else
    Result := '';
  end;
end;

function TAIProviderTypeHelper.DefaultTokens: Integer;
begin
  Result := 1024;
end;

function TAIProviderTypeHelper.ApiVersion: string;
begin
  case Self of
    aptClaude: Result := '2023-06-01';
  else
    Result := '';
  end;
end;

class function TAIProviderTypeHelper.FromName(const AName: string): TAIProviderType;
begin
  if SameText(AName, 'ChatGPT')
    then Result := aptChatGPT
  else if SameText(AName, 'Claude')
    then Result := aptClaude
  else
    raise Exception.CreateFmt('Unknown AI provider name: "%s"', [AName]);
end;

{ TChatGPTModelHelper }
function TChatGPTModelHelper.Name: string;
begin
  case Self of
    cgmGPT4o     : Result := 'GPT-4o';
    cgmGPT4oMini : Result := 'GPT-4o Mini';
    cgmGPT4Turbo : Result := 'GPT-4 Turbo';
    cgmO3Mini    : Result := 'o3-mini';
  else
    Result := 'Unknown';
  end;
end;

function TChatGPTModelHelper.ApiName: string;
begin
  case Self of
    cgmGPT4o     : Result := 'gpt-4o';
    cgmGPT4oMini : Result := 'gpt-4o-mini';
    cgmGPT4Turbo : Result := 'gpt-4-turbo';
    cgmO3Mini    : Result := 'o3-mini';
  else
    Result := '';
  end;
end;

class function TChatGPTModelHelper.Default: TChatGPTModel;
begin
  Result := cgmGPT4o;
end;

class function TChatGPTModelHelper.FromApiName(const AName: string): TChatGPTModel;
begin
  if SameText(AName, 'gpt-4o')
    then Result := cgmGPT4o
  else if SameText(AName, 'gpt-4o-mini')
    then Result := cgmGPT4oMini
  else if SameText(AName, 'gpt-4-turbo')
    then Result := cgmGPT4Turbo
  else if SameText(AName, 'o3-mini')
    then Result := cgmO3Mini
  else
    raise Exception.CreateFmt('Unknown ChatGPT model: "%s"', [AName]);
end;

{ TClaudeModelHelper }
function TClaudeModelHelper.Name: string;
begin
  case Self of
    cmSonnet4 : Result := 'Claude Sonnet 4';
    cmOpus4   : Result := 'Claude Opus 4';
    cmHaiku35 : Result := 'Claude Haiku 3.5';
  else
    Result := 'Unknown';
  end;
end;

function TClaudeModelHelper.ApiName: string;
begin
  case Self of
    cmSonnet4 : Result := 'claude-sonnet-4-20250514';
    cmOpus4   : Result := 'claude-opus-4-20250514';
    cmHaiku35 : Result := 'claude-3-5-haiku-20241022';
  else
    Result := '';
  end;
end;

class function TClaudeModelHelper.Default: TClaudeModel;
begin
  Result := cmHaiku35;
end;

class function TClaudeModelHelper.FromApiName(const AName: string): TClaudeModel;
begin
  if SameText(AName, 'claude-sonnet-4-20250514')
    then Result := cmSonnet4
  else if SameText(AName, 'claude-opus-4-20250514')
    then Result := cmOpus4
  else if SameText(AName, 'claude-3-5-haiku-20241022')
    then Result := cmHaiku35
  else
    raise Exception.CreateFmt('Unknown Claude model: "%s"', [AName]);
end;

end.
