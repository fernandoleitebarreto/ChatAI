unit uClaude;

/// //////////////////////////////////////////////////////////////////////////
{
  Unit uClaude
  Integração com a API da Anthropic (Claude)
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

    function Enviar(const APrompt: string): TJSONObject;

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

  // System prompt padrão que instrui o Claude a retornar JSON estruturado
  // para que o cliente (FrmIA) possa decidir como exibir: texto ou tabela
  DEFAULT_SYSTEM_PROMPT =
    'Você é um assistente de análise gerencial integrado a um sistema ERP. ' +
    'Sempre responda EXCLUSIVAMENTE em formato JSON, sem texto fora do JSON, ' +
    'sem blocos de código markdown. ' +
    'O JSON deve ter obrigatoriamente a chave "tipo" e a chave "dados". ' +
    'Use "tipo": "texto" quando a resposta for um texto descritivo — nesse caso '
    + '"dados" deve ser uma string. ' +
    'Use "tipo": "array" quando a resposta for uma lista/tabela — nesse caso ' +
    '"dados" deve ser um array de objetos JSON com as mesmas chaves em todos os itens. '
    + 'Exemplos: ' +
    '{"tipo":"texto","dados":"O faturamento cresceu 12% no último trimestre."} '
    + '{"tipo":"array","dados":[{"Produto":"Widget","Vendas":"150"},{"Produto":"Gadget","Vendas":"89"}]}';

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
  // Monta o corpo da requisição conforme a API Messages da Anthropic
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
  // A resposta da API tem o formato:
  // { "content": [ { "type": "text", "text": "..." } ], ... }

  LContent := AJson.GetValue<TJSONArray>('content');

  if (LContent = nil) or (LContent.Count = 0) then
    raise Exception.Create('Resposta da API do Claude não contém conteúdo.');

  LFirstBlock := LContent.Items[0] as TJSONObject;
  LText := LFirstBlock.GetValue<string>('text');

  // O system prompt instrui o Claude a retornar JSON puro.
  // Faz o parse do texto recebido para TJSONObject.
  LParsed := TJSONObject.ParseJSONValue(LText);

  if not(LParsed is TJSONObject) then
  begin
    // Segurança: se por algum motivo não vier JSON, encapsula como texto
    LParsed.Free;
    Result := TJSONObject.Create;
    Result.AddPair('tipo', 'texto');
    Result.AddPair('dados', LText);
  end
  else
    Result := LParsed as TJSONObject;
end;

function TClaude.Enviar(const APrompt: string): TJSONObject;
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
      raise Exception.CreateFmt('Erro na API do Claude [HTTP %d]: %s',
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
