unit Dm.Geral;

interface

uses
  System.SysUtils, System.Classes, FireDAC.Stan.Intf, FireDAC.Stan.Option,
  FireDAC.Stan.Error, FireDAC.UI.Intf, FireDAC.Phys.Intf, FireDAC.Stan.Def,
  FireDAC.Stan.Pool, FireDAC.Stan.Async, FireDAC.Phys, FireDAC.Phys.SQLite,
  FireDAC.Phys.SQLiteDef, FireDAC.Stan.ExprFuncs,
  FireDAC.Phys.SQLiteWrapper.Stat, FireDAC.VCLUI.Wait, Data.DB,
  FireDAC.Comp.Client, DataSet.Serialize.Config,
  DataSet.Serialize, System.JSON, uChatGPT, FireDAC.DApt;

type
  TDm = class(TDataModule)
    Conn: TFDConnection;
    procedure DataModuleCreate(Sender: TObject);
  private
    function MontaQueryIA(prompt: string): string;
    function ExecutarQuery(ssql: string): TJsonArray;
    function InterpretarResultado(prompt: string; dados: TJsonArray): string;
  public
    function ProcessarPrompt(prompt: string): TJSONObject;
  end;

var
  Dm: TDm;

Const
  OPENAI_KEY = 'sua api keu aqui...';

implementation

{%CLASSGROUP 'Vcl.Controls.TControl'}

{$R *.dfm}

procedure TDm.DataModuleCreate(Sender: TObject);
begin
  TDataSetSerializeConfig.GetInstance.CaseNameDefinition := cndLower;
  TDataSetSerializeConfig.GetInstance.Import.DecimalSeparator := '.';

  Conn.DriverName := 'SQLite';
  Conn.Params.Values['Database'] := System.SysUtils.GetCurrentDir +
                                    '\banco.db';

  Conn.Connected := true;
end;

function Tdm.MontaQueryIA(prompt: string): string;
var
  ChatGPT: TChatGPT;
  json_retorno, system_prompt: string;
begin
  try
    ChatGPT := TChatGPT.Create(OPENAI_KEY, 'gpt-4o-mini');

    system_prompt := 'Você é um assistente de banco de dados especialista em SQLite. ' +
    'Sua tarefa é interpretar perguntas do usuário e gerar apenas ' +
    'um comando SQL válido para SQLite. ' +
    'Use o seguinte schema para escrever os comandos SQL: ' +
    '- cliente (id_cliente, nome, cidade, uf). ' +
    '- produto (id_produto, descricao, preco).' +
    '- pedido (id_pedido, dt_pedido, vl_total, id_cliente).' +
    '- pedido_item (id_item, id_pedido, id_produto, qtd, vl_unitario, vl_total). ' +
    'Regras:' +
    'Devolva apenas o comando SQL puro.' +
    'Não use markdown.' +
    'Não explique nada.' +
    'Não escreva texto antes ou depois da query.' +
    'Não invente tabelas ou colunas.' +
    'Sempre que a pergunta envolver "fora do padrão", "anormal", "suspeito", "erro", ' +
    '  "fraude" ou "muito acima dos demais", trate isso como detecção de outlier.' +
    'Quando a pergunta for se "existe" algum caso, retorne os registros encontrados, ' +
    ' e não apenas verdadeiro/falso.' +
    'Se a pergunta for ambígua, escolha a interpretação mais útil para análise operacional.' +
    'Exemplo de análise outlier: "Existe algum pedido com quantidade fora do padrão dos demais pedidos?"' +
    '  SQL: SELECT pi.id_pedido, pi.id_produto, pi.qtd, ' +
    '       (SELECT AVG(qtd) FROM pedido_item) AS media_qtd ' +
    '       FROM pedido_item pi WHERE pi.qtd > ( ' +
    '                       SELECT AVG(qtd) * 3 ' +
    '                       FROM pedido_item);' +
    '';

    ChatGPT.AddSystem(system_prompt);
    ChatGPT.AddUser(prompt);

    Result := ChatGPT.Send(json_retorno);
  finally
    FreeAndNil(ChatGPT);
  end;
end;

function Tdm.ExecutarQuery(ssql: string): TJsonArray;
var
    qry: TFDQuery;
begin
    try
        qry := TFDQuery.Create(nil);
        qry.Connection := Conn;

        with qry do
        begin
            Active := false;
            SQL.Clear;
            SQL.Add(ssql);
            Active := true;
        end;

        Result := qry.ToJsonArray;

    finally
        qry.Free;
    end;
end;

function Tdm.InterpretarResultado(prompt: string; dados: TJsonArray): string;
var
  ChatGPT: TChatGPT;
  json: string;
begin
  ChatGPT := TChatGPT.Create(OPENAI_KEY, 'gpt-4o-mini');

  try
    ChatGPT.AddSystem(
      'Você recebe o resultado de uma consulta SQL e deve responder em linguagem natural.'
    );

    ChatGPT.AddUser(
      'Pergunta do usuário: ' + prompt + sLineBreak +
      'Resultado da consulta: ' + dados.ToJSON
    );

    Result := ChatGPT.Send(json);

  finally
    ChatGPT.Free;
  end;
end;

function Tdm.ProcessarPrompt(prompt: string): TJSONObject;
var
  sql: string;
  dados: TJsonArray;
  resposta: TJSONObject;
  texto: string;
begin
  sql := MontaQueryIA(prompt);

  dados := ExecutarQuery(sql);

  resposta := TJSONObject.Create;

  if dados.Count > 1 then
  begin
      resposta.AddPair('tipo', 'array');
      resposta.AddPair('dados', dados);
  end
  else
  begin
    texto := InterpretarResultado(prompt, dados);

    resposta.AddPair('tipo', 'texto');
    resposta.AddPair('dados', texto);

    dados.Free;
  end;

  resposta.AddPair('sql', sql); // retirar qdo for p/ producao....
  Result := resposta;
end;

end.
