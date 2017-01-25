library audio;

{$mode objfpc}{$H+}

uses
  Classes, laz_acs, acs_stdaudio, acs_wave,acs_converters ,Sysutils,acs_allformats,acs_file,
  acs_misc,acs_indicator,acs_audio,acs_volumequery,acs_mixer;


var
  Output : TAcsAudioOut;
  FileInput : TAcsFileIn;
  FileLoaded : Boolean;
  Input : TAcsAudioIn;
  Indicator : TAcsVolumeQuery;
  NullOutput : TAcsNULLOut;
  Mixer : TAcsMixer;
  MixerIn : TAcsMixer;
  SelectedMixer : Integer = -1;

procedure CreateClasses;
begin
  if not Assigned(Output) then
    begin
      Output := TAcsAudioOut.Create(nil);
      Output.Driver:='DirectSound';
    end;
  if Assigned(Mixer) then
    Mixer.Free;
  Mixer := TAcsMixer.Create(nil);
  if not Assigned(FileInput) then
    begin
      FileInput := TAcsFileIn.Create(nil);
      FileInput.Loop:=False;
      Output.Input:=FileInput;
    end;
  if not Assigned(Input) then
    begin
      Input := TAcsAudioIn.Create(nil);
      Input.Driver:='Wavemapper';
    end;
  if not Assigned(Indicator) then
    begin
      Indicator := TAcsVolumeQuery.Create(nil);
      Indicator.Input := Input;
    end;
  if not Assigned(NullOutput) then
    begin
      NullOutput := TAcsNULLOut.Create(nil);
      NullOutput.Input := Indicator;
      //NullOutput.Input := Input;
      NullOutput.BufferSize:=$10;
      NullOutput.Delay:=0;
      //NullOutput.FileName:='c:\tmp.wav';
    end;
end;

function ListInputs : PChar;stdcall;
var
  i: Integer;
  Res: String;
begin
  Res := '';
  CreateClasses;
  for i := 0 to Input.DeviceCount-1 do
    Res := Res+Input.DeviceInfo[i].DeviceName+LineEnding;
  Result := PChar(Res);
end;

function SetInput(aName : PChar) : Boolean;stdcall;
var
  i: Integer;
begin
  Result := False;
  CreateClasses;
  for i := 0 to Input.DeviceCount-1 do
    if pos(aName,Input.DeviceInfo[i].DeviceName)>0  then
      begin
        Input.Device:=i;
        Result := True;
      end;
end;

function ListOutputs : PChar;stdcall;
var
  i: Integer;
  Res: String;
begin
  Res := '';
  CreateClasses;
  for i := 0 to Output.DeviceCount-1 do
    Res := Res+Output.DeviceInfo[i].DeviceName+LineEnding;
  Result := PChar(Res);
end;

function GetOutputName : PChar;stdcall;
var
  i: Integer;
  Res: String;
begin
  Res := '';
  CreateClasses;
  Res := Output.DeviceInfo[Output.Device].DeviceName;
  Result := PChar(Res);
end;

function ListMixer : PChar;stdcall;
var
  i: Integer;
  Res: String;
begin
  Res := '';
  CreateClasses;
  for i := 0 to Mixer.DevCount-1 do
    begin
      Mixer.DevNum:=i;
      if Mixer.ChannelCount>0 then
        Res := Res+Mixer.MixerName+LineEnding;
    end;
  Result := PChar(Res);
end;

function ListMixerChannels : PChar;stdcall;
var
  i: Integer;
  Res: String;
  aName: String;
begin
  Res := '';
  CreateClasses;
  for i := 0 to Mixer.ChannelCount-1 do
    begin
      aName := Mixer.ChannelName[i];
      Res := Res+aName+LineEnding;
    end;
  Result := PChar(Res);
end;

function SetOutput(aName : PChar) : Boolean;stdcall;
var
  i: Integer;
  s: String;
  bName: String;
begin
  Result := False;
  CreateClasses;
  for i := 0 to Output.DeviceCount-1 do
    if pos(aName,Output.DeviceInfo[i].DeviceName) >0   then
      begin
        bName := Output.DeviceInfo[i].DeviceName; //reset aName to real name for Mixer selection
        Output.Device:=i;
        Result := True;
      end;
  for i := 0 to Mixer.DevCount-1 do
    begin
      Mixer.DevNum:=i;
      if pos('(',bName)>0 then
        bName := copy(bName,pos('(',bName)+1,length(bName)-(pos('(',bName)+1));
      s := Mixer.MixerName;
      if (pos('Lautsprecher',s)>0)
      or (pos('Speaker',s)>0)
      then
        begin
          if pos('(',s)>0 then s := StringReplace(copy(s,pos('(',s)+1,length(s)),')','',[rfReplaceAll]);
          if length(s)>length(bName) then
            if pos(bName,s)>0 then
              break;
          if length(bName)>length(s) then   //Mixername can be cutt off
            if copy(bName,0,length(s))=s then
              break;
          if bName=s then
            break;
        end;
    end;
end;

function SetMixer(aName : PChar) : Boolean;stdcall;
var
  i: Integer;
  aVol : TAcsMixerLevel;
  a: Integer;
begin
  Result := False;
  for i := 0 to Mixer.DevCount-1 do
    begin
      Mixer.DevNum:=i;
      if pos(aName,Mixer.MixerName)>0 then
        begin
          SelectedMixer:=i;
          Result := True;
          for a := 0 to Mixer.ChannelCount-1 do
            begin
              aVol.Main:=255;
              aVol.Left:=aVol.Main;
              aVol.Right:=aVol.Main;
              if Mixer.Channel[a] = mcPCM then
                Mixer.Level[a]:=aVol;
              aVol.Main:=128;
              aVol.Left:=aVol.Main;
              aVol.Right:=aVol.Main;
              if Mixer.Channel[a] = mcMic then
                Mixer.Level[a]:=aVol;
            end;
          break;
        end;
    end;
end;

function Start : Boolean;stdcall;
begin
  Result := True;
  CreateClasses;
  Result := FileLoaded;
  if not Result then exit;
  try
    Output.Run;
    Result := Output.Active;
  except
    Result := False;
  end;
end;

function IsPlaying : Boolean;stdcall;
begin
  Result := Output.Active;
end;

function StartRecording : Boolean;stdcall;
begin
  Result := True;
  CreateClasses;
  if not Result then exit;
  try
    NullOutput.Run;
    Result := NullOutput.Active;
  except
    Result := False;
  end;
end;

function IsRecording : Boolean;stdcall;
begin
  Result := NullOutput.Active;
end;

function GetRecordVolumeDB : Double;stdcall;
begin
  Result := (Indicator.dbLeft+Indicator.dbRight)/2;
end;

function GetRecordVolume : Word;stdcall;
begin
  Result := round((Indicator.volLeft+Indicator.volRight)/2);
end;

function GetExactRecordVolume(Time : Integer;Measurements : Integer) : Word;stdcall;
var
  aTime : Integer;
  Val : real;
  i: Integer;
begin
  aTime := Time div Measurements;
  for i := 0 to Measurements-1 do
    begin
      Val := Val+(Indicator.volLeft+Indicator.volRight)/2;
      sleep(aTime);
    end;
  Val := Val / Measurements;
  Result := round(Val);
end;

function StopRecording : Boolean;stdcall;
begin
  Result := True;
  CreateClasses;
  try
    NullOutput.Stop;
  except
    Result := False;
  end;
end;

function Stop : Boolean;stdcall;
begin
  Result := True;
  CreateClasses;
  try
    Output.Stop;
  except
    Result := False;
  end;
end;

function LoadFile(aFilename : PChar) : Boolean;stdcall;
begin
  Result := True;
  FileLoaded:=False;
  CreateClasses;
  try
    Output.Stop;
    FileInput.FileName:=aFilename;
    FileInput.Init;
    Result := FileInput.Size>0;
    FileInput.FileName:=aFilename;
    FileLoaded:=Result;
  except
    Result := False;
  end;
end;

function SetVolume(aVal : Integer) : Boolean;stdcall;
var
  aName: String;
  aVol : TAcsMixerLevel;
  i: Integer;
  aType: TAcsMixerChannel;
begin
  CreateClasses;
  Result := False;
  Mixer.DevNum:=SelectedMixer;
  for i := 0 to Mixer.ChannelCount-1 do
    begin
      aName := Mixer.ChannelName[i];
      aVol.Main:=aVal;
      aVol.Left:=aVal;
      aVol.Right:=aVal;
      aType := Mixer.Channel[i];
      if (aType = mcVolume) or (aType = mcMic) then
        begin
          Mixer.Level[i] := aVol;
          Result := True;
        end;
    end;
end;

procedure ScriptCleanup;
begin
  if Assigned(Output) then
    Output.Stop;
  if Assigned(NullOutput) then
    NullOutput.Stop;
  FreeAndNil(Output);
  FreeAndNil(Input);
  FreeAndNil(FileInput);
  FreeAndNil(Indicator);
  FreeAndNil(NullOutput);
  FreeAndNil(Mixer);
end;
function ScriptDefinition : PChar;stdcall;
begin
  Result := 'function ListInputs : PChar;stdcall;'
       +#10+'function SetInput(aName : PChar) : Boolean;stdcall;'
       +#10+'function ListOutputs : PChar;stdcall;'
       +#10+'function GetOutputName : PChar;stdcall;'
       +#10+'function ListMixer : PChar;stdcall;'
       +#10+'function ListMixerChannels : PChar;stdcall;'
       +#10+'function SetOutput(aName : PChar) : Boolean;stdcall;'
       +#10+'function SetMixer(aName : PChar) : Boolean;stdcall;'
       +#10+'function LoadFile(aFilename : PChar) : Boolean;stdcall;'
       +#10+'function Start : Boolean;stdcall;'
       +#10+'function IsPlaying : Boolean;stdcall;'
       +#10+'function Stop : Boolean;stdcall;'
       +#10+'function StartRecording : Boolean;stdcall;'
       +#10+'function IsRecording : Boolean;stdcall;'
       +#10+'function GetRecordVolume : Word;stdcall;'
       +#10+'function GetExactRecordVolume(Time : Integer;Measurements : Integer) : Word;stdcall;'
       +#10+'function GetRecordVolumeDB : Double;stdcall;'
       +#10+'function StopRecording : Boolean;stdcall;'
       +#10+'function SetVolume(aVal : Integer) : Boolean;stdcall;'
            ;
end;

exports
  ListInputs,
  ListOutputs,
  GetOutputName,
  Start,
  IsPlaying,
  Stop,
  LoadFile,
  SetOutput,
  SetMixer,
  ListMixer,
  ListMixerChannels,
  SetInput,
  StartRecording,
  IsRecording,
  GetRecordVolume,
  GetExactRecordVolume,
  GetRecordVolumeDB,
  StopRecording,
  SetVolume,

  ScriptCleanup,
  ScriptDefinition;

initialization
  Output := nil;
  Input := nil;
  FileLoaded := False;
end.

