{ @project: XAMPPER
  @author   KRZYSZTOF "@K0FF.EU" K0FF
  @version: 2017-08
}
unit main;

{$mode delphi}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, UniqueInstance, Forms, Controls, Graphics,
  Dialogs, ExtCtrls, StdCtrls, Menus, IniFiles, Process, jwatlhelp32;

type

  TModule = record
    Enable: Boolean;
    M_Panel: TPanel;
    M_Button: TButton;
    M_Name: TLabel;
    M_Status: TLabel;
    C_CommandStart: AnsiString;
    C_CommandStop: AnsiString;
    C_Process: AnsiString;
  end;

  { TWindow }

  TWindow = class(TForm)
    Stop: TButton;
    P_Exit: TMenuItem;
    P_Panel: TMenuItem;
    M_Modules: TPanel;
    M_Bottom: TPanel;
    Popu: TPopupMenu;
    Timex: TTimer;
    Tray: TTrayIcon;
    Once: TUniqueInstance;
    procedure Button1Click(Sender: TObject);
    procedure FormActivate(Sender: TObject);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormWindowStateChange(Sender: TObject);
    procedure P_ExitClick(Sender: TObject);
    procedure P_PanelClick(Sender: TObject);
    procedure P_StopClick(Sender: TObject);
    procedure StopClick(Sender: TObject);
    procedure TimexTimer(Sender: TObject);
    procedure TrayClick(Sender: TObject);
    procedure ModuleClick(Sender: TObject);
    procedure ModuleAppend( MODULE_section: String; MODULE_index: Integer );
    procedure TrayDblClick(Sender: TObject);
    procedure UniqueInstance1OtherInstance(Sender: TObject;
      ParamCount: Integer; const Parameters: array of String);
  private
    { private declarations }
  public
    { public declarations }
  end;

var
  WINDOW: TWindow;
  INI: TINIFile;
  MODULES: Array [0..255] of TMODULE;
  COUNTER: Integer;
  STARTTRAY: Boolean;

implementation

{$R *.lfm}

{ Process }

function PROCESS_Exists(exeFileName: string): Boolean;
var
  ContinueLoop: Boolean;
  FSnapshotHandle: THandle;
  FProcessEntry32: TProcessEntry32;
begin
  FSnapshotHandle := CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
  FProcessEntry32.dwSize := SizeOf(FProcessEntry32);
  ContinueLoop := Process32First(FSnapshotHandle, FProcessEntry32);
  Result := False;
  while Integer(ContinueLoop) <> 0 do
  begin
    if ((UpperCase(ExtractFileName(FProcessEntry32.szExeFile)) =
      UpperCase(ExeFileName)) or (UpperCase(FProcessEntry32.szExeFile) =
      UpperCase(ExeFileName))) then
    begin
      Result := True;
    end;
    ContinueLoop := Process32Next(FSnapshotHandle, FProcessEntry32);
  end;
  //CloseHandle(FSnapshotHandle);
end;

procedure PROCESS_Execute(COMMAND: AnsiString);
var
   RunProgram: TProcess;
begin
   RunProgram := TProcess.Create(nil);
   RunProgram.CommandLine := COMMAND;
   RunProgram.ShowWindow := swoHIDE;
   RunProgram.Execute;
   RunProgram.Free;
end;

{ Module / TModule }

procedure MODULE_START( MODULE_index: Integer );
begin
  MODULES[MODULE_index].M_BUTTON.Enabled := False;
  MODULES[MODULE_index].M_Name.Color := clWhite;
  PROCESS_Execute(MODULES[MODULE_index].C_CommandStart);
end;

procedure MODULE_STOP( MODULE_index: Integer );
begin
  MODULES[MODULE_index].M_BUTTON.Enabled := False;
  MODULES[MODULE_index].M_Name.Color := clYellow;
  PROCESS_Execute(MODULES[MODULE_index].C_CommandStop);
end;

procedure MODULE_STATUS( MODULE_index: Integer );
begin
  if not (MODULES[MODULE_index].C_Process = '') then
    begin
      if PROCESS_Exists(MODULES[MODULE_index].C_Process) then
        begin
          case MODULES[MODULE_index].M_Name.Color of
            clNone: MODULES[MODULE_index].M_Name.Color := clLime;
            clWhite: MODULES[MODULE_index].M_Name.Color := clLime;
          end;
          if MODULES[MODULE_index].M_Name.Color = clLime then
            begin
              MODULES[MODULE_index].M_Button.Caption := 'Stop';
              MODULES[MODULE_index].M_Button.Enabled := True;
            end;
          MODULES[MODULE_index].M_Status.Caption := MODULES[MODULE_index].C_Process;
        end
      else
        begin
          case MODULES[MODULE_index].M_Name.Color of
            clYellow: MODULES[MODULE_index].M_Name.Color := clNone;
            clLime: MODULES[MODULE_index].M_Name.Color := clNone;
          end;
          if MODULES[MODULE_index].M_Name.Color = clNone then
            begin
              MODULES[MODULE_index].M_Button.Caption := 'Start';
              MODULES[MODULE_index].M_Button.Enabled := True;
            end;
          MODULES[MODULE_index].M_Status.Caption := '';
        end;
    end;
end;

procedure MODULE_LOAD( MODULE_section: String; MODULE_index: Integer );
begin
  WINDOW.ModuleAppend( MODULE_section, MODULE_index );

  //
  MODULES[MODULE_index].C_Process := INI.ReadString( MODULE_section,'process', '');
  MODULES[MODULE_index].C_CommandStart := INI.ReadString( MODULE_section,'command.start', '');
  MODULES[MODULE_index].C_CommandStop := INI.ReadString( MODULE_section,'command.stop', '');
  MODULES[MODULE_index].M_NAME.Caption := INI.ReadString( MODULE_section,'name', '#'+IntToStr(MODULE_index));

  if MODULES[MODULE_index].C_Process = '' then
    MODULES[MODULE_index].M_BUTTON.Enabled := False;

end;

procedure MODULE_INI();
var
  MODULE_index: Integer;
  MODULE_enable: Boolean;
begin
  try
    COUNTER := INI.ReadInteger('modules','count', 5)-1;
    for MODULE_index:=COUNTER downto 0 do
      begin
        MODULE_enable := INI.ReadBool('modules','module.'+IntToStr(MODULE_index), False);
        if MODULE_enable then
          begin
            MODULE_LOAD('module.'+IntToStr(MODULE_index),MODULE_index)
          end;
        MODULES[MODULE_index].Enable:= MODULE_enable;
      end;

    //
    for MODULE_index:=0 to COUNTER do
      begin
        if INI.ReadBool('module.'+IntToStr(MODULE_index),'autorun', False) then
          begin
            if not (MODULES[MODULE_index].C_Process = '') then
              begin
                if not PROCESS_Exists(MODULES[MODULE_index].C_Process) then
                  begin
                    MODULE_START(MODULE_index);
                  end;
              end;
          end;
      end;
  finally
  end;
end;



{ TWindow }

procedure TWindow.FormCreate(Sender: TObject);
begin
  //
  WINDOW.Width := INI.ReadInteger('xampper','Width', 450);
  WINDOW.Height := INI.ReadInteger('xampper','Height', 300);
  STARTTRAY := INI.ReadBool('xampper','minimize', True);

//
//  if not  then
//     := False;

  MODULE_INI;
  Timex.Enabled := True;
end;

procedure TWindow.FormDestroy(Sender: TObject);
begin

end;

procedure TWindow.FormWindowStateChange(Sender: TObject);
begin
  //if WindowState = wsMinimized then Hide;
end;

procedure TWindow.P_ExitClick(Sender: TObject);
begin
  Tray.Visible := False;
  INI.Free;
  Halt;
end;

procedure TWindow.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  Hide;
  CloseAction := caNone;
  try
    INI.WriteString('xampper', 'width', IntToStr(WINDOW.Width));
    INI.WriteString('xampper', 'height', IntToStr(WINDOW.Height));
  finally
  end;
end;

procedure TWindow.Button1Click(Sender: TObject);
begin
  Application.Minimize();
end;

procedure TWindow.FormActivate(Sender: TObject);
begin
  if STARTTRAY then
    begin
      STARTTRAY := False;
      Hide;
    end;
  WindowState := wsNormal;
end;

procedure TWindow.P_PanelClick(Sender: TObject);
begin
  if Visible then
     Hide
  else
    begin
      WindowState := wsNormal;
      Show;
    end;
end;

procedure TWindow.P_StopClick(Sender: TObject);
begin

end;

procedure TWindow.StopClick(Sender: TObject);
var
  MODULE_index: Integer;
begin
  // STOP ALL
  for MODULE_index:=COUNTER downto 0 do
    MODULE_STOP( MODULE_index );
end;

procedure TWindow.TimexTimer(Sender: TObject);
var
  MODULE_index: Integer;
begin
  for MODULE_index := 0 to COUNTER do
    MODULE_STATUS(MODULE_index);
end;

procedure TWindow.TrayClick(Sender: TObject);
begin

end;

procedure TWindow.ModuleClick(Sender: TObject);
var
  M_BUTTON: TButton;
begin
  M_BUTTON := Sender as TButton;
  M_BUTTON.Enabled := False;
  if M_BUTTON.Caption = 'Start' then MODULE_START(M_BUTTON.Tag);
  if M_BUTTON.Caption = 'Stop' then MODULE_STOP(M_BUTTON.Tag);
end;

procedure TWindow.ModuleAppend( MODULE_section: String; MODULE_index: Integer );
begin
  MODULES[MODULE_index].M_PANEL := TPanel.Create( WINDOW );
  MODULES[MODULE_index].M_PANEL.Parent := WINDOW;
  MODULES[MODULE_index].M_PANEL.Height := 40;
  MODULES[MODULE_index].M_PANEL.Align := alTop;

  //
  MODULES[MODULE_index].M_BUTTON := TButton.Create(MODULES[MODULE_index].M_PANEL);
  MODULES[MODULE_index].M_BUTTON.Parent := MODULES[MODULE_index].M_PANEL;
  MODULES[MODULE_index].M_BUTTON.Enabled := False;
  MODULES[MODULE_index].M_BUTTON.Height := 25;
  MODULES[MODULE_index].M_BUTTON.Width := 75;
  MODULES[MODULE_index].M_BUTTON.Left := 8;
  MODULES[MODULE_index].M_BUTTON.Top := 8;

  //
  MODULES[MODULE_index].M_BUTTON.Tag := MODULE_index;
  MODULES[MODULE_index].M_BUTTON.OnClick:=ModuleClick;

  //
  MODULES[MODULE_index].M_NAME := TLabel.Create(MODULES[MODULE_index].M_PANEL);
  MODULES[MODULE_index].M_NAME.Parent := MODULES[MODULE_index].M_PANEL;
  MODULES[MODULE_index].M_NAME.AutoSize := False;
  MODULES[MODULE_index].M_NAME.Font.Style := [fsBold];
  MODULES[MODULE_index].M_NAME.Height := 15;
  MODULES[MODULE_index].M_NAME.Width := 56;
  MODULES[MODULE_index].M_NAME.Left := 104;
  MODULES[MODULE_index].M_NAME.Top := 13;

  //
  MODULES[MODULE_index].M_STATUS := TLabel.Create(MODULES[MODULE_index].M_PANEL);
  MODULES[MODULE_index].M_STATUS.Parent := MODULES[MODULE_index].M_PANEL;
  MODULES[MODULE_index].M_STATUS.Height := 15;
  MODULES[MODULE_index].M_STATUS.Left := 176;
  MODULES[MODULE_index].M_STATUS.Top := 13;
end;

procedure TWindow.TrayDblClick(Sender: TObject);
begin
  if Visible then
     Hide
  else
     Show;
end;

procedure TWindow.UniqueInstance1OtherInstance(Sender: TObject;
  ParamCount: Integer; const Parameters: array of String);
begin

end;

begin
  INI := TINIFile.Create('xampper.ini');
end.

