#SingleInstance force
; /////////////////////////////////////////////////////////////////////////////////////////////////
; //   >>>> USER WARNING:  Do NOT edit the header, it makes helping you in Discord HARDER! <<<<
; // Updates installed after the date below may result in the pointer addresses not being valid.
; // Epic Games IC Version:  v0.408
; /////////////////////////////////////////////////////////////////////////////////////////////////
global ScriptDate    := "2021/11/10"   ; USER: Cut and paste these in Discord when asking for help
global ScriptVersion := "2021.11.10.1" ; USER: Cut and paste these in Discord when asking for help
; /////////////////////////////////////////////////////////////////////////////////////////////////
; // Modron Automation Gem Farming Script for Epic Games Store
; // Original by mikebaldi1980 - steam focused
; // Updated  by CantRow for Epic Games Store Compatibility
; // Put together with the help from many different people. thanks for all the help.
; // Thanks to Ferron7 for incorporating updates from Steam branch and updating memory offsets.
; /////////////////////////////////////////////////////////////////////////////////////////////////
; // Future Considerations / Areas of Interest
; // -improve encapsulation and code reuse
; // -
; /////////////////////////////////////////////////////////////////////////////////////////////////
; // Changes
; // 20210918 1 - modified file header
; //          2 - removed Core Target Area read and logic-- both pointers were null, discussed 
; //              with Mike and #scripting.  Not needed.  Don't Briv stack at your core reset area
; // 20210919 1 - started reworking the Read First tab
; //            - added buttons and code to launch stuff off the resources tab
; // 20210924 1 - Initial fork update
; // 20210925 1 - Verticalized Seats, redesigning Settings page
; // 20210926 1 - Adding LJs mod
; //            - AutoLevel and AutoUlt INI saves/loads
; // 20211014 1 - Fixed a bug where all F-Key toggles would show as activated in settings after
; //              every reload.
; // 20211020 1 - Hopefully fixed/merged things correctly.
; //            - fix log file extension
; //          2 - added Fenume's Pause key selector, logging currently not working, commented out
; // 20211021 1 - Shifted the code to ZModronGUI.ahk, keeping ModronGUI.ahk (mostly) Mike's stuff
; /////////////////////////////////////////////////////////////////////////////////////////////////

SetWorkingDir, %A_ScriptDir% ; The working directory is the Script Directory, log files are there
CoordMode, Mouse, Client     ; TBD why this is important, don't change

; /////////////////////////////////////////////////////////////////////////////////////////////////
; // User settings not accessible via the GUI
; /////////////////////////////////////////////////////////////////////////////////////////////////
; // variables to consider changing if restarts are causing issues
global g_OPdelay_ms  := 10000 ;time in milliseconds for your PC to open Idle Champions  ; TODO: no real need for this to be global?
global g_GA_delay_ms := 5000  ;time in milliseconds after Idle Champions is opened for it to load pointer base into memory
; /////////////////////////////////////////////////////////////////////////////////////////////////
; // end of user settings
; /////////////////////////////////////////////////////////////////////////////////////////////////

;class and methods for parsing JSON (User details sent back from a server call)
#include JSON.ahk

;pointer addresses and offsets
#include IC_MemoryFunctions.ahk

;server call functions and variables Included after GUI so chest tabs maybe non optimal way of doing it
#include IC_ServerCallFunctions.ahk

;https://discord.com/channels/357247482247380994/474639469916454922/888620280862355506
;ControlFocus,, ahk_id %win%
;PostMessage, 0x0100, 0xC0, 0,, ahk_id %win%
;PostMessage, 0x0101, 0xC0, 0xC0000001,, ahk_id %win%


; This array of variables are used as on/off switches for whether to level/not level the heroes in these seats
global g_levToggles := [] ; [ S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12]
; This array of variables are used as on/off switches for whether to fire ultimates for the heroes in these seats
global g_ultToggles := [] ; [ S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12]
global g_StopAt := []     ; LJ This array holds the Champ level at which to stop auto levelling 
; This string of variables contains the Fx Keys for "on" Champions to level
; Thanks ThePuppy for the ini code
global g_FKeys :=  ; Note: This loop reads in the seat toggles from the INI, and creates the Active Levelling Keys
loop, 12   ; TODO: put in a function that can be called to re-string the actives when the user changes them live
{    
	IniRead, S%A_Index%, UserSettings.ini, "AutoLevel", S%A_Index%, 1
	if (S%A_Index% == 1)
	{
		g_FKeys = %g_FKeys%{F%A_Index%}
	}
    g_levToggles.push(S%A_index%) ;g_levToggles[A_Index] := S%A_Index%
    ;LogMsg("INI Loaded Seat Toggle " . S%A_Index% . " = " . g_levToggles[A_Index] . ", active: " . g_FKeys, true)
	IniRead, StopAt%A_Index%, UserSettings.ini, "StopAutoAtLevel", StopAt%A_Index%, 0 ;LJ
	g_StopAt.push(StopAt%A_Index%) ;g_StopAt[A_Index] := StopAt%A_Index% ;LJ    
    ;LogMsg("INI Loaded Level To Toggle " . S%A_Index%Level . " = " . g_StopAt[A_Index], true)
    IniRead, AU%A_Index%, UserSettings.ini, "AutoUltimate", U%A_Index%, 0 ;LJ
	g_ultToggles.push(AU%A_Index%) ;g_ultToggles[A_Index] := AU%A_Index% ;LJ    
}

; // LoadFromINI //////////////////////////////////////////////////////////////////////////////////
; // Encapsulates reading values used by the script from the stored INI file UserSettings.ini
; // NOTE: uses the only one default section Section 1, and returns the value read at the key provided
; // myKeyName - string with the name of the item in the INI file
; // myDefVal  - default value to use for this setting in case the INI entry doesn't exist
LoadFromINI(myKeyName, mydefVal, mySection := "Section1")
{	
	IniRead, mytemp, UserSettings.ini, %mySection%, %myKeyName%, %myDefVal%
	return mytemp
}

; // Let's read in all of the settings stored in the file that we need:
global SLCD := LoadFromINI("SLCD", 999, "StopAutoAtLevel")
global g_AutoLevel   := LoadFromINI("AutoLevel", 1, "AutoLevel")   ;Master Switch for Auto Levelling
global gbSpamUlts    := LoadFromINI("AutoUlts", 1, "AutoUltimate") ;bool - whether to spam ults
global gStopLevZone  := LoadFromINI("ContinuedLeveling", 10) ;Stop levelling after this zone
global gAreaLow      := LoadFromINI("AreaLow", 30)           ;Farm Brivs SB stacks after this zone
global gMinStackZone := LoadFromINI("MinStackZone", 25)      ;Lowest zone SB stacks can be farmed on
global gSBTargetStacks := LoadFromINI("SBTargetStacks", 400) ;Target Haste stacks count
global gDashSleepTime := LoadFromINI("DashSleepTime", 6000)  ;Dash (Sandie's speed ability!) wait max time
global gHewUlt       := LoadFromINI("HewUlt", 6)             ;Hew's ult key
global gbSpamUlts    := LoadFromINI("Ults", 1)               ;bool - whether to spam ults
global gbCancelAnim  := LoadFromINI("BrivSwap", 1)           ;bool - Briv swap-out to cancel animation
global gAvoidBosses  := LoadFromINI("AvoidBosses", 1)        ;bool - Briv swap-out to avoid bosses
global gbCDLeveling  := LoadFromINI("ClickLeveling", 1)      ;bool - Click damage(CD) levelling toggle
global gb100xCDLev   := LoadFromINI("CtrlClickLeveling", 0)  ;bool - 100x with CTRL key CD levelling toggle
global gbSFRecover   := LoadFromINI("StackFailRecovery", 0)  ;bool - Stack fail recovery toggle  TBD what this means
global gStackFailConvRecovery := LoadFromINI("StackFailConvRecovery", 0) ;Stack fail recovery toggle
global gSwapSleep := LoadFromINI("SwapSleep", 1500) ;Briv swap sleep time
global gRestartStackTime := LoadFromINI("RestartStackTime", 12000) ;Restart stack sleep time
global gModronResetCheckEnabled := LoadFromINI("ModronResetCheckEnabled" , 0) ;Modron Reset Check
global gCoreTargetArea := LoadFromINI("CoreTargetArea", 50) ;global to help protect against script attempting to stack farm immediately before a modron reset
global gSBTimeMax := LoadFromINI("SBTimeMax", 60000) ;Normal SB farm max time
global gDoChests := LoadFromINI("DoChests", 0) ;Enable servecalls to open chests during stack restart
global gSCMinGemCount := LoadFromINI("SCMinGemCount", 0) ;Minimum gems to save when buying chests
global gSCBuySilvers := LoadFromINI("SCBuySilvers", 0) ;Buy silver chests when can afford this many
global gSCSilverCount := LoadFromINI("SCSilverCount", 0) ;Open silver chests when you have this many
global gSCBuyGolds := LoadFromINI("SCBuyGolds", 0) ;Buy gold chests when can afford this many
global gSCGoldCount := LoadFromINI("SCGoldCount", 0) ;Open silver chests when you have this many

;Intall locations
global strSTMpath := ""
global strEGSpath := explorer.exe "com.epicgames.launcher://apps/40cb42e38c0b4a14a1bb133eb3291572?action=launch&silent=true"
global gInstallPath := LoadFromINI("GameInstallPath", strEGSpath)

;variable for correctly tracking stats during a failed stack, to prevent fast/slow runs to be thrown off
global gStackFail := 0

;globals for various timers
global gSlowRunTime    :=         
global gFastRunTime    := 100
global gRunStartTime   :=
global gTotal_RunCount := 0
global gStartTime      := 
global gPrevLevelTime  :=    
global gPrevRestart    :=
global gprevLevel      :=
global g_ZoneTime      := 0    ; variable to hold the calculated value of the time spent in the current zone

;globals for reset tracking
global gFailedStacking := 0
global gFailedStackConv := 0
global ResetCount      := 0
;globals used for stat tracking
global gGemStart       :=
global gCoreXPStart    :=
global gGemSpentStart  :=
global gRedGemsStart   :=

global gStackCountH    :=
global gStackCountSB   :=

global gTestReset := 0 ;variable to test a reset function not ready for release

global gfullScreen   := 1  ; LJ
global gScreenEnable := 1  ; LJ

; // From Fenume:
;----------------- <HOTKEY
;pause hotkey
IniRead, PauseHotkey, UserSettings.ini, Section1, PauseHotkey, 0
global gPauseHotkey := PauseHotkey

;default Pause hotkey
global gDefaultPauseHotkey := "SC029"

if !gPauseHotkey
	gPauseHotkey = %gDefaultPauseHotkey%
;----------------- HOTKEY>	


global wTitle := "Zees GemFarmer Modron for EGS (" . ScriptVersion . ")"
LogFMsg("VERSION INFO: ZModronGUI.ahk - " . wTitle)
LogMsg( "VERSION INFO: ZModronGUI.ahk - " . wTitle)
LogMsg("VERSION INFO: IC_Memoryfunctions.ahk (" . MF_ScriptVersion . ")" )
global CustomColor := 2C2F33
Gui, MyWindow:New, +Resize, %wTitle%
Gui, MyWindow:+Resize -MaximizeBox
Gui, MyWindow:Color, 2C2F33
;Gui, Mywindow:
Gui +LastFound
;WinSet, TransColor, %CustomColor% 150
;Winset, Transparent, 150, , wTitle

FormatTime, CurrentTime, , yyyyMMdd-HH:mm:ss
FormatTime, DayTime, , ddd HH:mm:ss
PreciseTime := DayTime . "." . A_MSec

global GUITabW := 500 ; width of GUI TAb control
global GUITabT := 50  ; Y offset (ie TOP) of GUI Tab control
Gui, MyWindow:Font, cSilver s11 ;
Gui, MyWindow:Add, Button, x10 y10 w100 gSave_Clicked, Save
Gui, MyWindow:Add, Button, x120 y10 w100 gRun_Clicked, Run
Gui, MyWindow:Add, Button, x230 y10 w100 gPause_Clicked, Pause
Gui, MyWindow:Add, Button, x340 y10 w100 gReload_Clicked, Reload
;if (gScreenEnable)
;	Gui, MyWindow:Add, Button, x415 y+25 w60 gScreen_Clicked, `Screen ;LJ TODO User selected Res, Monitor -- Probably remove these for general users till done

Gui, MyWindow:Add, Tab3, x5 y%GUITabT% w%GUITabW%, Read First|Settings|Help|Stats|Debug|Resources|ZDebug

Gui, Tab, Read First
global GUITabTxtW := GUITabW - 30
global GUITabTxtT := GUITabT + 30
iGUIInstctr := 0
strInsS1 := "In Slot 1 (hotkey ""Q"") save a SPEED formation. Must include Briv and at least one familiar on the field."
strInsS2 := "In Slot 2 (hotkey ""W"") save a STACK FARMing formation." 
          . " Remove all familiars from the field, keep Briv only.  Add a healer if needed."
strInsS3 := "In Slot 3 (hotkey ""E"") save the SPEED formation (above), without Briv, Hew, Havi, or Melf." 
          . " This step may be ommitted if you will not be swapping out Briv to cancel his jump animation."
          . " (TODO: include blurb here about when you DO want this option)"
strInsS6 :=  "In Idle Champions, load into zone 1 of an adventure to farm gems (Mad Wizard is a good starting choice)."
Gui, MyWindow:Font, w400
Gui, MyWindow:Add, Text, x15 y%GUITabTxtT%, Instructions:
Gui, MyWindow:Add, Text, x15 y+3 w%GUITabTxtW%,  % ++iGUIInstctr . ".  " . strInsS1
Gui, MyWindow:Add, Text, x15 y+3 w%GUITabTxtW%,  % ++iGUIInstctr . ".  " . strInsS2
Gui, MyWindow:Add, Text, x15 y+3 w%GUITabTxtW%,  % ++iGUIInstctr . ".  " . strInsS3 
Gui, MyWindow:Add, Text, x15 y+3 w%GUITabTxtW%,  % ++iGUIInstctr . ".  " .  "Switch to Settings tab, adjust as desired. (ask for help in Discord #scripting)"
Gui, MyWindow:Add, Text, x15 y+3 w%GUITabTxtW%,  % ++iGUIInstctr . ".  " .  "Click the SAVE button to save to UserSettings.ini file in your script folder."
Gui, MyWindow:Add, Text, x15 y+3 w%GUITabTxtW%,  % ++iGUIInstctr . ".  " . strIns6
Gui, MyWindow:Add, Text, x15 y+3 w%GUITabTxtW%,  % ++iGUIInstctr . ".  " .  " Press the RUN button to start farming gems."
strNotS1  := "To adjust your settings after the run starts, first use the pause hotkey, ~(Shift `), then adjust & save settings."
strNotS4  := "Recommended SB stack level : [Modron Reset Zone] - (2 + 2*X), where X is your Briv skip level (ie 1x 2x 3x 4x)"
strNotS6  := "Script communicates directly with Idle Champions play servers to recover from a failed stacking and for when Modron resets to the World Map."
strNotS10 := "Recommended Briv swap `sleep time is betweeb 1500 - 3000. If you are seeing Briv's " 
           . "landing animation then increase the the swap sleep time. If Briv is not back in the" 
           . " formation before monsters can be killed then decrease the swap sleep time."
iGUIInstctr := 0
Gui, MyWindow:Add, Text, x15 y+15, Notes:
Gui, MyWindow:Add, Text, x15 y+2 w%GUITabTxtW%, % ++iGUIInstctr . ".  " .  strNotS1
Gui, MyWindow:Add, Text, x15 y+2 w%GUITabTxtW%, % ++iGUIInstctr . ".  " .  "DON'T FORGET to unpause after saving your settings with the same pause hotkey."
Gui, MyWindow:Add, Text, x15 y+2 w%GUITabTxtW%, % ++iGUIInstctr . ".  " .  "First run is ignored for stats, in case it is a partial run."
Gui, MyWIndow:Add, Text, x15 y+2 w%GUITabTxtW%, % ++iGUIInstctr . ".  " .  strNotS4
Gui, MyWindow:Add, Text, x15 y+2 w%GUITabTxtW%, % ++iGUIInstctr . ".  " .  "Script will activate and focus the game window for manual resets as part of failed stacking."
Gui, MyWIndow:Add, Text, x15 y+2 w%GUITabTxtW%, % ++iGUIInstctr . ".  " .  strNotS6
Gui, MyWIndow:Add, Text, x15 y+2 w%GUITabTxtW%, % ++iGUIInstctr . ".  " .  "Script reads system memory."
Gui, MyWIndow:Add, Text, x15 y+2 w%GUITabTxtW%, % ++iGUIInstctr . ".  " .  "The script does not work without Shandie."
Gui, MyWIndow:Add, Text, x15 y+2 w%GUITabTxtW%, % ++iGUIInstctr . ".  " .  "Disable manual resets to recover from failed Briv stack conversions when running event free plays."
Gui, MyWIndow:Add, Text, x15 y+2 w%GUITabTxtW%, % ++iGUIInstctr . ".  " .  strNotS10
strKI2 := "Using Hew's ult throughout a run with Briv swapping can result in Havi's ult being trig" 
       . "gered instead. Consider removing Havi from formation save slot 3, in game `hotkey ""E""."
strKI3 := "Conflict between Epic Games Store and IdleCombos.exe script. Close IdleCombos if Briv " 
       . "Restart Stacking as EGS will see IdleCombos as an instance of IC. "
iGUIInstctr := 0
Gui, MyWindow:Add, Text, x15 y+10, Known Issues:
Gui, MyWindow:Add, Text, x15 y+2, 1. Cannot fully interact with `GUI `while script is running.
Gui, MyWindow:Add, Text, x15 y+2 w%GUITabTxtW%, % ++iGUIInstctr . ".  " .  strKI2
Gui, MyWindow:Add, Text, x15 y+2 w%GUITabTxtW%, % ++iGUIInstctr . ".  " .  strKI3 

; // GUITAB: Settings /////////////////////////////////////////////////////////////////////////////
Gui, Tab, Settings
; // AutoLevel Group Box 
Gui, MyWindow:Add, GroupBox, x+5 r14 w110,
Gui, MyWindow:Font, w300
Gui, MyWindow:Add, CheckBox, w80 xp+10 vAutoLevel Section Checked%g_AutoLevel%, AutoLevel
Gui, MyWindow:Add, Edit, vSLCD w33 h18, %SLCD%
Gui, MyWindow:Add, CheckBox, xs+40 ys+25 vACD Checked, CD

loop, 12
{   
    sv := g_levToggles[A_Index] ; value of the specific seat
    Gui, MyWindow:Add, Edit, xs yp+24 vStopAt%A_Index% w33 h17, % g_StopAt[A_Index]
    Gui, MyWindow:Add, CheckBox, xs+40 yp vAL%A_Index% Checked%sv%, S%A_Index%
    
}
;Gui, MyWindow:Add, Edit, xs h18 vnewStopLevZone w30 BackGround2C2F33, % gStopLevZone
;Gui, MyWindow:Add, Text, x+2, Stop Zone

;Gui, Tab, Settings
; // Auto Ultimates Group Box
Gui, MyWindow:Add, GroupBox, xs+110 ys r14 w110,
Gui, MyWindow:Add, CheckBox, w70 xp+10 vAutoUlts Checked%gbSpamUlts% Section, AutoUlts
;Gui, MyWindow:Add, CheckBox, vAUCD Checked , LOL :)
Gui, MyWindow:Add, Edit, h18 vnewStopUltZone w33 BackGround2C2F33, % gStopUltZone
Gui, MyWindow:Add, Text, x+2, Stop Zone
loop, 12
{
    sv := g_ultToggles[A_Index] ; value of the speciic seat
    Gui, MyWindow:Add, CheckBox, xs vAU%A_Index%  Checked%sv%, S%A_Index%
}

; // Do Chests Group Box
Gui, MyWindow:Add, GroupBox, xs+110 ys r6 w235,
Gui, MyWindow:Add, CheckBox, w80 xp+10 vgDoChestsID Checked%gDoChests% Section, DoChests
Gui, MyWindow:Add, Text, +wrap y+5 r2 w180, Enable server calls to buy and open chests during stack restart
;Gui, MyWindow:Add, Text, vgDoChestsID x+2 w%GUITabTxtW%, % gDoChests
Gui, MyWindow:Add, Edit, xs ys+50 h20 vgSCMinGemCountID y+5 w40, % gSCMinGemCount
Gui, MyWindow:Add, Text, x+2, Gems Reserve (don't spend) ; Maintain this many gems when buying chests:
Gui, MyWindow:Add, Edit, xs ys+78 h20 vgSCBuySilversID w40, % gSCBuySilvers
Gui, MyWindow:Add, Text, x+2, Silvers to Buy(Reserve+)
Gui, MyWindow:Add, Edit, xs ys+98 h20 vgSCSilverCountID w40, % gSCSilverCount
Gui, MyWindow:Add, Text, x+2, Open when Silver count = ;When there are this many silver chests, open them:
Gui, MyWindow:Add, Edit, xs ys+118 h20 vgSCBuyGoldsID w40, % gSCBuyGolds
Gui, MyWindow:Add, Text, x+2, Golds to buy(Reserve+) ;When there are sufficient gems, buy this many gold chests:
Gui, MyWindow:Add, Edit, xs ys+138 h20 vgSCGoldCountID w40, % gSCGoldCount
Gui, MyWindow:Add, Text, x+2, Open when Gold count = ;When there are this many gold chests, open them:

; // Do Stacks Group Box
Gui, MyWindow:Add, GroupBox, xs-10 y+15 r7 w235,
Gui, MyWindow:Add, CheckBox, w80 xp+10 vgDoStacksID Checked%gDoStacks% Section, DoStacks
Gui, MyWindow:Add, Edit, xs ys+20 h20 vNewgAreaLow w40, % gAreaLow
Gui, MyWindow:Add, Text, x+5, Farm SB stacks AFTER ; this zone
Gui, MyWindow:Add, Edit, xs ys+40 h20 vNewgMinStackZone w40, % gMinStackZone
Gui, MyWindow:Add, Text, x+5, Briv farm min zone
Gui, MyWindow:Add, Edit, xs ys+60 h20 vNewSBTargetStacks w40, % gSBTargetStacks
Gui, MyWindow:Add, Text, x+5, Haste Stack goal for next run
Gui, MyWindow:Add, Edit, xs ys+88 h20 vNewgSBTimeMax w45, % gSBTimeMax
Gui, MyWindow:Add, Text, x+5, Briv farm max time(ms)
Gui, MyWindow:Add, Edit, xs ys+108 h20 vNewRestartStackTime w45, % gRestartStackTime
Gui, MyWindow:Add, Text, x+5, Delay offline stacking 0-Off ; (ms) client remains closed for Briv Restart Stack (0 disables)
Gui, MyWindow:Add, Edit, xs ys+128 h20 vNewSwapSleep w45, % gSwapSleep
Gui, MyWindow:Add, Text, x+5, Briv swap sleep time (ms)
Gui, MyWindow:Add, Edit, xs ys+148 h20 vNewDashSleepTime w45, % gDashSleepTime
Gui, MyWindow:Add, Text, x+5, Dash wait max time 0-Ooff

Gui, MyWindow:Add, Edit, vNewHewUlt x15 y+40 w45, % gHewUlt
Gui, MyWindow:Add, Text, x+5, `Hew's ultimate key (0 disables)
;Gui, MyWindow:Add, Checkbox, vgbSpamUlts Checked%gbSpamUlts% x15 y+10, Use ults 2-9 after intial champion leveling
;Gui, MyWindow:Add, Checkbox, vgbCancelAnim Checked%gbCancelAnim% x15 y+5, Swap to 'e' formation to cancel Briv's jump animation
Gui, MyWindow:Add, Checkbox, vgAvoidBosses Checked%gAvoidBosses% x15 y+10, Avoid Bosses (4x Briv only) ;Swap to 'e' formation when `on boss zones
Gui, MyWindow:Add, Checkbox, vgbCDLeveling Checked%gbCDLeveling% x15 y+5, `Uncheck `if using a familiar `on `click damage
Gui, MyWindow:Add, Checkbox, vgb100xCDLev Checked%gb100xCDLev% x15 y+5, Enable ctrl (x100) leveling of `click damage
Gui, MyWindow:Add, Checkbox, vgbSFRecover Checked%gbSFRecover% x15 y+5, Enable manual resets to recover from failed Briv stacking
Gui, MyWindow:Add, Checkbox, vgStackFailConvRecovery Checked%gStackFailConvRecovery% x15 y+5, Enable manual resets to recover from failed Briv stack conversion
Gui, MyWindow:Add, Edit, vgCoreTargetArea x15 y+5 w45, % gCoreTargetArea
Gui, MyWindow:Add, Text, x+5, Core Target Area
Gui, MyWindow:Add, Checkbox, vgModronResetCheckEnabled Checked%gModronResetCheckEnabled% x+5, Have script check for Modron reset level
Gui, MyWindow:Add, Button, x15 y+20 gChangeInstallLocation_Clicked, Change Install Path
strGUI := "Default installation path may be EGS client specific. If launch fails, make a " 
        . "shortcut through EGS and replace default path with new app launcher `ID."
Gui, MyWindow:Add, Text, x+5 w%GUITabTxtW%, %strGUI%
;----------------- <HOTKEY
Gui, MyWindow:Add, Hotkey, % "x15 y+15 w50 h25 vgPauseHotkey gHotKeyChanged", %gPauseHotkey% 
;Gui, MyWindow:Add, Button, x+50 gHotkeyChanged, Change Pause hotkey
;----------------- HOTKEY>

Gui, Tab, Help
;Gui, MyWindow:Font, w700
Gui, MyWindow:Add, Button, x385 y90 w100 gHelp_Clicked, Help
Gui, MyWindow:Add, Text, x15 y%GUITabTxtT%, First, confirm your settings are saved. 
Gui, MyWindow:Add, Text, x15 y+2, 1 = true, yes, or enabled            0 = false, no, or disabled
;Gui, MyWindow:Font, w400
Gui, MyWindow:Add, GroupBox, w%GUITabTxtW% h45, Current level string to DirectInput
Gui, Mywindow:Add, Text, vFKeysID w450 xp+8 yp+20, % g_FKeys
Gui, MyWindow:Add, Text, vgStopLevZoneID x15 y+20 w%GUITabTxtW%, % gStopLevZone . "    Use Fkey leveling while below this zone"
Gui, MyWindow:Add, Text, vgAreaLowID x15 y+5 w%GUITabTxtW%, % gAreaLow . "    Farm SB stacks AFTER this zone"
Gui, MyWindow:Add, Text, x15 y+5, Minimum zone Briv can farm SB stacks on: 
Gui, MyWindow:Add, Text, vgMinStackZoneID x+2 w%GUITabTxtW%, % gMinStackZone 
Gui, MyWindow:Add, Text, x15 y+5, Target Haste stacks for next run: 
Gui, MyWindow:Add, Text, vgSBTargetStacksID x+2 w%GUITabTxtW%, % gSBTargetStacks
Gui, MyWindow:Add, Text, x15 y+5, Max time script will farm SB Stacks normally: 
Gui, MyWindow:Add, Text, vgSBTimeMaxID x+2 w%GUITabTxtW%, % gSBTimeMax
Gui, MyWindow:Add, Text, x15 y+5, Maximum time (ms) script will wait for Dash: 
Gui, MyWindow:Add, Text, vDashSleepTimeID x+2 w%GUITabTxtW%, % gDashSleepTime
Gui, MyWindow:Add, Text, x15 y+5, Hew's ultimate key: 
Gui, MyWindow:Add, Text, vgHewUltID x+2 w%GUITabTxtW%, % gHewUlt
Gui, MyWindow:Add, Text, x15 y+5, Time (ms) client remains closed for Briv Restart Stack:
Gui, MyWindow:Add, Text, vgRestartStackTimeID x+2 w%GUITabTxtW%, % gRestartStackTime
Gui, MyWindow:Add, Text, x15 y+5, Use ults 2-9 after initial champion leveling:
Gui, MyWindow:Add, Text, vgbSpamUltsID x+2 w%GUITabTxtW%, % gbSpamUlts
Gui, MyWindow:Add, Text, x15 y+5, Swap to 'e' formation to cancle Briv's jump animation:
Gui, MyWindow:Add, Text, vgbCancelAnimID x+2 w%GUITabTxtW%, % gbCancelAnim
Gui, MyWindow:Add, Text, x15 y+5, Briv swap sleep time (ms):
Gui, MyWindow:Add, Text, vgSwapSleepID x+2 w%GUITabTxtW%, % gSwapSleep
Gui, MyWindow:Add, Text, x15 y+5, Swap to 'e' formation when on boss zones:
Gui, MyWindow:Add, Text, vgAvoidBossesID x+2 w%GUITabTxtW%, % gAvoidBosses
Gui, MyWindow:Add, Text, x15 y+5, Using a familiar on click damage:
Gui, MyWindow:Add, Text, vgbCDLevelingID x+2 w%GUITabTxtW%, % gbCDLeveling
Gui, MyWindow:Add, Text, x15 y+5, Enable ctrl (x100) leveling of `click damage:
Gui, MyWindow:Add, Text, vgb100xCDLevID x+2 w%GUITabTxtW%, % gb100xCDLev
Gui, MyWindow:Add, Text, x15 y+5, Enable manual resets to recover from failed Briv stacking:
Gui, MyWindow:Add, Text, vgbSFRecoverID x+2 w%GUITabTxtW%, % gbSFRecover
Gui, MyWindow:Add, Text, x15 y+5, Enable manual resets to recover from failed Briv stack conversion:
Gui, MyWindow:Add, Text, vgStackFailConvRecoveryID x+2 w%GUITabTxtW%, % gStackFailConvRecovery
Gui, MyWindow:Add, Text, x15 y+5, Enable script to check for Modron reset level:
Gui, MyWindow:Add, Text, vgModronResetCheckenabledID x+2 w%GUITabTxtW%, % gModronResetCheckEnabled
Gui, MyWindow:Add, Text, x15 y+5, Core Reset Level:
Gui, MyWindow:Add, Text, vgCoreTargetAreaID x+2 w%GUITabTxtW%, % gCoreTargetArea
Gui, MyWindow:Add, Text, x15 y+10, Install Path:
Gui, MyWindow:Add, Edit, vICPath x15 y+10 w%GUITabTxtW%, % gInstallPath
Gui, MyWindow:Add, Text, +wrap w450 vgInstallPathID x15 y+2 w%GUITabTxtW% r3, % gInstallPath
Gui, MyWindow:Add, Text, x15 y+10 w%GUITabTxtW% r5, Still having trouble? Take note of the information on the debug tab and ask for help in the scripting channel on the official discord.

statTabTxtWidth := 
Gui, Tab, Stats
Gui, MyWindow:Font, w700
Gui, MyWindow:Add, Text, x15 y%GUITabTxtT%, Stats updated continuously (mostly):
Gui, MyWindow:Font, w400
Gui, MyWindow:Add, Text, x15 y+10 %statTabTxtWidth%, SB Stack `Count: 
Gui, MyWindow:Add, Text, vgStackCountSBID x+2 w50, % gStackCountSB
;Gui, MyWindow:Add, Text, vReadSBStacksID x+2 w200,
Gui, MyWindow:Add, Text, x15 y+2 %statTabTxtWidth%, Haste Stack `Count:
Gui, MyWindow:Add, Text, vgStackCountHID x+2 w50, % gStackCountH
;Gui, MyWindow:Add, Text, vReadHasteStacksID x+2 w200,
Gui, MyWindow:Add, Text, x15 y+10 %statTabTxtWidth%, Current `Run `Time:
Gui, MyWindow:Add, Text, vdtCurrentRunTimeID x+2 w50, 0 ;% dtCurrentRunTime
Gui, MyWindow:Add, Text, x15 y+2 %statTabTxtWidth%, Total `Run `Time:
Gui, MyWindow:Add, Text, vdtTotalTimeID x+2 w50, % dtTotalTime
Gui, MyWindow:Font, w700
Gui, MyWindow:Add, Text, x15 y+10, Stats updated once per run:
Gui, MyWindow:Font, w400
Gui, MyWindow:Add, Text, x15 y+10 %statTabTxtWidth%, Total `Run `Count:
Gui, MyWindow:Add, Text, vgTotal_RunCountID x+2 w50, % gTotal_RunCount
Gui, MyWindow:Add, Text, x15 y+2 %statTabTxtWidth%, Previous `Run `Time:
Gui, MyWindow:Add, Text, vgPrevRunTimeID x+2 w50, % gPrevRunTime
Gui, MyWindow:Add, Text, x15 y+2 %statTabTxtWidth%, Fastest `Run `Time:
Gui, MyWindow:Add, Text, vgFastRunTimeID x+2 w50, 
Gui, MyWindow:Add, Text, x15 y+2 %statTabTxtWidth%, Slowest `Run `Time:
Gui, MyWindow:Add, Text, vgSlowRunTimeID x+2 w50, % gSlowRunTime
Gui, MyWindow:Add, Text, x15 y+2 %statTabTxtWidth%, Avg. `Run `Time:
Gui, MyWindow:Add, Text, vgAvgRunTimeID x+2 w50, % gAvgRunTime
Gui, MyWindow:Add, Text, x15 y+2 %statTabTxtWidth%, Fail `Run `Time:
Gui, MyWindow:Add, Text, vgFailRunTimeID x+2 w50, % gFailRunTime    
Gui, MyWindow:Add, Text, x15 y+2 %statTabTxtWidth%, Fail Stack Conversion:
Gui, MyWindow:Add, Text, vgFailedStackConvID x+2 w50, % gFailedStackConv
Gui, MyWindow:Add, Text, x15 y+2 %statTabTxtWidth%, Fail Stacking:
Gui, MyWindow:Add, Text, vgFailedStackingID x+2 w50, % gFailedStacking
Gui, MyWindow:Font, cBlue w700
Gui, MyWindow:Add, Text, x15 y+10 %statTabTxtWidth%, Bosses per hour:
Gui, MyWindow:Add, Text, vgbossesPhrID x+2 w50, % gbossesPhr
Gui, MyWindow:Font, cGreen
Gui, MyWINdow:Add, Text, x15 y+10, Total Gems:
Gui, MyWindow:Add, Text, vGemsTotalID x+2 w50, % GemsTotal
Gui, MyWINdow:Add, Text, x15 y+2, Gems per hour:
Gui, MyWindow:Add, Text, vGemsPhrID x+2 w200, % GemsPhr
Gui, MyWindow:Font, cRed
Gui, MyWINdow:Add, Text, x15 y+10, Total Black Viper Red Gems:
Gui, MyWindow:Add, Text, vRedGemsTotalID x+2 w50, % RedGemsTotal
Gui, MyWINdow:Add, Text, x15 y+2, Red Gems per hour:
Gui, MyWindow:Add, Text, vRedGemsPhrID x+2 w200, % RedGemsPhr
Gui, MyWindow:Font, cSilver w400
;Gui, MyWindow:Font, w700
Gui, MyWindow:Add, Text, x15 y+10, `Loop: 
Gui, MyWindow:Add, Text, vgLoopID x+2 w450, Initialized...Waiting for Run Command
global hZLoop := 0
Gui, MyWindow:Font, cSilver s9
GUITabTxtW := GUITabTxtW +20
rowCt := gDoChests ? 15 : 25
Gui, MyWindow:Add, Edit, x7 y+5 r%rowCt% w%GUITabTxtW% HwndhZLoop vZLoop ReadOnly, %gLoopID%
Gui, MyWindow:Font, w400

if (gDoChests)
{
    Gui, MyWindow:Font, w700
    Gui, MyWindow:Add, Text, x15 y+10 w300, Chest Data:
    Gui, MyWindow:Font, w400
    Gui, MyWindow:Add, Text, x15 y+5, Starting Gems Spent: 
    Gui, MyWindow:Add, Text, vgSCRedRubiesSpentStartID x+2 w200,
    Gui, MyWindow:Add, Text, x15 y+5, Starting Silvers Opened: 
    Gui, MyWindow:Add, Text, vgSCSilversOpenedStartID x+2 w200,
    Gui, MyWindow:Add, Text, x15 y+5, Starting Golds Opened: 
    Gui, MyWindow:Add, Text, vgSCGoldsOpenedStartID x+2 w200,    
    Gui, MyWindow:Add, Text, x15 y+5, Silvers Opened: 
    Gui, MyWindow:Add, Text, vgSCSilversOpenedID x+2 w200,
    Gui, MyWindow:Add, Text, x15 y+5, Golds Opened: 
    Gui, MyWindow:Add, Text, vgSCGoldsOpenedID x+2 w200,
    Gui, MyWindow:Add, Text, x15 y+5, Gems Spent: 
    Gui, MyWindow:Add, Text, vGemsSpentID x+2 w200,
}


Gui, Tab, Debug
Gui, MyWindow:Font, cSilver s11 ;
Gui, MyWindow:Font, w700
;Gui, MyWindow:Add, Text, x15 y35, Timers:
Gui, MyWindow:Font, w400
Gui, MyWindow:Add, Button, x390 y150 w100 gRead_AdvID, Read AdvID
Gui, MyWindow:Add, Text, x15 y%GUITabTxtT% w100, Elapsed Time:  ; TODO: what elapsed time? this seems to be arbitrary short periods, do they need to be displayed?
Gui, MyWindow:Add, Text, vElapsedTimeID x+2 w100, 0
Gui, MyWindow:Add, Text, x200 y%GUITabTxtT% w100, Elapsed Zone Time:
Gui, MyWindow:Add, Text, vZoneTimeID x+2 w100, % ZoneTime := 0

Gui, MyWindow:Font, w700
Gui, MyWindow:Add, Text, x15 y+15, Server Call Variables         (ver %SC_ScriptVersion%)
Gui, MyWindow:Font, w400
Gui, MyWindow:Add, Text, x15 y+5 w200, advtoload:
Gui, MyWindow:Add, Text, vadvtoloadID x+2 w300, % advtoload
Gui, MyWindow:Add, Text, x15 y+5 w200, current_adventure_id:
Gui, MyWindow:Add, Text, vCurrentAdventureID x+2 w300, % current_adventure_id := 0
;Gui, MyWindow:Add, Button, x15 y100 w100 gDiscord_Clicked, Discord

Gui, MyWindow:Add, Text, x15 y+5 w200, InstanceID:
Gui, MyWindow:Add, Text, vInstanceIDID x+2 w300, % InstanceID := 0
Gui, MyWindow:Add, Text, x15 y+5 w200, ActiveInstance:
Gui, MyWindow:Add, Text, vActiveInstanceID x+2 w300, % ActiveInstance := 0

Gui, MyWindow:Font, w700
Gui, MyWindow:Add, Text, x15 y+15, Memory Reads                    (ver %MF_ScriptVersion%)
Gui, MyWindow:Font, w400
Gui, MyWindow:Add, Text, x15 y+10 w200, Current Zone: 
Gui, MyWindow:Add, Text, vReadCurrentZoneID x+2 w200, %PreciseTime% `t 00000
Gui, MyWindow:Add, Text, x15 y+5 w200, Highest Zone: 
Gui, MyWindow:Add, Text, vReadHighestZoneID x+2 w200, %PreciseTime% `t 00000
Gui, MyWindow:Add, Text, x15 y+5 w200, Quest Remaining: 
Gui, MyWindow:Add, Text, vReadQuestRemainingID x+2 w200, %PreciseTime% `t 00000
Gui, MyWindow:Add, Text, x15 y+5 w200, TimeScaleMultiplier: 
Gui, MyWindow:Add, Text, vReadTimeScaleMultiplierID x+2 w200, %PreciseTime% `t 00000
Gui, MyWindow:Add, Text, x15 y+5 w200, Transitioning: 
Gui, MyWindow:Add, Text, vReadTransitioningID x+2 w200, %PreciseTime% `t 00000
Gui, MyWindow:Add, Text, x15 y+5 w200, SB Stacks: 
Gui, MyWindow:Add, Text, vReadSBStacksID x+2 w200, %PreciseTime% `t 00000
Gui, MyWindow:Add, Text, x15 y+5 w200, Haste Stacks: 
Gui, MyWindow:Add, Text, vReadHasteStacksID x+2 w200, %PreciseTime% `t 00000
Gui, MyWindow:Add, Text, x15 y+5 w200, Resetting: 
Gui, MyWindow:Add, Text, vReadResettingID x+2 w200, %PreciseTime% `t 00000
Gui, MyWindow:Add, Text, x15 y+5 w200, Screen Width: 
Gui, MyWindow:Add, Text, vReadScreenWidthID x+2 w200, %PreciseTime% `t 00000
Gui, MyWindow:Add, Text, x15 y+5 w200, Screen Height: 
Gui, MyWindow:Add, Text, vReadScreenHeightID x+2 w200, %PreciseTime% `t 00000
;Gui, MyWindow:Add, Text, x15 y+5, ReadChampLvlBySlot: 
;Gui, MyWindow:Add, Text, vReadChampLvlBySlotID x+2 w200,
Gui, MyWindow:Add, Text, x15 y+5 w200, Monsters Spawned:
Gui, MyWindow:Add, Text, vReadMonstersSpawnedID x+2 w200, %PreciseTime% `t 00000
Gui, MyWindow:Add, Text, x15 y+5 w200, ChampLvlByID:
Gui, MyWindow:Add, Text, vReadChampLvlByIDID x+2 w200, %PreciseTime% `t 00000
;Gui, MyWindow:Add, Text, x15 y+5, ReadChampSeatByID:
;Gui, MyWindow:Add, Text, vReadChampSeatByIDID x+2 w200,
;Gui, MyWindow:Add, Text, x15 y+5, ReadChampIDbySlot:
;Gui, MyWindow:Add, Text, vReadChampIDbySlotID x+2 w200,
Gui, MyWindow:Add, Text, x15 y+5 w200, Core Target Area:
Gui, MyWindow:Add, Text, vReadCoreTargetAreaID x+2 w200, %PreciseTime% `t 00000
Gui, MyWindow:Add, Text, x15 y+5 w200, Core XP: 
Gui, MyWindow:Add, Text, vReadCoreXPID x+2 w200, %PreciseTime% `t 00000
Gui, MyWindow:Add, Text, x15 y+5 w200, Gems: 
Gui, MyWindow:Add, Text, vReadGemsID x+2 w200, %PreciseTime% `t 00000
Gui, MyWindow:Add, Text, x15 y+5 w200, Gems Spent: 
Gui, MyWindow:Add, Text, vReadGemsSpentID x+2 w200, %PreciseTime% `t 00000
Gui, MyWindow:Add, Text, x15 y+5 w200, Red Gems: 
Gui, MyWindow:Add, Text, vReadRedGemsID x+2 w200, %PreciseTime% `t 00000
Gui, MyWindow:Add, Text, x15 y+5 w200, ChampBenchedByID: 
Gui, MyWindow:Add, Text, vReadChampBenchedByIDID x+2 w200, %PreciseTime% `t 00000
Gui, MyWindow:Add, Text, x15 y+180 w40, UserID: 
Gui, MyWindow:Add, Text, vReadUserIDID x+2 w55, 00000
Gui, MyWindow:Add, Text, x+2 w30, Hash: 
Gui, MyWindow:Font, w200
Gui, MyWindow:Add, Text, vReadUserHashID x+2 w400, 0000000000000000000000000000000
Gui, MyWindow:Font, w400

Gui, Tab, Resources
Gui, MyWindow:Font, cSilver s11 ;
Gui, MyWindow:Add, Button, x15 y100 w100 gDiscord_Clicked, Discord
Gui, MyWindow:Add, Button, x15 y+15 w100 gByteGlow_Clicked, Byteglow
Gui, MyWindow:Add, Button, x15 y+15 w100 gKleho_Clicked, Kleho
Gui, MyWindow:Add, Button, x15 y+15 w100 gSoul_Clicked, Soul's
Gui, MyWindow:Add, Button, x15 y+15 w100 gFenomas_Clicked, Fenomas's
Gui, MyWindow:Add, Button, x15 y+15 w100 gXeio_Clicked, Xeio's Code Redeemer

;banur:
;clipboard := "copy paste version"
;msgbox "version copied! paste into discord"

global Zeelog := CurrentTime . " Initializing ..."
global hZlog := 0
Gui, Tab, ZDebug
GUITabZDBW := GUITabTxtW +20
Gui, MyWindow:Add, Edit, r40 w%GUITabZDBW% x9 y%GUITabTxtT% HwndhZlog vZlog ReadOnly, %Zeelog%
;Gui, Add, Edit, r10 w500 hwndhMyEdit vMyEdit, % GenText("a", 60000)
Gui, MyWindow:Font, cSilver s11 ;
Gui, MyWindow:Font, w700

;server call functions and variables Included after GUI so chest tabs maybe non optimal way of doing it
#include IC_ServerCallFunctions.ahk

Gui, MyWindow:Show

Gui, InstallGUI:New
Gui, InstallGUI:Add, Edit, vNewInstallPath x15 y+10 w%GUITabTxtW% r5, % gInstallPath
Gui, InstallGUI:Add, Button, x15 y+25 gInstallOK_Clicked, Save and `Close
Gui, InstallGUI:Add, Button, x+100 gInstallCancel_Clicked, `Cancel

;----------------- <HOTKEY
Hotkey, %gPauseHotkey%, PauseScript, On

HotkeyChanged()
{
    ;str := "Hotkey changed: " gPauseHotkey
    ;LogMsg("Hotkey changed: " gPauseHotkey, true)
	Hotkey, %gPauseHotkey%, PauseScript, Off
	Gui, Submit, NoHide
	if (!gPauseHotkey)
	{
		gPauseHotkey = %gDefaultPauseHotkey%
		GuiControl,, msctls_hotkey321, SC029
        ;LogMsg("Hotkey changed: " gPauseHotkey, true)
	}
	Hotkey, %gPauseHotkey%, PauseScript, On
}

PauseScript()
{
	Pause
	gPrevLevelTime := A_TickCount
	return
}
;----------------- HOTKEY>

InstallCancel_Clicked:
{
    GuiControl, InstallGUI:, NewInstallPath, %gInstallPath%
    Gui, InstallGUI:Hide
    Return
}

InstallOK_Clicked:
{
    Gui, Submit, NoHide
    gInstallPath := NewInstallPath
    GuiControl, MyWindow:, gInstallPathID, %gInstallPath%
    IniWrite, %gInstallPath%, Usersettings.ini, Section1, GameInstallPath
    Gui, InstallGUI:Hide
    Return
}

ChangeInstallLocation_Clicked:
{
    Gui, InstallGUI:Show
    Return
}

; TODO: implement explorer selection on the Resources GUI that verifies exe paths,
; Also allow user to enter their own name/path in addition to those detected?
strBrowser := "chrome.exe "
Discord_Clicked:
{
    Run chrome.exe "https://discord.gg/idlechampions" " --new-window "
    Return
}

ByteGlow_Clicked:
{
    Run chrome.exe "https://ic.byteglow.com/user" " --new-window "
    Return
}

Kleho_Clicked:
{
    Run chrome.exe "https://idle.kleho.ru/about/" " --new-window "
    Return
}

Xeio_Clicked:
{
    Run chrome.exe "chrome-extension://cblhleinomjkhhekobghobnofjbnpgag/dst/options.html"
    Return
}

Soul_Clicked:
{
    Run chrome.exe "http://idlechampions.soulreaver.usermd.net/achievements.html" " --new-window "
    Return
}

Fenomas_Clicked:
{    
    Run chrome.exe "https://fenomas.com/idle/" " --new-window "
    Return
}

Read_AdvID:
{
    UpdateAdvID() 
    return
}

UpdateAdvID()
{
    advtoload := ReadCurrentObjID(0)
    GuiControl, MyWindow:, advtoloadID, % advtoload
    return advtoload     
}

; courtesy of banur@Discord
Help_clicked:
{
    clipboard = %MF_ScriptDate% `n%MF_ScriptVersion% `n%SC_ScriptDate% `n%SC_ScriptVersion% `n %A_AhkVersion%
    msgbox %MF_ScriptDate% `n%MF_ScriptVersion% `n%SC_ScriptDate% `n%SC_ScriptVersion% `n%A_AhkVersion%`n`nVersion data copied!`nPaste into Discord.
    return
}

; // WriteSettingToINI ////////////////////////////////////////////////////////////////////////////
; // Encapsulates writing values used by the script to the stored INI file UserSettings.ini
; // NOTE: uses the only one default section Section 1
; // myKeyName - string with the name of the item in the INI file
; // myVal     - value to write for the myKeyName provided
WriteSettingToINI(myKeyName, myVal, mySection := "Section1")
{	
    ;MsgBox,,, %myKeyName% %myVal%
    IniWrite, %myVal%, UserSettings.ini, %mySection%, %myKeyName%
    LogMsg("INI Write in key " . myKeyName . " the value " . myVal)
    return myVal
	;IniRead, mytemp, UserSettings.ini, Section1, %myKeyName%, %myDefVal%
}

Save_Clicked:
{
    Gui, Submit, NoHide
    ; Write the AutoLevel stuff to file
    ; 1. Autolevel on/off
    WriteSettingToINI("AutoLevel", AutoLevel, "AutoLevel")
    ; 2. Write the CD settings
    WriteSettingToINI("ACD", ACD, "AutoLevel")
    WriteSettingToINI("SLCD", SLCD, "StopAutoAtLevel")
    WriteSettingToINI("AutoUlts", AutoUlts, "AutoUltimate")
    WriteSettingToINI("AUCD", AUCD, "AutoUltimate")
    g_FKeys := ; Reset the Active F keys array, rebuild and write it to the file in the loop
    Loop, 12
    {
        ; Write the Seat toggles
        t := WriteSettingToINI("ALSeat" . A_Index, AL%A_Index%, "AutoLevel")
        g_levToggles[A_Index] := t
        if (t == 1)
            g_FKeys = %g_FKeys%{F%A_Index%}
        
        ; Write the Level To values
		t := WriteSettingToINI("ALStopSeat" . A_Index, StopAt%A_Index%, "StopAutoAtLevel")
        g_StopAt[A_Index] := t ;SLevel%A_Index%                      ; LJ

        ; Write the AutoUlt values
        t := WriteSettingToINI("U" . A_Index, AU%A_Index%, "AutoUltimate")
        g_ultToggles[A_Index] := t 
    }
    GuiControl, MyWindow:, FkeysID, % g_FKeys ; Restore the GUI display of the levelling string
    GuiControl, MyWindow:, SLCD, %SLCD%
    gAreaLow := NewgAreaLow
    GuiControl, MyWindow:, gAreaLowID, % gAreaLow
    IniWrite, %gAreaLow%, UserSettings.ini, Section1, AreaLow
    gMinStackZone := NewgMinStackZone
    GuiControl, MyWindow:, gMinStackZoneID, % gMinStackZone
    IniWrite, %gMinStackZone%, Usersettings.ini, Section1, MinStackZone
    gSBTargetStacks := NewSBTargetStacks
    GuiControl, MyWindow:, gSBTargetStacksID, % gSBTargetStacks
    IniWrite, %gSBTargetStacks%, UserSettings.ini, Section1, SBTargetStacks
    gSBTimeMax := NewgSBTimeMax
    GuiControl, MyWindow:, gSBTimeMaxID, %gSBTimeMax%
    IniWrite, %gSBTimeMax%, Usersettings.ini, Section1, SBTimeMax
    gDashSleepTime := NewDashSleepTime
    GuiControl, MyWindow:, DashSleepTimeID, % gDashSleepTime
    IniWrite, %gDashSleepTime%, UserSettings.ini, Section1, DashSleepTime
    gStopLevZone := newStopLevZone
    GuiControl, MyWindow:, gStopLevZoneID, % gStopLevZone
    IniWrite, %gStopLevZone%, UserSettings.ini, Section1, ContinuedLeveling
    gHewUlt := NewHewUlt
    GuiControl, MyWindow:, gHewUltID, % gHewUlt
    IniWrite, %gHewUlt%, UserSettings.ini, Section1, HewUlt
    GuiControl, MyWindow:, gbSpamUltsID, % gbSpamUlts
    IniWrite, %gbSpamUlts%, UserSettings.ini, Section1, Ults
    GuiControl, MyWindow:, gbCancelAnimID, % gbCancelAnim
    IniWrite, %gbCancelAnim%, UserSettings.ini, Section1, BrivSwap
    GuiControl, MyWindow:, gAvoidBossesID, % gAvoidBosses
    IniWrite, %gAvoidBosses%, UserSettings.ini, Section1, AvoidBosses
    GuiControl, MyWindow:, gbCDLevelingID, % gbCDLeveling
    IniWrite, %gbCDLeveling%, UserSettings.ini, Section1, ClickLeveling
    GuiControl, MyWindow:, gb100xCDLevID, % gb100xCDLev
    IniWrite, %gb100xCDLev%, UserSettings.ini, Section1, CtrlClickLeveling
    GuiControl, MyWindow:, gbSFRecoverID, % gbSFRecover
    IniWrite, %gbSFRecover%, UserSettings.ini, Section1, StackFailRecovery
    GuiControl, MyWindow:, gStackFailConvRecoveryID, % gStackFailConvRecovery
    IniWrite, %gStackFailConvRecovery%, UserSettings.ini, Section1, StackFailConvRecovery
    gSwapSleep := NewSwapSleep
    GuiControl, MyWindow:, gSwapSleepID, % gSwapSleep
    IniWrite, %gSwapSleep%, UserSettings.ini, Section1, SwapSleep
    gRestartStackTime := NewRestartStackTime
    GuiControl, MyWindow:, gRestartStackTimeID, % gRestartStackTime
    IniWrite, %gRestartStackTime%, UserSettings.ini, Section1, RestartStackTime
    GuiControl, MyWindow:, gModronResetCheckEnabledID, % gModronResetCheckEnabled
    IniWrite, %gModronResetCheckEnabled%, UserSettings.ini, Section1, ModronResetCheckEnabled
    GuiControl, MyWindow:, gCoreTargetAreaID, % gCoreTargetArea
    IniWrite, %gCoreTargetArea%, UserSettings.ini, Section1, CoreTargetArea
    GuiControl, MyWindow:, gDoChestsID, % gDoChests
    IniWrite, %gDoChests%, UserSettings.ini, Section1, DoChests
    gSCMinGemCount := NewSCMinGemCount
    GuiControl, MyWindow:, gSCMinGemCount, % gSCMinGemCount
    IniWrite, %gSCMinGemCount%, UserSettings.ini, Section1, SCMinGemCount
    gSCBuySilvers := NewSCBuySilvers
    if (gSCBuySilvers > 100)
    gSCBuySilvers := 100
    GuiControl, MyWindow:, gSCBuySilversID, % gSCBuySilvers
    IniWrite, %gSCBuySilvers%, UserSettings.ini, Section1, SCBuySilvers
    gSCSilverCount := NewSCSilverCount
    if (gSCSilverCount > 99)
    gSCSilverCount := 99
    GuiControl, MyWindow:, gSCSilverCountID, % gSCSilverCount
    IniWrite, %gSCSilverCount%, UserSettings.ini, Section1, SCSilverCount
    gSCBuyGolds := NewSCBuyGolds
    if (gSCBuyGolds > 100)
    gSCBuyGolds := 100
    GuiControl, MyWindow:, gSCBuyGoldsID, % gSCBuyGolds
    IniWrite, %gSCBuyGolds%, UserSettings.ini, Section1, SCBuyGolds
    gSCGoldCount := NewSCGoldCount
    if (gSCGoldCount > 99)
    gSCGoldCount := 99
    GuiControl, MyWindow:, gSCGoldCountID, % gSCGoldCount
    IniWrite, %gSCGoldCount%, UserSettings.ini, Section1, SCGoldCount
    ;----------------- <HOTKEY
	GuiControl, MyWindow:, msctls_hotkey321, % gPauseHotkey
	IniWrite, %gPauseHotkey%, UserSettings.ini, Section1, PauseHotkey	
	;----------------- <HOTKEY
    return
}

Reload_Clicked:
{
    Reload
    return
}

Run_Clicked:
{
    gStartTime := A_TickCount
    gRunStartTime := A_TickCount
    ;SetupStrings()
    GemFarm()
    return
}

Pause_Clicked:
{
    PauseScript()
    ;Pause
    ;gPrevLevelTime := A_TickCount
    return
}

; LJ
Screen_Clicked: ;LJ TODO User selected Res, Monitor -- Probably remove these for general users till done
{
	WinGetPos,,,ww,,Idle Champions

	if (ww = 1936 or ww = 1920)
		gfullScreen = 0
	else
		gfullScreen = 1
    return
}
; LJ
Set_Screen() ;LJ TODO User selected Res, Monitor -- Probably remove these for general users till done
{
	if not (gScreenEnable)
		return
	WinGetPos,,,ww,,ahk_exe IdleDragons.exe

	if (gfullScreen and ww != 1920)
	{
		WinSet, Style, -0xC40000, ahk_exe IdleDragons.exe
		WinMove, ahk_exe IdleDragons.exe, , -1920, 0, 1920, 1030
	}
	else if (gfullScreen = 0 and ww !=600)
	{
		WinSet, Style, -0xC40000, ahk_exe IdleDragons.exe
		WinMove, ahk_exe IdleDragons.exe, , -1920, 0, 600, 500
	}
return
}

MyWindowGuiClose() 
{
    MsgBox 4,, Are you sure you want to `exit?
    IfMsgBox Yes
        ExitApp
    IfMsgBox No
        return True
}

$~::
{
    PauseScript()
    return
}
;    Pause
;    gPrevLevelTime := A_TickCount
;return

Edit_Prepend(handl, Text ) 
{ ;www.autohotkey.com/community/viewtopic.php?p=565894#p565894
    ;MsgBox %handl%
    DllCall( "SendMessage", UInt, handl, UInt,0xB1, UInt,0 , UInt,0 ) ; EM_SETSEL
    DllCall( "SendMessage", UInt, handl, UInt,0xC2, UInt,0 , UInt,&Text ) ; EM_REPLACESEL
    DllCall( "SendMessage", UInt, handl, UInt,0xB1, UInt,0 , UInt,0 ) ; EM_SETSEL
    return
}

global fLog := "Zlog.txt"  ; TODO figure out why this line does not actually actuall get called, that is fLog is undefined
LogMsg(msg, display := false)
{
    FormatTime, CurrentTime, , yyyyMMdd HH:mm:ss
    TSmsg := CurrentTime . "." . A_MSec . " " . msg . "`r`n"
    if (display)
    {
        ;SendMessage, 0x0115, 7, 0,, ahk_id %hZlog% ;WM_VSCROLL 
        Edit_Prepend(hZlog, TSmsg)
    }
    FormatTime, today, , yyyyMMdd
    nFn := today " ZMainlog.txt"
    FileAppend, %TSmsg%, %nFn%
    return
}

AppendText(hEdit, ptrText) 
{
    SendMessage, 0x000E, 0, 0,, ahk_id %hEdit% ;WM_GETTEXTLENGTH
    SendMessage, 0x00B1, ErrorLevel, ErrorLevel,, ahk_id %hEdit% ;EM_SETSEL
    SendMessage, 0x00C2, False, ptrText,, ahk_id %hEdit% ;EM_REPLACESEL
    return
}

SetupStrings()
{
    FileName = textfile.txt
    text =
    (
    First Line
    Second Line
    Third Line
    )
    FileAppend, %text%, %FileName%
    Loop, Read, %FileName%, NewFile.txt
    {
        If (InStr(A_LoopReadLine, "Second Line")) {
            NewData := StrReplace(A_LoopReadLine, "Second Line", "New Text")
            FileAppend, % NewData "`r`n"
        } Else {
            FileAppend, % A_LoopReadLine "`r`n"
        }
    }
    FileDelete, %FileName%
    FileMove, NewFile.txt, %FileName%
    return    
}

;Solution by Meviin to release Alt, Shift, and Ctrl keys when they get stuck during script use.
ReleaseStuckKeys()                                           
{                                                            
    if GetKeyState("Alt") && !GetKeyState("Alt", "P")        
        Send {Alt up}                                          
    if GetKeyState("Shift") && !GetKeyState("Shift", "P")    
        Send {Shift up}                                                                                                
    if GetKeyState("Control") && !GetKeyState("Control", "P")
        Send {Control up}                                      
    return                                                  
}


SafetyCheck(delay := 5000)
{
    static lastRan := 0
    static scCount := 0
    if (lastRan + delay < A_TickCount)
    {
        While (Not WinExist("ahk_exe IdleDragons.exe")) 
        {
            Run, %gInstallPath%
            ;Run, "C:\Program Files (x86)\Steam\steamapps\common\IdleChampions\IdleDragons.exe"
            StartTime := A_TickCount
            ElapsedTime := 0
            UpdateStatusEdit("Opening IC")        ;GuiControl, MyWindow:, gloopID, Opening IC
            While (Not WinExist("ahk_exe IdleDragons.exe") AND ElapsedTime < 60000) 
            {
                Sleep 1000
                ElapsedTime := UpdateElapsedTime(StartTime)
                UpdateStatTimers()
            }
            If (Not WinExist("ahk_exe IdleDragons.exe"))
                Return

            ;the script doesn't update GUI with elapsed time while IC is loading, opening the address, or readying base address, to minimize use of CPU.
        ; TODO: Separate Gui from operation
            UpdateStatusEdit("Opening Process") ; GuiControl, MyWindow:, gloopID, Opening `Process
            Sleep g_OPdelay_ms
            OpenProcess()
            UpdateStatusEdit("Loading Module Base") ; GuiControl, MyWindow:, gloopID, Loading Module Base
            Sleep gGetAddress
            ModuleBaseAddress()
            ++ResetCount
            GuiControl, MyWindow:, ResetCountID, % ResetCount
            LoadingZoneREV()
            if (gbSpamUlts)
                DoUlts()
                    ;reset timer for checking if IC is stuck on a zone.
            gPrevLevelTime := A_TickCount
        }
        lastRan := A_TickCount
        ++scCount
        GuiControl, MyWindow:, SafetyCheckID, %scCount%
    }
}

/*
; SafetyCheck is executed to ensure we have a valid/running IC application.  If we don't the script will
; attempt to open it for 60 seconds, if it fails, it returns without any further execution/checks
SafetyCheck() 
{
    ReleaseStuckKeys()
    While (Not WinExist("ahk_exe IdleDragons.exe")) 
    {

    }
}
*/

; CloseIC - closes Idle Champions. If IC takes longer than 60 seconds to save and close then the script will force it closed.
; TODO: there is no actual "force it closed" code, it repeats the first attempt loop with 1s sleeps instead of 0.1
;       look into processkill if we really want to kill the IC process
CloseIC()
{
    PostMessage, 0x112, 0xF060,,, ahk_exe IdleDragons.exe   ; TOODO: what message is this sending to the IC executable?
    start := A_TickCount
    UpdateStatusEdit("Saving and Closing IC") ;GuiControl, MyWindow:, gloopID, Saving and Closing IC
    While (WinExist("ahk_exe IdleDragons.exe") AND UpdateElapsedTime(start) < 60000) 
    {
        Sleep 100
        UpdateStatTimers()
    }
    While (WinExist("ahk_exe IdleDragons.exe")) 
    {
        UpdateStatusEdit("Forcing IC Close") ;GuiControl, MyWindow:, gloopID, Forcing IC Close
        PostMessage, 0x112, 0xF060,,, ahk_exe IdleDragons.exe
        sleep 1000
        UpdateStatTimers()
    }
}

; CheckForFailedConv - checks if farmed SB stacks from previous run failed to convert to haste. If so, the script will 
; manually end the adventure to attempt to covnert the stacks, close IC, use a servercall to restart the adventure, and restart IC.
CheckForFailedConv()
{
    stacks := GetNumStacksFarmed()
    If (gStackCountH < gSBTargetStacks AND stacks > gSBTargetStacks AND !gTestReset)
    {
        EndAdventure(1) ; If this sleep is too low it can cancel the reset before it completes. In this case
                        ; that could be good as it will convert SB to Haste and not end the adventure.        
        gStackFail := 2
        return
    }
}

FinishZone()
{
    start := A_TickCount
    UpdateStatusEdit("Finishing Zone") ;GuiControl, MyWindow:, gloopID, Finishing Zone
    while (ReadQuestRemaining(1) AND UpdateElapsedTime(start) < 15000)
    {
        StuffToSpam(0, gLevel_Number) ;TODO: where did this come from?
        UpdateStatTimers()
    }
    return
}

LevelChampByID(ChampID := 1, Lvl := 0, i := 5000, j := "q", seat := 1)
{
    ;seat := ReadChampSeatByID(,, ChampID)
    start := A_TickCount
    UpdateStatusEdit("Levelling Champ " . ChampID . " to " . Lvl) ;GuiControl, MyWindow:, gloopID, Leveling Champ %ChampID% to %Lvl%
    var := "{F" . seat . "}"
    var := var j
    while (ReadChampLvlByID(1,,ChampID) < Lvl AND UpdateElapsedTime(start) < i)
    {
        DirectedInput(var)
        UpdateStatTimers()
    }
    return
}

DoDashWait()
{
    start := A_TickCount
    ReleaseStuckKeys()
    DirectedInput("g")
    LevelChampByID(47, 120, 5000, "q", 6)
    LevelChampByID(58, 80, 5000, "q", 5)
    gTime := ReadTimeScaleMultiplier(1)  ; TODO: name better
    if (gTime < 1)
        gTime := 1
    DashSpeed := gTime * 1.4
    modDashSleep := gDashSleepTime / gTime
    if (modDashSleep < 1)
    modDashSleep := gDashSleepTime
    GuiControl, MyWindow:, NewDashSleepID, % modDashSleep
    if (gStackFailConvRecovery)
        CheckForFailedConv()

    UpdateStatusEdit("Dash Wait") ;GuiControl, MyWindow:, gloopID, Dash Wait 
    While (ReadTimeScaleMultiplier(1) < DashSpeed AND UpdateElapsedTime(start) < modDashSleep)
    {
        StuffToSpam(0, 1, 0)
        ReleaseStuckKeys()
        UpdateStatTimers()
    }
    if (ReadQuestRemaining(1))
        FinishZone()  ; TODO: needs zoneNum?
    if (gbSpamUlts)
        DoUlts()

    DirectedInput("g")
    SetFormation(1) ; This assumes that DoDashWait is called from zone 1.... might not be right
    return
}

DoUlts()
{
    start := A_TickCount
    iUltSpamDur := 2000
    UpdateStatusEdit("Spamming Ultimates for " . iUltSpamDur . " milli seconds") 
    while (UpdateElapsedTime(start) < iUltSpamDur)
    {
        ReleaseStuckKeys()
        DirectedInput("23456789")
        UpdateStatTimers()
    }
    DirectedInput("8") ; use whatever number is Hav's ult
}

DirectedInput(s) 
{
    ReleaseStuckKeys()
    SafetyCheck()    
    ControlFocus,, ahk_exe IdleDragons.exe
    ; if (A_TimeIdleKeyboard > 3000)  could enable this to help with typing while script is running
    ControlSend,, {Blind}%s%, ahk_exe IdleDragons.exe
    Sleep, 25  ; Sleep for 25 sec formerly ScriptSpeed global, not used elsewhere.
}

SetFormation(zoneNum)
{
    ; if configured to avoidbosses, and we are at a boss zone (zone div 5 remainder is 0)
    if (gAvoidBosses and !Mod(zoneNum, 5))
    {
        DirectedInput("e") ; 
    }
    else if (gbCancelAnim AND !ReadQuestRemaining(1) AND ReadTransitioning(1))
    {
        DirectedInput("e") ; set to formation e to cancel the animation
        start   := A_TickCount ; store the tick count now, ie the start          
        UpdateStatusEdit("Read Transitioning") ;GuiControl, MyWindow:, gloopID, ReadTransitioning
        while (UpdateElapsedTime(start) < 5000 AND !ReadQuestRemaining(1))
        {
            DirectedInput("{Right}")
            UpdateStatTimers()
        }

        start := A_TickCount ; store the tick count now, ie the start
        tms := ReadTimeScaleMultiplier(1)
        swapSleepMod := gSwapSleep / tms
        UpdateStatusEdit("Still Read Transitioning") ;GuiControl, MyWindow:, gloopID, Still ReadTransitioning
        while (UpdateElapsedTime(start) < swapSleepMod AND ReadTransitioning(1))
        {
            DirectedInput("{Right}")
            UpdateStatTimers()
        }
        DirectedInput("q")
    }
    else
        DirectedInput("q")
}

LoadingZoneREV()
{
    start := A_TickCount
    UpdateStatusEdit("Loading Zone (REV)") ;GuiControl, MyWindow:, gloopID, Loading Zone
    ;ReadMonstersSpawned was added in case monsters were spawned before game allowed inputs, an 
    ;issue when spawn speed is very high. Might be creating more problems.  Offline Progress 
    ;appears to read monsters spawning, so this entire function can be bypassed creating 
    ;issues with stack restart.
    ;while (ReadChampBenchedByID(1,, 47) != 1 AND ElapsedTime < 60000 AND ReadMonstersSpawned(1) < 2)
    ;shouldn't be an issue if monsters spawn, shandie is supposed to be on bench. 
    ;Zone will kill monsters no problem. Higher zones she should be leveled.
    while (ReadChampBenchedByID(1,, 47) != 1 AND UpdateElapsedTime(start) < 60000)
    {
        DirectedInput("w{F6}w")
        UpdateStatTimers()
    }
    if (UpdateElapsedTime(start) > 60000)
    {
        CheckifStuck(gprevLevel)
    }
    start := A_TickCount
    UpdateStatusEdit("Confirming Zone Load (REV)") 
    ;need a longer sleep since offline progress should read shandie benched.
    while (ReadChampBenchedByID(1,, 47) != 0 AND UpdateElapsedTime(start) < 60000)
    {
        DirectedInput("q{F6}")
        UpdateStatTimers()
    }
}

LoadingZoneOne() ; TODO: we do the same thing twice in this function and more times elsewhere.  factor out the common logic
{
    ;look for Briv not benched when spamming 'q' formation.
    start := A_TickCount
    UpdateStatusEdit("Loading Zone (One)") ;GuiControl, MyWindow:, gloopID, Loading Zone
    while (ReadChampBenchedByID(1,, 58) != 0 AND UpdateElapsedTime(start) < 60000)
    {
        DirectedInput("q{F5}q")
        UpdateStatTimers()
    }
    if (UpdateElapsedTime(start) > 60000)
        CheckifStuck(gprevLevel)

    ;look for Briv benched when spamming 'e' formation.
    start := A_TickCount
    UpdateStatusEdit("Confirming Zone Load (One)") ;GuiControl, MyWindow:, gloopID, Confirming Zone Load
    while (ReadChampBenchedByID(1,, 58) != 0 AND UpdateElapsedTime(start) < 60000)
    {
        DirectedInput("e{F5}e")
        UpdateStatTimers()
    }
    if (UpdateElapsedTime(start) > 60000)
    {
        CheckifStuck(gprevLevel)
    }
}

CheckSetUpREV()  ; TODO: get rid of this, do Core area check somewhere other than the start of the run?
{
    ; TODO: this CheckSetUpREV() is strange thing to do right at the start of GemFarm(), once?
    ;find core target reset area so script does not try and Briv stack before a modron reset happens.
    ;gCoreTargetArea := ReadCoreTargetArea(1)
    ;confirm target area has been read
    if (!gModronResetCheckEnabled)
    {
        gCoreTargetArea := 999
    }
    Else
    {
        While (!gCoreTargetArea)
        {
            MsgBox, 2,, Script cannot find Modron Reset Area.
            IfMsgBox, Abort
            {
                Return, 1
            }
            IfMsgBox, Retry
            {
                ;gCoreTargetArea := ReadCoreTargetArea(1)
            }
            IfMsgBox, ignore
            {
                gCoreTargetArea := 999
            }
        }
    }
    ;will need to add more here eventually ; TODO: what is this?
    if (gCoreTargetArea < gAreaLow)
    {
        gCoreTargetArea := 999
    }   
    return, 0
}

; // UpdateElapsedTime ////////////////////////////////////////////////////////////////////////////
; // UpdateElapsedTime() - helper function
UpdateElapsedTime(start)
{
    elapsed := A_TickCount - start
    GuiControl, MyWindow:, ElapsedTimeID, % elapsed
    return elapsed
}

;thanks meviin for coming up with this solution
GetNumStacksFarmed()
{
    ; Read the number of stacks from memory
    gStackCountSB := ReadSBStacks(1)
    ; We've been having issues related to stacks, so we'll read it again every quarter second
    ; until it matches what we read the first time around.  NOTE: Potential to endless loop 
    ; here, please provide feedback to Zee(ValorZee) in Discord if using this code
    while (ReadSBStacks(1) != gStackCountSB)
    {
        Sleep 250
    }
    gStackCountH := ReadHasteStacks(1) ; TODO: may need to experiment with this read too
    if (gRestartStackTime) 
    {
        return gStackCountH + gStackCountSB
    } 
    else 
    {
        ; If restart stacking is disabled, we'll stack to basically the exact
        ; threshold.  That means that doing a single jump would cause you to
        ; lose stacks to fall below the threshold, which would mean StackNormal
        ; would happen after every jump.
        ; Thus, we use a static 47 instead of using the actual haste stacks
        ; with the assumption that we'll be at minimum stacks after a reset.
        return gStackCountSB + 47
    }
}

StackRestart()
{
    UpdateStatusEdit("Transitioning to Stack Restart") ;GuiControl, MyWindow:, gloopID, Transitioning to Stack Restart
    while (ReadTransitioning(1))
    {
        DirectedInput("w")
        UpdateStatTimers()
    }
    start := A_TickCount
    UpdateStatusEdit("Confirming ""w"" Loaded") ;GuiControl, MyWindow:, gloopID, Confirming "w" Loaded
    ;added due to issues with Loading Zone function, see notes therein
    while (ReadChampBenchedByID(1,, 47) != 1 AND UpdateElapsedTime(start) < 15000)
    {
        DirectedInput("w")
        UpdateStatTimers()
    }
    Sleep 1000
    CloseIC()
    start := A_TickCount
    UpdateStatusEdit("Stack Slee - ") ;GuiControl, MyWindow:, gloopID, Stack `Sleep
    if (gDoChests)
        DoChests()
    while (UpdateElapsedTime(start) < gRestartStackTime)
    {
        Sleep 100
        UpdateStatTimers()
    }
    UpdateStatusEdit("Finish Stack Sleep for " . ElapsedTime/1000 . " seconds")
    SafetyCheck()
    ; Game may save "q" formation before restarting, creating an endless restart loop. LoadinZone() should 
    ; bring "w" back before triggering a second restart, but monsters could spawn before it does.
    ; this doesn't appear to help the issue above.
    DirectedInput("w")
}

StackNormal()
{
    start := A_TickCount
    UpdateStatusEdit("Stack Normal")
    while (GetNumStacksFarmed() < gSBTargetStacks AND UpdateElapsedTime(start) < gSBTimeMax)
    {
        ReleaseStuckKeys()
        directedinput("w")
        if (ReadCurrentZone(1) <= gAreaLow) 
            DirectedInput("{Right}")
        Sleep 1000
        UpdateStatTimers()
        if (ReadResetting(1) OR ReadCurrentZone(1) = 1)
            Return
    }
}

StackFarm()
{
    start := A_TickCount
    UpdateStatusEdit("Transitioning to Stack Farm")
    while (ReadChampBenchedByID(1,, 47) != 1 AND UpdateElapsedTime(start) < 5000)
    {
        DirectedInput("w")
        UpdateStatTimers()
    }
    DirectedInput("g")
    
    while (!mod(ReadCurrentZone(1), 5)) ;send input Left while on a boss zone
    {
        ReleaseStuckKeys()
        DirectedInput("{Left}")
    }
    if gRestartStackTime
        StackRestart()
    if (GetNumStacksFarmed() < gSBTargetStacks)
        StackNormal()
    gPrevLevelTime := A_TickCount
    DirectedInput("g")
}

UpdateStartLoopStats(zoneNum)
{
    ReleaseStuckKeys()
    if (gTotal_RunCount = 0)
    {
        gStartTime     := A_TickCount
        gCoreXPStart   := ReadCoreXP(1)
        gGemStart      := ReadGems(1)
        gGemSpentStart := ReadGemsSpent(1)
        gRedGemsStart  := ReadRedGems(1)
    }
    if (gTotal_RunCount)
    {
        gPrevRunTime := round((A_TickCount - gRunStartTime) / 60000, 2)
        GuiControl, MyWindow:, gPrevRunTimeID, % gPrevRunTime
        if (gSlowRunTime < gPrevRunTime AND !gStackFail)
        {
            gSlowRunTime := gPrevRunTime
            GuiControl, MyWindow:, gSlowRunTimeID, % gSlowRunTime
        }
        if (gFastRunTime > gPrevRunTime AND !gStackFail)
        {
            gFastRunTime := gPrevRunTime
            GuiControl, MyWindow:, gFastRunTimeID, % gFastRunTime
        }
        if (gStackFail)
        {
            gFailRunTime := gPrevRunTime
            GuiControl, MyWindow:, gFailRunTimeID, % gFailRunTime
            if (gStackFail = 1)
            {
                ++gFailedStacking
                GuiControl, MyWindow:, gFailedStackingID, % gFailedStacking
            }
            else if (gStackFail = 2)
            {
                ++gFailedStackConv
                GuiControl, MyWindow:, gFailedStackConvID, % gFailedStackConv
            }
        }
        dtTotalTime := (A_TickCount - gStartTime) / 3600000
        gAvgRunTime := Round((dtTotalTime / gTotal_RunCount) * 60, 2)
        GuiControl, MyWindow:, gAvgRunTimeID, % gAvgRunTime
        dtTotalTime := (A_TickCount - gStartTime) / 3600000
        TotalBosses := (ReadCoreXP(1) - gCoreXPStart) / 5
        gbossesPhr := Round(TotalBosses / dtTotalTime, 2)
        GuiControl, MyWindow:, gbossesPhrID, % gbossesPhr
        GuiControl, MyWindow:, gTotal_RunCountID, % gTotal_RunCount
        GemsTotal := (ReadGems(1) - gGemStart) + (ReadGemsSpent(1) - gGemSpentStart)
        GuiControl, MyWindow:, GemsTotalID, % GemsTotal
        GemsPhr := Round(GemsTotal / dtTotalTime, 2)
        GuiControl, MyWindow:, GemsPhrID, % GemsPhr
        RedGemsTotal := (ReadRedGems(1) - gRedGemsStart)
        if (RedGemsTotal)
        {
            GuiControl, MyWindow:, RedGemsTotalID, % RedGemsTotal
            RedGemsPhr := Round(RedGemsTotal / dtTotalTime, 2)
            GuiControl, MyWindow:, RedGemsPhrID, % RedGemsPhr
        }
        Else
        {
            GuiControl, MyWindow:, RedGemsTotalID, 0
            GuiControl, MyWindow:, RedGemsPhrID, Pathetic
        }    
    }
    gRunStartTime := A_TickCount
    SetLastZone(zoneNum)

}

; SetLastZone - helper function to store the value in the global storage (TODO: factor out) and update the GUI
SetLastZone(znum)
{
    gPrevLevel := znum
    GuiControl, MyWindow:, gPrevLevelID, % gPrevLevel
}

UpdateStatTimers()
{
    ReleaseStuckKeys()
    dtCurrentRunTime := Round((A_TickCount - gRunStartTime) / 60000, 2)
    GuiControl, MyWindow:, dtCurrentRunTimeID, % dtCurrentRunTime
    dtTotalTime := Round((A_TickCount - gStartTime) / 3600000, 2)
    GuiControl, MyWindow:, dtTotalTimeID, % dtTotalTime
    GetZoneTime() 
}

GetZoneTime()
{
    g_ZoneTime := Round((A_TickCount - gPrevLevelTime) / 1000, 2)
    GuiControl, MyWindow:, ZoneTimeID, % g_ZoneTime
    return g_ZoneTime
}

UpdateStatusEdit(msg)
{
    GuiControl, MyWindow:, gLoopID, %msg%  ; %A_Hour%:%A_Min%:%A_Sec%.%A_MSec%
    FormatTime, CurrentTime, , yyyyMMdd HH:mm:ss
    TSmsg := CurrentTime . " " . msg . "`r`n"
    Edit_Prepend(hZLoop, TSmsg)  
    LogMsg(msg)    
}

; // VerifyChamp //////////////////////////////////////////////////////////////////////////////////
; // VerifyChamp() - helper function to eliminate code duplication
VerifyChamp(strGUI, strInit, champID, benched)  ; benched 1, 0 not benched
{
    start := A_TickCount  ; The tick count NOW is the start time
    UpdateStatusEdit(strGUI) 
    DirectedInput(strInit)  ; this should  set the stage for the champ check, ie right formation etc
    while (ReadChampBenchedByID(1,, champID) = benched AND (UpdateElapsedTime(start) < 5000))
    {
        DirectedInput(strInit) ; we are doing it again        
        UpdateStatTimers() ; TODO: why are we doing this here? this function has nothing to do with it?
    }
    ; One final check for our champ:
    if (ReadChampBenchedByID(1,, champID) = benched)
    {
        LogMsg("WARN: " . strGUI . " [" . benched . "] was Unsuccessful", true)
        ; TODO: create checkboxes for User Settings for HARD FAIL - this is anti newer user friendly
        ;MsgBox, Couldn't find Shandie in "Q" formation. Check saved formations. Ending Gem Farm.
        ;Return, 1
    } 
    return 0    
}

SimpleInput(s)
{
    ControlFocus,, ahk_exe IdleDragons.exe
    ; if (A_TimeIdleKeyboard > 3000)  could enable this to help with typing while script is running
    ControlSend,, {Blind}%s%, ahk_exe IdleDragons.exe
    Sleep, 25  ; Sleep for 25 sec formerly ScriptSpeed global, not used elsewhere.
}

SimpleLoop()
{
    SimpleInput("g")
    loopctr := 0
    loop    ; MainLoop
    {
        ++loopctr
        UpdateStatusEdit("Simple Loop (" . loopctr . ") started")
        ;gLevel_Number := ReadCurrentZone(1)     

        fakezonenum := loopctr < 10 ? 1 : 2
        var := "{Right}"
        if (gb100xCDLev)
            var := var "{Ctrl down}``{Ctrl up}"
        else if (gbCDLeveling)
            var := var "``"
        if (SLCD > zoneNum)
            ;var := var g_FKeys
            var := var BuildLevelKeys(1) ;LJ gFKeys
        if (gHewUlt AND hew)
            var := var gHewUlt
        ;if (formation) ; TODO: relying on empty string being false, not a good idea, refactor
        ;    var := var formation
        ;MsgBox %var%
        SimpleInput(var)
    
        ;UpdateStartLoopStats(fakezonenum)
        
        ReleaseStuckKeys()

        dtCurrentRunTime := Round((A_TickCount - gRunStartTime) / 60000, 2)
        GuiControl, MyWindow:, dtCurrentRunTimeID, % dtCurrentRunTime
        dtTotalTime := Round((A_TickCount - gStartTime) / 3600000, 2)
        GuiControl, MyWindow:, dtTotalTimeID, % dtTotalTime

        if (gbSpamUlts) 
        {
            SimpleInput("g") ; TODO: why is this part of spamming ults?
            var :=
            if (gb100xCDLev)
                var := var "{Ctrl down}``{Ctrl up}"
            else if (gbCDLeveling)
                var := var "``"
            if (gStopLevZone > zoneNum)
                ;var := var g_FKeys
                var := BuildLevelKeys(zoneNum) ;LJ gFKeys
            if (gHewUlt AND hew)
                var := var gHewUlt
            SimpleInput(var)

            start := A_TickCount
            iUltSpamDur := 500
            UpdateStatusEdit("Spamming Ultimates for " . iUltSpamDur . " milli seconds") ;GuiControl, MyWindow:, gloopID, Spamming Ults for 2s
            while (UpdateElapsedTime(start) < iUltSpamDur)
            {
                ReleaseStuckKeys()
                SimpleInput("1234567890")
            }
            SimpleInput("g") ; TODO: why is this part of spamming ults?
        }    
    }
}

GemFarm() 
{  
    ReleaseStuckKeys() ; Strange, why here? it happens once per script execution
    OpenProcess()      ; OpenProcess makes sense as a thing that happens at the start of execution
    ModuleBaseAddress()
    ;not sure why this one is here, commented out for now.
    ;GetUserDetails()
    strNow := "  " . A_Hour . ":" . A_Min . ":" . A_Sec . ":" . A_MSec
    GuiControl, %GUIwindow%, ReadUserIDID , % ReadUserID()
    GuiControl, %GUIwindow%, ReadUserHashID, % ReadUserHash()  . strNow    
    VerifyChamp("Looking for PRESENCE of Shandie in Q", "q{F6}q", 47, 1)
    VerifyChamp("Looking for PRESENCE of Briv in Q", "q{F5}q", 58, 1)
    VerifyChamp("Looking for ABSENCE of Shandie in W", "w", 47, 0)

    if (UpdateAdvID() < 1)
    {
        MsgBox, AdventureID is 0, something is not right. Click OK to go to simple loop mode
        SimpleLoop()
        ;MsgBox, Please load into a valid adventure and restart. Ending Gem Farm.        
        ;return
    }
    gPrevLevelTime := A_TickCount  ; TODO: why store now as the previous level time?

    loopctr := 0
    loop    ; MainLoop
    {
        ++loopctr
        UpdateStatusEdit("Main Loop (" . loopctr . ") started") 

        gLevel_Number := ReadCurrentZone(1)
        DirectedInput("``")
        SetFormation(gLevel_Number)

        ;WinActivate Idle Champions
        WinGet, active_id, ProcessPath, A
        ;WinMaximize, ahk_id %active_id%
        ;MsgBox, The active window's ID is "%active_id%".

        if (gLevel_Number = 1)
        {
            LogMsg("Loop " . loopctr . " Entered z1 check", true)
            if (false) ;gDashSleepTime) ; TODO: we spam Ults in both other branches, why not here? if we need to wait for Dash, migth as well eh?
            {
                LogMsg("Loop " . loopctr . " gDashSleepTime is true", true)
                ;putting this check with the gLevel_Number = 1 appeared to completely disable DashWait
                if (ReadQuestRemaining(1))
                {
                    LogMsg("Loop " . loopctr . " ReadQuestRemaining(1) is true, calling DoDashWait", true)
                    DoDashWait()
                    LogMsg("Loop " . loopctr . " DoDashWait returned", true)
                }
            }
            Else if (gStackFailConvRecovery)
            {
                CheckForFailedConv()
                SpamUlts(true)
                SetFormation(1)  ; TODO: why do this here?
            }
            Else 
                SpamUlts(false)
        }

        GemFarmStacking(gLevel_Number)


        if (!Mod(gLevel_Number, 5) AND Mod(ReadHighestZone(1), 5) AND !ReadTransitioning(1))
        {
            DirectedInput("g")
            DirectedInput("g")
        }
         
        StuffToSpam(1, gLevel_Number)

        if (ReadResetting(1))
        {
            ModronReset()
            LoadingZoneOne() 
            UpdateStartLoopStats(gLevel_Number)
            if (!gStackFail)
                ++gTotal_RunCount
            gStackFail := 0
            gPrevLevelTime := A_TickCount
            gprevLevel := ReadCurrentZone(1)
        }

        CheckifStuck(gLevel_Number)
        UpdateStatTimers()
    }
}

; // SpamUlts /////////////////////////////////////////////////////////////////////////////////////
; // SpamUlts - helper function to reduce code duplication,
SpamUlts(finish) ; TODO: this function does more than Spam Ults, rename for better self documentation
{
    if (gbSpamUlts) 
    {
        DirectedInput("g") ; TODO: why is this part of spamming ults?
        FinishZone()       ; TODO: odd thing to combine with spamming ults functionality
        DoUlts()
        DirectedInput("g") ; TODO: why is this part of spamming ults?
    }    
    else if (finish)
        FinishZone()
}
;-GemFarmStacking------------------------------------------------------------------------------------
; GemFarmStacking encapsulates the logic for farming Briv stacks (to enable his power)
GemFarmStacking(zoneNum)
{
    ;stacks := GetNumStacksFarmed()

    ;if (stacks < gSBTargetStacks AND gLevel_Number > gAreaLow AND gLevel_Number < gCoreTargetArea)
    if (zoneNum > gAreaLow AND zoneNum < gCoreTargetArea AND GetNumStacksFarmed() < gSBTargetStacks)
    {
        StackFarm()
    }

    if (gStackCountH < 50 AND zoneNum > gMinStackZone AND gbSFRecover AND zoneNum < gAreaLow)
    {
        if (gStackCountSB < gSBTargetStacks)
        {
            StackFarm()
        }
        stacks := GetNumStacksFarmed()
        if (stacks > gSBTargetStacks AND !gTestReset)
        {
            EndAdventure(2000)
            UpdateStartLoopStats(zoneNum)
            gStackFail := 1
            gPrevLevelTime := A_TickCount
            gprevLevel := ReadCurrentZone(1)
        }
    }
}
; // RestartGame //////////////////////////////////////////////////////////////////////////////////
; RestartGame contains the code needed to close IdleChampions, and restart in the same adventure
RestartGame(condouter, condinner:=false)  ; outer condition makes inline calling simpler.  inner condition is for the special case use
{
    if (condouter)
    {
        MsgBox, Fuuuuk!
        CloseIC()
        if (GetUserDetails() = -1)   
        {      
            LoadAdventure()     
        }
        if (condinner)                 
        {
            SafetyCheck()
        }
    }
}

; // CheckifStuck /////////////////////////////////////////////////////////////////////////////////
CheckifStuck(zoneNum)
{
    if (zoneNum != gprevLevel) ; TODO: should probably check for >
    {
        SetLastZone(zoneNum) ; TODO: why is CheckifStuck updating the GUI? work outside scope of functionality
        gPrevLevelTime := A_TickCount ; TODO: we seem to reset this all over the place, source of unnecessary state complexity
    }

    if (!ReadQuestRemaining(1) AND !ReadTransitioning(1)) ; We've been here 30 seconds, we're not transitioning, and there are no quests remaining.  Auto-advance got stuck off.
    {
        DirectedInput("g")
    }

    RestartGame(GetZoneTime() > 60, true)
    gPrevLevelTime := A_TickCount
    ;RestartGame(ReadChampLvlByID(1, "MyWindow:", 58) < 100, true)
}

; // ModronReset //////////////////////////////////////////////////////////////////////////////////
ModronReset()
{
    StartTime := A_TickCount
    ElapsedTime := 0
    UpdateStatusEdit("Modron Reset") ;GuiControl, MyWindow:, gloopID, Modron Reset
    while (ReadResetting(1) AND ElapsedTime < 180000)
    {
        Sleep, 250
        ElapsedTime := UpdateElapsedTime(StartTime)
        UpdateStatTimers()
        if (ReadCurrentZone(1) = 1)
        Break
    }
    ;RestartGame(ElapsedTime > 180000)
    StartTime := A_TickCount
    ElapsedTime := 0
    UpdateStatusEdit("Resetting to Zone 1") ;GuiControl, MyWindow:, gloopID, Resettting to z1
    while (ReadCurrentZone(1) != 1 AND ElapsedTime < 180000)
    {
        Sleep, 250
        ElapsedTime := UpdateElapsedTime(StartTime)
        UpdateStatTimers()
    }
    RestartGame(ElapsedTime > 180000)
}

EndAdventure(restartdelay_ms = 1)   ; delay in milliseconds before readString()
{ 
    DirectedInput("r")
    xClick := (ReadScreenWidth(1) / 2) - 80
    yClickMax := ReadScreenHeight(1)
    yClick := yClickMax / 2
    StartTime := A_TickCount
    ElapsedTime := 0
    UpdateStatusEdit("Manually Ending Adventure") ;GuiControl, MyWindow:, gloopID, Manually Ending Adventure
    while(!ReadResetting(1) AND ElapsedTime < 30000)
    {
        WinActivate, ahk_exe IdleDragons.exe
        MouseClick, Left, xClick, yClick, 1
        if (yClick < yClickMax)
        yClick := yClick + 10
        Else
        yClick := yClickMax / 2
        Sleep, 25
        ElapsedTime := UpdateElapsedTime(StartTime)
        UpdateStatTimers()
    }
    sleep restartdelay_ms
    RestartGame(true, true)  ; do both the restart and the safety check
}

; Source from LJ
BuildLevelKeys(currentLevel) ;LJ ReadChampLvlBySlot(UpdateGUI := 0, GUIwindow := "MyWindow:", slot := 0)
{
;	tTip :=
	levstring :=

	if (currentLevel < 2) ;LJ Attempt to summon all champs z1 .. id = null if not summoned == wont summon champs below this loop 
	{
		loop, 12
		{
            ;MsgBox,,, % g_levToggles[A_Index]
			if (g_levToggles[A_Index] == 1)
			    levstring = %levstring%{F%A_Index%}
		}
	    return levstring
	}

	loop, 10 
	{
		id := ReadChampIDbySlot(,,A_Index - 1)
		if (StrLen(id) = 0) ;LJ ID was not Found skip
			continue
		level := ReadChampLvlByID(1,, id)
		seat  := ReadChampSeatBySlot(,,A_Index - 1)
;		ttip = %tTip%%id% %seat% %level%`r`n ;LJ Debugging tooltip
		if (g_levToggles[A_Index] == 1) ;(S%seat%Toggle)
		{
            stoplev := g_StopAt[seat]
			if (stoplev == 0 or stoplev >= level)
				levstring = %levstring%{F%seat%}
		}
	}
;	Tooltip, %tTip%, 400, 35 ;LJ Expert debugging tool    
    GuiControl, MyWindow:, FkeysID, % levstring ; update the GUI
	return levstring
}

StuffToSpam(SendRight := 1, zoneNum := 1, hew := 1, formation := "")
{
    ReleaseStuckKeys()
    var :=
    if (SendRight)
        var := "{Right}"
    if (gb100xCDLev)
        var := var "{Ctrl down}``{Ctrl up}"
    else if (gbCDLeveling)
        var := var "``"
    if (!gStopLevZone || gStopLevZone > zoneNum)
        ;var := var g_FKeys
        var := BuildLevelKeys(zoneNum) ;LJ gFKeys
    if (gHewUlt AND hew)
        var := var gHewUlt
    if (formation) ; TODO: relying on empty string being false, not a good idea, refactor
       var := var formation

    DirectedInput(var)
    Return
}

;functions not actually for server calls
DoChests()
{
    GuiControl, MyWindow:, gloopID, Getting User Details to Do Chests
    GetUserDetails()
    if gSCFirstRun
    {
        gSCRedRubiesSpentStart := gRedRubiesSpent
        GuiControl, MyWindow:, gSCRedRubiesSpentStartID, %gSCRedRubiesSpentStart%
        gSCSilversOpenedStart := gSilversOpened
        GuiControl, MyWindow:, gSCSilversOpenedStartID, %gSCSilversOpenedStart%
        gSCGoldsOpenedStart := gGoldsOpened
        GuiControl, MyWindow:, gSCGoldsOpenedStartID, %gSCGoldsOpenedStart%
        gSCFirstRun := 0
    }
    if (gSCSilverCount < gSilversHoarded AND gSCSilverCount)
    {
        GuiControl, MyWindow:, gloopID, Opening %gSCSilverCount% Silver Chests
        OpenChests(1, gSCSilverCount)
    }
    else if (gSCGoldCount < gGoldsHoarded AND gSCGoldCount)
    {
        GuiControl, MyWindow:, gloopID, Opening %gSCGoldCount% Gold Chests
        OpenChests(2, gSCGoldCount)
    }
    else if (gSCBuySilvers)
    {
        i := gSCBuySilvers * 50
        j := i + gSCMinGemCount
        if (gRedRubies > j)
        {
            GuiControl, MyWindow:, gloopID, Buying %gSCBuySilvers% Silver Chests
            BuyChests(1, gSCBuySilvers)
        }
    }
    else if (gSCBuyGolds)
    {
        i := gSCBuyGolds * 500
        j := i + gSCMinGemCount
        if (gRedRubies > j)
        {
            GuiControl, MyWindow:, gloopID, Buying %gSCBuyGolds% Gold Chests
            BuyChests(2, gSCBuyGolds)
        }
    }
    var := gRedRubiesSpent - gSCRedRubiesSpentStart
    GuiControl, MyWindow:, GemsSpentID, %var%
    var := gSilversOpened - gSCSilversOpenedStart
    GuiControl, MyWindow:, gSCSilversOpenedID, %var%
    var := gGoldsOpened - gSCGoldsOpenedStart
    GuiControl, MyWindow:, gSCGoldsOpenedID, %var%
    Return
}
