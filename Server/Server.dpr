program Server;

uses
  Vcl.Forms,
  UnitMain in 'UnitMain.pas' {FrmMain},
  Dm.Main in 'Dm.Main.pas' {Dm: TDataModule},
  uChatGPT in 'Utils\uChatGPT.pas',
  uClaude in 'Utils\uClaude.pas',
  uAIProviderIntf in 'Utils\uAIProviderIntf.pas',
  uAIProvider in 'Utils\uAIProvider.pas',
  uAIModels in 'Utils\uAIModels.pas',
  uChatGPTProvider in 'Utils\uChatGPTProvider.pas',
  uClaudeProvider in 'Utils\uClaudeProvider.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TFrmMain, FrmMain);
  Application.Run;
end.
