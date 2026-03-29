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
    btnSend: TSpeedButton;
    TabItem2: TTabItem;
    Layout3: TLayout;
    lblText: TLabel;
    Image2: TImage;
    Layout4: TLayout;
    Rectangle4: TRectangle;
    btnBack1: TSpeedButton;
    TabItem3: TTabItem;
    Layout5: TLayout;
    Rectangle1: TRectangle;
    SpeedButton1: TSpeedButton;
    Grid: TStringGrid;
    procedure FormShow(Sender: TObject);
    procedure btnSendClick(Sender: TObject);
    procedure btnBack1Click(Sender: TObject);
    procedure SpeedButton1Click(Sender: TObject);
  private
    FResult: TJSONObject;
    procedure ProcessAnalysis(const APrompt: string);
    procedure OnAnalysisComplete(Sender: TObject);
    procedure PopulateGrid(AGrid: TStringGrid; AData: TJSONArray);
    { Private declarations }
  public
    { Public declarations }
  end;

var
  FrmIA: TFrmIA;

implementation

{$R *.fmx}

procedure TFrmIA.ProcessAnalysis(const APrompt: string);
var
  LResp: IResponse;
  LJson: TJSONObject;
begin
  try
    LJson := TJSONObject.Create;
    LJson.AddPair('prompt', APrompt);

    LResp := TRequest.New
      .BaseURL('http://localhost:3001')
      .Resource('prompts')
      .AddBody(LJson.ToJSON)
      .Accept('application/json')
      .Post;

    if LResp.StatusCode <> 200 then
      raise Exception.Create(LResp.Content);

    FResult := TJSONObject.ParseJSONValue(
      TEncoding.UTF8.GetBytes(LResp.Content), 0
    ) as TJSONObject;

  finally
    LJson.Free;
  end;
end;

procedure TFrmIA.SpeedButton1Click(Sender: TObject);
begin
  TabControl.GotoVisibleTab(0);
end;

procedure TFrmIA.PopulateGrid(AGrid: TStringGrid; AData: TJSONArray);
var
  i, j : Integer;
  LObj : TJSONObject;
  LPair: TJSONPair;
  LCol : TStringColumn;
begin
  if (AData = nil) or (AData.Count = 0) then
    Exit;

  AGrid.BeginUpdate;
  try
    AGrid.ClearColumns;

    // Create columns dynamically from the first object's keys
    LObj := AData.Items[0] as TJSONObject;
    for LPair in LObj do
    begin
      LCol        := TStringColumn.Create(AGrid);
      LCol.Header := LPair.JsonString.Value;
      LCol.Stored := False;
      AGrid.AddObject(LCol);
    end;

    AGrid.RowCount := AData.Count;

    // Fill rows
    for i := 0 to AData.Count - 1 do
    begin
      LObj := AData.Items[i] as TJSONObject;
      j    := 0;
      for LPair in LObj do
      begin
        AGrid.Cells[j, i] := LPair.JsonValue.Value;
        Inc(j);
      end;
    end;

  finally
    AGrid.EndUpdate;
  end;
end;

procedure TFrmIA.OnAnalysisComplete(Sender: TObject);
begin
  TLoading.Hide;

  if Assigned(TThread(Sender).FatalException) then
  begin
    ShowMessage(Exception(TThread(Sender).FatalException).Message);
    Exit;
  end;

  // Route the result to the correct tab based on the "type" field
  if FResult.GetValue<string>('type', '') = 'text' then
  begin
    lblText.Text := FResult.GetValue<string>('data', '');
    TabControl.GotoVisibleTab(1);
  end
  else if FResult.GetValue<string>('type', '') = 'array' then
  begin
    PopulateGrid(Grid, FResult.GetValue<TJSONArray>('data'));
    TabControl.GotoVisibleTab(2);
  end;
end;

procedure TFrmIA.btnSendClick(Sender: TObject);
begin
  TLoading.Show(FrmIA);

  TLoading.ExecuteThread(
    procedure
    begin
      ProcessAnalysis(mPrompt.Text);
    end,
    OnAnalysisComplete
  );
end;

procedure TFrmIA.btnBack1Click(Sender: TObject);
begin
  TabControl.GotoVisibleTab(0);
end;

procedure TFrmIA.FormShow(Sender: TObject);
begin
  TabControl.ActiveTab := TabItem1;
end;

end.
