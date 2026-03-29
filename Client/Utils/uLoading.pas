unit uLoading;

interface

uses
  System.SysUtils, System.UITypes, FMX.Types, FMX.Controls, FMX.StdCtrls,
  FMX.Objects, FMX.Effects, FMX.Layouts, FMX.Forms, FMX.Graphics, FMX.Ani,
  FMX.VirtualKeyboard, FMX.Platform, System.Classes;

type
  TMyThreadMethod = procedure(Sender: TObject) of object;

  TLoading = class
  private
    class var Layout: TLayout;
    class var Background: TRectangle;
    class var Arc: TArc;
    class var Message: TLabel;
    class var Animation: TFloatAnimation;
  public
    class procedure Show(const AForm: TForm; const AMsg: string = '');
    class procedure Hide;
    class procedure ChangeText(const ANewText: string); static;
    class procedure ExecuteThread(AProc: TProc;
      AProcTerminate: TMyThreadMethod);
  end;

implementation

{ TLoading }

class procedure TLoading.Hide;
begin
  if not Assigned(Layout) then
    Exit;

  try
    if Assigned(Message) then
      Message.DisposeOf;
    if Assigned(Animation) then
      Animation.DisposeOf;
    if Assigned(Arc) then
      Arc.DisposeOf;
    if Assigned(Background) then
      Background.DisposeOf;
    if Assigned(Layout) then
      Layout.DisposeOf;
  except
    // Suppress any disposal errors
  end;

  Message := nil;
  Animation := nil;
  Arc := nil;
  Layout := nil;
  Background := nil;
end;

class procedure TLoading.Show(const AForm: TForm; const AMsg: string = '');
var
  LKeyboardSvc: IFMXVirtualKeyboardService;
begin
  // Semi-transparent dark overlay
  Background := TRectangle.Create(AForm);
  Background.Opacity := 0;
  Background.Parent := AForm;
  Background.Visible := True;
  Background.Align := TAlignLayout.Contents;
  Background.Fill.Color := TAlphaColorRec.Black;
  Background.Fill.Kind := TBrushKind.Solid;
  Background.Stroke.Kind := TBrushKind.None;

  // Layout that contains the spinner and the message label
  Layout := TLayout.Create(AForm);
  Layout.Opacity := 0;
  Layout.Parent := AForm;
  Layout.Visible := True;
  Layout.Align := TAlignLayout.Contents;
  Layout.Width := 250;
  Layout.Height := 78;

  // Spinner arc
  Arc := TArc.Create(AForm);
  Arc.Visible := True;
  Arc.Parent := Layout;
  Arc.Align := TAlignLayout.Center;
  Arc.Margins.Bottom := 55;
  Arc.Width := 25;
  Arc.Height := 25;
  Arc.EndAngle := 280;
  Arc.Stroke.Color := $FFFEFFFF;
  Arc.Stroke.Thickness := 2;
  Arc.Position.X := Trunc((Layout.Width - Arc.Width) / 2);
  Arc.Position.Y := 0;

  // Rotation animation for the spinner
  Animation := TFloatAnimation.Create(AForm);
  Animation.Parent := Arc;
  Animation.StartValue := 0;
  Animation.StopValue := 360;
  Animation.Duration := 0.8;
  Animation.Loop := True;
  Animation.PropertyName := 'RotationAngle';
  Animation.AnimationType := TAnimationType.InOut;
  Animation.Interpolation := TInterpolationType.Linear;
  Animation.Start;

  // Message label
  Message := TLabel.Create(AForm);
  Message.Parent := Layout;
  Message.Align := TAlignLayout.Center;
  Message.Margins.Top := 60;
  Message.Font.Size := 13;
  Message.Height := 70;
  Message.Width := AForm.Width - 100;
  Message.FontColor := $FFFEFFFF;
  Message.TextSettings.HorzAlign := TTextAlign.Center;
  Message.TextSettings.VertAlign := TTextAlign.Leading;
  Message.StyledSettings := [TStyledSetting.Family, TStyledSetting.Style];
  Message.Text := AMsg;
  Message.VertTextAlign := TTextAlign.Leading;
  Message.Trimming := TTextTrimming.None;
  Message.TabStop := False;
  Message.SetFocus;

  // Fade in the overlay and spinner layout
  Background.AnimateFloat('Opacity', 0.7);
  Layout.AnimateFloat('Opacity', 1);
  Layout.BringToFront;

  // Hide the virtual keyboard if present
  TPlatformServices.Current.SupportsPlatformService(IFMXVirtualKeyboardService,
    IInterface(LKeyboardSvc));
  if LKeyboardSvc <> nil then
    LKeyboardSvc.HideVirtualKeyboard;
  LKeyboardSvc := nil;
end;

class procedure TLoading.ChangeText(const ANewText: string);
begin
  if Assigned(Layout) and Assigned(Message) then
    try
      Message.Text := ANewText;
    except
      // Suppress any update errors
    end;
end;

class procedure TLoading.ExecuteThread(AProc: TProc;
  AProcTerminate: TMyThreadMethod);
var
  LThread: TThread;
begin
  LThread := TThread.CreateAnonymousThread(AProc);

  if Assigned(AProcTerminate) then
    LThread.OnTerminate := AProcTerminate;

  LThread.Start;
end;

end.
