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

    // Retorna o conteúdo da resposta do assistant e, opcionalmente, o JSON bruto
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
-- PARAMETRO TEMPERATURE -------------------------------------------------------
Vai de 0 a 2. Onde:
Valores mais baixos (0.0 a 0.3): Use quando você quer respostas claras
e consistentes, como em situações que exigem precisão ou informações técnicas.

Valores médios (0.4 a 0.7): Proporcionam um bom equilíbrio entre criatividade
e previsibilidade, útil para a maioria das aplicações, como artigos ou respostas
de suporte.

Valores mais altos (0.8 a 1.0): Ideais para quando você deseja que o modelo
seja mais exploratório e menos restrito, útil para tarefas como geração
de poesia, ficção, ou ideias criativas.


-- PARAMETRO MAXTOKENS  --------------------------------------------------------
O parametro max_tokens define o máximo de tokens que a resposta da API pode conter.
Um token é um pedaço de texto (geralmente 3–4 caracteres em média).

Respostas curtas (ex: título, frase): max_tokens = 50–100
Respostas médias (ex: parágrafo, resumo): max_tokens = 200–400
Respostas longas (ex: texto, código): max_tokens = 1000–2000

Se deixar 0, nenhum limite será utilizado
}

constructor TChatGPT.Create(const AApiKey, AModel: string);
begin
  inherited Create;
  FApiKey := AApiKey;
  FModel := AModel;
  FTemperature := 0.7;
  FMaxTokens := 0;            // 0 = não envia o campo
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

    // Clona o array de mensagens para evitar que o Free do body libere FMessages
    msgsClone := FMessages.Clone as TJSONValue;
    body.AddPair('messages', msgsClone);

    // Campos opcionais
    if FTemperature >= 0 then
      body.AddPair('temperature', TJSONNumber.Create(FTemperature));
    if FMaxTokens > 0 then
      body.AddPair('max_tokens', TJSONNumber.Create(FMaxTokens));

    Result := body.ToJSON;
  finally
    body.Free; // msgsClone é liberado aqui, o FMessages original permanece
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
        raise Exception.Create('Resposta JSON inválida');

      Choices := JO.GetValue('choices') as TJSONArray;
      if (Choices = nil) or (Choices.Count = 0) then
        raise Exception.Create('Sem choices na resposta');

      Choice := Choices.Items[0] as TJSONObject;
      Msg := Choice.GetValue('message') as TJSONObject;
      if (Msg = nil) or (Msg.GetValue('content') = nil) then
        raise Exception.Create('Resposta sem message.content');

      Result := Msg.GetValue('content').Value;

      // Opcional: já adiciona a resposta ao histórico
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

