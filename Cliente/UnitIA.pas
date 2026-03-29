unit UnitIA;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.Memo.Types,
  System.Rtti, FMX.Grid.Style, FMX.Grid, FMX.StdCtrls, FMX.Objects,
  FMX.ScrollBox, FMX.Memo, FMX.Controls.Presentation, FMX.Layouts,
  FMX.TabControl, uLoading, RESTRequest4D, System.JSON;

type
  TFrmIA = class(TForm)
    TabControl: TTabControl;
    TabItem1: TTabItem;
    Layout1: TLayout;
    Label1: TLabel;
    mPrompt: TMemo;
    Image1: TImage;
    Label2: TLabel;
    Layout2: TLayout;
    Rectangle3: TRectangle;
    btnEnviar: TSpeedButton;
    TabItem2: TTabItem;
    Layout3: TLayout;
    lblTexto: TLabel;
    Image2: TImage;
    Layout4: TLayout;
    Rectangle4: TRectangle;
    btnVoltar1: TSpeedButton;
    TabItem3: TTabItem;
    Layout5: TLayout;
    Rectangle1: TRectangle;
    SpeedButton1: TSpeedButton;
    Grid: TStringGrid;
    procedure FormShow(Sender: TObject);
    procedure btnEnviarClick(Sender: TObject);
    procedure btnVoltar1Click(Sender: TObject);
    procedure SpeedButton1Click(Sender: TObject);
  private
    retorno: TJSONObject;
    procedure ProcessarAnalise(prompt: string);
    procedure TerminateIA(Sender: TObject);
    procedure MontarLista(Grid: TStringGrid; Dados: TJSONArray);
    { Private declarations }
  public
    { Public declarations }
  end;

var
  FrmIA: TFrmIA;

implementation

{$R *.fmx}

procedure TFrmIA.ProcessarAnalise(prompt: string);
var
  resp: IResponse;
  json: TJSONObject;
begin
  try
    json := TJSONObject.Create;
    json.AddPair('prompt', prompt);

    resp := TRequest.New.BaseURL('http://localhost:3001')
                        .Resource('prompts')
                        .AddBody(json.ToJSON)
                        .Accept('application/json')
                        .Post;

    if resp.StatusCode <> 200 then
        raise Exception.Create(resp.Content);

    retorno := TJSONObject.ParseJSONValue(TEncoding.UTF8.GetBytes(resp.Content), 0) as TJSONObject;

  finally
    json.Free;
  end;
end;

procedure TFrmIA.SpeedButton1Click(Sender: TObject);
begin
  TabControl.GotoVisibleTab(0);
end;

procedure TFrmIA.MontarLista(Grid: TStringGrid; Dados: TJSONArray);
var
  i, j: Integer;
  Obj: TJSONObject;
  Pair: TJSONPair;
  Col: TStringColumn;
begin
  if (Dados = nil) or (Dados.Count = 0) then
    Exit;

  Grid.BeginUpdate;
  try
    Grid.ClearColumns;

    Obj := Dados.Items[0] as TJSONObject;

    // cria colunas dinamicamente
    for Pair in Obj do
    begin
      Col := TStringColumn.Create(Grid);
      Col.Header := Pair.JsonString.Value;
      Col.Stored := False;
      Grid.AddObject(Col);
    end;

    Grid.RowCount := Dados.Count;

    // preenche as linhas
    for i := 0 to Dados.Count - 1 do
    begin
      Obj := Dados.Items[i] as TJSONObject;
      j := 0;

      for Pair in Obj do
      begin
        Grid.Cells[j, i] := Pair.JsonValue.Value;
        Inc(j);
      end;
    end;

  finally
    Grid.EndUpdate;
  end;
end;

procedure TFrmIA.TerminateIA(Sender: TObject);
begin
  TLoading.Hide;

  if Assigned(TThread(Sender).FatalException) then
  begin
    showmessage(Exception(TThread(sender).FatalException).Message);
    exit;
  end;

  // Analise do resultado...
  if retorno.GetValue<string>('tipo', '') = 'texto' then
  begin
    lblTexto.Text := retorno.GetValue<string>('dados', '');
    TabControl.GotoVisibleTab(1);
  end

  else if retorno.GetValue<string>('tipo', '') = 'array' then
  begin
    MontarLista(Grid, retorno.GetValue<TJSONArray>('dados'));
    TabControl.GotoVisibleTab(2);
  end;

end;

procedure TFrmIA.btnEnviarClick(Sender: TObject);
begin
  TLoading.Show(FrmIA);

  TLoading.ExecuteThread(procedure
  begin
    ProcessarAnalise(mPrompt.Text);
  end, TerminateIA);
end;

procedure TFrmIA.btnVoltar1Click(Sender: TObject);
begin
  TabControl.GotoVisibleTab(0);
end;

procedure TFrmIA.FormShow(Sender: TObject);
begin
  TabControl.ActiveTab := TabItem1;
end;

end.
