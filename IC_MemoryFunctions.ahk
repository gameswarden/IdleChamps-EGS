; /////////////////////////////////////////////////////////////////////////////////////////////////
; //   >>>> USER WARNING:  Do NOT edit the header, it makes helping you in Discord HARDER! <<<<
; // Updates installed after the date below may result in the pointer addresses not being valid.
; // Epic Games IC Version:  v0.408
; /////////////////////////////////////////////////////////////////////////////////////////////////
global MF_ScriptDate    := "2021/10/20"   ; USER: Cut and paste these in Discord when asking for help
global MF_ScriptVersion := "2021.10.20.1" ; USER: Cut and paste these in Discord when asking for help
; /////////////////////////////////////////////////////////////////////////////////////////////////
; // This file contains remory read functionality for Idle Champions scripting.  It also logs all
; // memory reads (currently partially rolled out) into a text file each day, to help with tracking
; // down issues.  Please bring your log file when in need of help in the CNE Discord #scripting chan
; // Dependent on classMemory.ahk structure to read actual memory of actual running IC executable
; /////////////////////////////////////////////////////////////////////////////////////////////////
; // Future Considerations / Areas of Interest
; // -implement a profiling/timing system to evaluate/optimize performance
; // -investigate ReadRaw
; // -investigate Read direct with one address (as opposed to offsets)
; // -solve reads with slot/dynamic offset type reads in an OO fashion
; // -consider a solution to help widdle down pointer candidate pool (see below)
; // -
; /////////////////////////////////////////////////////////////////////////////////////////////////
; // Changes
; // 20210916 C - modified file header
; //            - added logging
; // 20210917 1 - changed versioning scheme to aling with grand plan
; //            - updated ReadMonsterSpawned to use 0x230 instead of 0x228 - issues with Jimothy
; //            - added code for reading different pointer offset sets we have to narrow down the magic pointer
; //            - expanded logging and also optimizing ReadMem encapsulation
; // 20210918 2 - more ReadMem rollouts
; // 20210924 1 - Initial fork update
; // 20211013 1 - Updated ReadCoreExp found/tested by Fenume, 3rd offset from 0x38 to 0x40
; // 20211020 1 - Fenume's tentative fix for Hero structures change introduced by v.408
; /////////////////////////////////////////////////////////////////////////////////////////////////

; This class relies on classMemory.ahk
; wrapper with memory reading functions sourced from: https://github.com/Kalamity/classMemory
#include classMemory.ahk

; This code verifies taht the classmemory class is configured/accessible correctly
if (_ClassMemory.__Class != "_ClassMemory")
{
	msgbox "classMemory not correctly installed. " 
         . "(Or global class variable ""_ClassMemory"" has been overwritten"
	ExitApp
}

; // This is the instance of the ClassMemory class--never name your class with 'Class' folks--
global hProc :=  ; storage for Windows API type handle to the IC executable process 
global idle := new _ClassMemory("ahk_exe IdleDragons.exe", "", hProc) ; hProc is set by the ctor

; // Game Controller Structure
global ptrGCbase :=         ; pointer to the base address of the Game Controller
; // NOTE:   Pointer offsets to the GameController in the running IC executable, as found in CE.
; // The way this works is that we, the dev community find a pool of pointer candidates through
; // painstaking trial and error and collaboration (If you are interest in helping, contact us in
; // DISCORD -- does not require programming expertise).  CNE and their Unity engine + Mono library
; // do some questionable stuff that leads to a lot of pointers that may be viable.  Over time,
; // we 'widdle' down this list to what we hope turn out to be the Magic Pointers that are the
; // right ones!  The user community help is greatly appreciated, we are all in this together.
; // Modifying these values should NOT BE DONE BY USERS, it will break memory read functionality
global ptrAGCoffsets := [0xC88, 0xD8, 0xB0, 0x10, 0x20, 0x18] ;[0x210, 0xE8, 0x30, 0x40, 0x18] ; pointer offsets array
;global ptrAGCoffstT1 := [0xC88, 0xD8, 0x10, 0x18, 0x360, 0x18] ; proved to be bad on a adventure reset
;global ptrAGCoffstT2 := [0xC88, 0xD8, 0xB8, 0x10, 0x20, 0x18]
;global ptrAGCoffstT3 := [0xC88, 0xD8, 0xB0, 0x10, 0x20, 0x18]
; /////////////////////////////////////////////////////////////////////////////////////////////////

; // LOGGING CODE - TODO: Move to its own file ////////////////////////////////////////////////////
global fMFLog := "ZMemFunclog.txt"
LogFMsg(msg)
{
    FormatTime, CurrentTime, , yyyyMMdd HH:mm:ss
    TSmsg := CurrentTime . "." . A_MSec . " " . msg . "`r`n"
    FormatTime, today, , yyyyMMdd
    nFn := today " " fMFLog
    FileAppend, %TSmsg%, %nFn%
}

; // PTRArray2String //////////////////////////////////////////////////////////////////////////////
; // PTRArray2String - takes an array, and cycles throu, stringifying the individual hex values
PTRArray2String(Byref ptrArray)
{
    i := 1                  ; AHK indexes are 1 based
    ct := ptrArray.Count()  ; how many do we need to read/format/add to string?
    str := "0x"             ; 0x means the following is hexadecimal, eg 0xFF, 0x99
    while (i <= ct)        
    {
        str .= Format("{:X}", ptrArray[i]) ; format to capital lettered HEX, ad to str
        ++i                                ; increment the counter else endless loop
    }
    return str
}
; // END LOGGING CODE /////////////////////////////////////////////////////////////////////////////

; // OpenProcess //////////////////////////////////////////////////////////////////////////////////
; // Open a process with sufficient access to read and write memory addresses (this is required 
; // before you can use the other functions). You only need to do this once. But if the process 
; // closes/restarts, then you will need to perform this step again. See the notes section below.
; //
; // Also, if the target process is running as admin, the script will also require admin rights!
; // 
; // Note: The program identifier can be any AHK windowTitle i.e.ahk_exe, ahk_class, ahk_pid, or 
; // simply the window title.
; // hProcessCopy is an optional variable in which the opened handled is stored.
; // TODO: use isHandleValid() on the stored handle to determine whether it is valid :TODO
OpenProcess()
{
    LogFMsg("VERSION INFO: IC_Memoryfunctions.ahk (" . MF_ScriptVersion . ")" )
    idle := new _ClassMemory("ahk_exe IdleDragons.exe", "", hProcessCopy)
    LogFMsg("In OpenProcess()       hProcesscopy = " . hProcessCopy)
}

; // ModuleBaseAddress ///////////////////////////////////////////////////////////////////////////
ModuleBaseAddress()
{
    ;ptrGCbase := idle.getModuleBaseAddress("mono-2.0-bdwgc.dll")+0x00493DE8 ; Old CantRow's
    ;ptrGCbase := idle.getModuleBaseAddress("mono-2.0-bdwgc.dll")+0x004A3418
    ptrGCbase := idle.getModuleBaseAddress("mono-2.0-bdwgc.dll")+0x00491A90
    LogFMsg("In ModuleBaseAddress() ptrGCbase = 0x" . Format("{:X}", ptrGCbase))
    ; These are test reads and can be removed if desired
    ;ReadHighestZone(1)
    ;ReadGems(1)
    ;ReadGemsSpent(1)
    ;ReadRedGems(1)
    ;ReadQuestRemaining(1)
}

; // ReadMem //////////////////////////////////////////////////////////////////////////////////////
ReadMem(Byref last := 0, msg := "You didn't provide it!", Byref ptrArray := 0
       , GUIupdate := 0, GUIwindow := "MyWindow:", valType := "Int")
{
    ; MsgBox,, ReadMem, testword %GUIitemiD%
    if (ptrArray == 0)  ; basic error checking
        MsgBox "DEV ERROR: Can't call ReadMem with a 0 array!"

    addr  := idle.getAddressFromOffsets(ptrGCbase, ptrAGCoffsets*) ; TODO: may not need to do this all the time?
    var   := idle.read(addr, valType, ptrArray*)  ; TODO: Investigate/test can have addr resolved with offsets too
    ;addr2 := idle.getAddressFromOffsets(ptrGCbase, ptrAGCoffstT2*)
    ;var2  := idle.read(addr2, valType, ptrArray*)
    strOffsets := PTRArray2String(ptrArray)
    LogFMsg(msg . " 0x" . Format("{:X}+", addr ) . strOffsets . ": " . var . "(" . last . ")")

    if (var == Null)  
    {   ; log a few more read attempts
        Loop, 25
        {
            var  := idle.read(addr,  valType, ptrArray*)
            LogFMsg(msg . " Test location   : " . var)
            sleep 200        
        }
    }

    if GUIupdate
    {
        GUIitemiD := msg . "ID"
        FormatTime, DayTime, , ddd HH:mm:ss
        PreciseTime := DayTime . "." . A_MSec
        GuiControl, %GUIwindow%, %GUIitemiD%, %PreciseTime% `t %var%
    }

    last := var  ; store it in the last variable for next loop
    return var   ; return the current variable read
}

; // ReadCurrentZone //////////////////////////////////////////////////////////////////////////////
global offsetCurZ := [0x30, 0x28, 0x4C] ; These are the offsets to get "Current zone variable"
global lastCurZ   := 0 ; We'll store last read value here so that logfile shows transition
ReadCurrentZone(UpdateGUI := 0, GUIwindow := "MyWindow:")
{    
    ;MsgBox,,ReadCurrentZone, testword%ReadCurrentZoneID%morecrap
    return ReadMem(lastCurZ, "ReadCurrentZone", offsetCurZ, UpdateGUI, GUIwindow) ;, "ReadCurrentZoneID")
}

; // ReadHighestZone //////////////////////////////////////////////////////////////////////////////
global offsetTopZ := [0x30, 0x90] ; These are the offsets to get "Highest zone variable"
global lastTopZ   := 0 ; We'll store last read value here so that logfile shows transition
ReadHighestZone(UpdateGUI := 0, GUIwindow := "MyWindow:")
{ 
    return ReadMem(lastTopZ, "ReadHighestZone", offsetTopZ, UpdateGUI, GUIwindow) ;, ReadHighestZoneID)
}

; // ReadGems /////////////////////////////////////////////////////////////////////////////////////
global offsetGems := [0xA0, 0x224] ; These are the offsets to get "Gems"
global lastGems   := 0 ; We'll store last read value here so that logfile shows transition
ReadGems(UpdateGUI := 0, GUIwindow := "MyWindow:")
{
    return ReadMem(lastGems, "ReadGems", offsetGems, UpdateGUI, GUIwindow) ;, ReadGemsID)
}

; // ReadGemsSpent ////////////////////////////////////////////////////////////////////////////////
global offsetGemSP := [0xA0, 0x228] ; These are the offsets to get "Gems"
global lastGemSP   := 0 ; We'll store last read value here so that logfile shows transition
ReadGemsSpent(UpdateGUI := 0, GUIwindow := "MyWindow:")
{
    return ReadMem(lastGemSP, "ReadGemsSpent", offsetGemSP, UpdateGUI, GUIwindow) 
}

; // ReadRedGems //////////////////////////////////////////////////////////////////////////////////
global offsetRGem := [0xA0, 0x30, 0x290] ; These are the offsets to get "RedGems"
global lastRGem   := 0 ; We'll store last read value here so that logfile shows transition
ReadRedGems(UpdateGUI := 0, GUIwindow := "MyWindow:")
{
    return ReadMem(lastRGem, "ReadRedGems", offsetRGem, UpdateGUI, GUIwindow) 
}

; // ReadQuestRemaining ///////////////////////////////////////////////////////////////////////////
global offsetQR := [0x30, 0x28, 0x54] ; These are the offsets to get "Quest Remaining"
global lastQR   := 0 ; We'll store last read value here so that logfile shows transition
ReadQuestRemaining(UpdateGUI := 0, GUIwindow := "MyWindow:")
{
    return ReadMem(lastQR, "ReadQuestRemaining", offsetQR, UpdateGUI, GUIwindow) 
}

; // ReadTimeScaleMultiplier //////////////////////////////////////////////////////////////////////
ReadTimeScaleMultiplier(UpdateGUI := 0, GUIwindow := "MyWindow:")
{
    Controller := idle.getAddressFromOffsets(ptrGCbase, ptrAGCoffsets*)
    pointerArray := [0x10, 0x168]
    var := Round(idle.read(Controller, "Float", pointerArray*), 3)
    if UpdateGUI
    GuiControl, %GUIwindow%, ReadTimeScaleMultiplierID, %var% %A_Hour%:%A_Min%:%A_Sec%.%A_MSec%
    return var
}

global offsetTR := [0x40, 0x38] ; These are the offsets to get "ReadTransitioning"
global lastTR   := 0 ; We'll store last read value here so that logfile shows transition
ReadTransitioning(UpdateGUI := 0, GUIwindow := "MyWindow:")
{
    return ReadMem(lastTR, "ReadTransitioning", offsetTR, UpdateGUI, GUIwindow, "Char") 
}

; // ReadSBStacks /////////////////////////////////////////////////////////////////////////////////
ReadSBStacks(UpdateGUI := 0, GUIwindow := "MyWindow:")
{
    Controller := idle.getAddressFromOffsets(ptrGCbase, ptrAGCoffsets*)
    pointerArray := [0xA0, 0x30, 0x2F0]
    var := idle.read(Controller, "Int", pointerArray*)
    if UpdateGUI
    {
        GuiControl, %GUIwindow%, ReadSBStacksID, %var% %A_Hour%:%A_Min%:%A_Sec%.%A_MSec%
        GuiControl, %GUIwindow%, gStackCountSBID, %var%
    }
    return var
}

;global offsetSB := [0xA0, 0x30, 0x2F0] ; These are the offsets to get "ReadTransitioning"
;global lastSB   := 0 ; We'll store last read value here so that logfile shows transition
;ReadSBStacks(UpdateGUI := 0, GUIwindow := "MyWindow:")
;{
;    return ReadMem(lastSB, "ReadSBStacks", offsetSB, UpdateGUI, GUIwindow) 
;}

; // ReadHasteStacks //////////////////////////////////////////////////////////////////////////////
ReadHasteStacks(UpdateGUI := 0, GUIwindow := "MyWindow:")
{
    Controller := idle.getAddressFromOffsets(ptrGCbase, ptrAGCoffsets*)
    pointerArray := [0xA0, 0x30, 0x2F4]
    var := idle.read(Controller, "Int", pointerArray*)
    if UpdateGUI
    {
        GuiControl, %GUIwindow%, ReadHasteStacksID, %var% %A_Hour%:%A_Min%:%A_Sec%.%A_MSec%
        GuiControl, %GUIwindow%, gStackCountHID, %var%
    }
    return var
}

; // ReadCoreXP ///////////////////////////////////////////////////////////////////////////////////
global offsetCXP := [0x10, 0x80, 0x40, 0x50] ; These are the offsets to get "ReadCoreXP"
global lastCXP   := 0 ; We'll store last read value here so that logfile shows transition
ReadCoreXP(UpdateGUI := 0, GUIwindow := "MyWindow:")
{
    return ReadMem(lastCXP, "ReadCoreXP", offsetCXP, UpdateGUI, GUIwindow) 
}

; // OBSOLETED ///////////
; // ReadCoreTargetArea ///////////////////////////////////////////////////////////////////////////
;global offsetTgtA := [0x10, 0x80, 0x38, 0x54] ; These are the offsets to get "ReadCoreTargetArea"
;global lastTgtA   := 0 ; We'll store last read value here so that logfile shows transition
;ReadCoreTargetArea(UpdateGUI := 0, GUIwindow := "MyWindow:")
;{
;    return ReadMem(lastTgtA, "ReadCoreTargetArea", offsetTgtA, UpdateGUI, GUIwindow) 
;}

; // ReadResetting ////////////////////////////////////////////////////////////////////////////////
global offsetReset := [0x10, 0x38, 0x38] ; These are the offsets to get "ReadResettting"
global lastReset   := 0 ; We'll store last read value here so that logfile shows transition
ReadResettting(UpdateGUI := 0, GUIwindow := "MyWindow:")
{
    return ReadMem(lastReset, "ReadResettting", offsetReset, UpdateGUI, GUIwindow, "Char") 
}

; // ReadUserID ///////////////////////////////////////////////////////////////////////////////////
global offsetUID := [0x20, 0xA8, 0x58] ; These are the offsets to get "ReadUserID"
global lastUID   := 0 ; We'll store last read value here so that logfile shows transition
ReadUserID(UpdateGUI := 0, GUIwindow := "MyWindow:")
{                                                  ; TODO: remove GUI dependency
    return ReadMem(lastUID, "ReadUserID", offsetUID, UpdateGUI, GUIwindow)  
}

; // ReadUserHash /////////////////////////////////////////////////////////////////////////////////
ReadUserHash(UpdateGUI := 0, GUIwindow := "MyWindow:")
{
    Controller := idle.getAddressFromOffsets(ptrGCbase, ptrAGCoffsets*)
    pointerArray := [0x20, 0xA8, 0x20, 0x14]
    var := idle.readstring(Controller, bytes := 64, encoding := "UTF-16", pointerArray*)
                                                      ; TODO: remove GUI dependency
    if UpdateGUI
        GuiControl, %GUIwindow%, ReadUserHashID, %var% %A_Hour%:%A_Min%:%A_Sec%.%A_MSec%
    return var
}

; // ReadScreenWidth //////////////////////////////////////////////////////////////////////////////
global offsetScrW := [0x10, 0x10, 0x2F4] ; These are the offsets to get "ReadScreenWidth"
global lastScrW   := 0 ; We'll store last read value here so that logfile shows transition
ReadScreenWidth(UpdateGUI := 0, GUIwindow := "MyWindow:")
{
    return ReadMem(lastScrW, "ReadUsReadScreenWidtherID", offsetScrW, UpdateGUI, GUIwindow) 
}

; // ReadScreenHeight /////////////////////////////////////////////////////////////////////////////
global offsetScrH := [0x10, 0x10, 0x2F8] ; These are the offsets to get "ReadScreenHeight"
global lastScrH   := 0 ; We'll store last read value here so that logfile shows transition
ReadScreenHeight(UpdateGUI := 0, GUIwindow := "MyWindow:")
{
    return ReadMem(lastScrH, "ReadScreenHeight", offsetScrH, UpdateGUI, GUIwindow) 
}

ReadChampLvlBySlot(UpdateGUI := 0, GUIwindow := "MyWindow:", slot := 0)
{
    Controller := idle.getAddressFromOffsets(ptrGCbase, ptrAGCoffsets*)
    pointerArray := [0x28, 0x18, 0x10]
    var := 0x20 + (slot * 0x8)
    pointerArray.Push(var, 0x28, 0x318) ; 310 -v408 ; 30C -v397?
    var := idle.read(Controller, "Int", pointerArray*)
    if UpdateGUI
    GuiControl, %GUIwindow%, ReadChampLvlBySlotID, Slot: %slot% Lvl: %var% %A_Hour%:%A_Min%:%A_Sec%.%A_MSec%
    return var
}

ReadChampSeatBySlot(UpdateGUI := 0, GUIwindow := "MyWindow:", slot := 0)
{
    Controller := idle.getAddressFromOffsets(ptrGCbase, ptrAGCoffsets*)
    pointerArray := [0x28, 0x18, 0x10]
    var := 0x20 + (slot * 0x8)
    pointerArray.Push(var, 0x28, 0x18, 0x130) ; 128 -v397? ; TODO may need to go to 138 for v.408
    var := idle.read(Controller, "Int", pointerArray*)
    if UpdateGUI
    GuiControl, %GUIwindow%, ReadChampSeatBySlotID, Slot: %slot% Seat: %var% %A_Hour%:%A_Min%:%A_Sec%.%A_MSec%
    return var
}

ReadChampIDbySlot(UpdateGUI := 0, GUIwindow := "MyWindow:", slot := 0)
{
    Controller := idle.getAddressFromOffsets(ptrGCbase, ptrAGCoffsets*)
    pointerArray := [0x28, 0x18, 0x10]
    var := 0x20 + (slot * 0x8)
    pointerArray.Push(var, 0x28, 0x18, 0x10)
    var := idle.read(Controller, "Int", pointerArray*)
    if UpdateGUI
    GuiControl, %GUIwindow%, ReadChampIDbySlotID, Slot: %slot% `ID: %var% %A_Hour%:%A_Min%:%A_Sec%.%A_MSec%
    return var
}

;maybe doesnt work?
ReadChampLvlByID(UpdateGUI := 0, GUIwindow := "MyWindow:", ChampID := 0)
{
    Controller := idle.getAddressFromOffsets(ptrGCbase, ptrAGCoffsets*)
    pointerArray := [0xA0, 0x10, 0x18, 0x10]
    --ChampID
    var := 0x20 + (ChampID * 0x8)
    pointerArray.Push(var, 0x318) ; 310 -v408  ; 30C - v397?
    var := idle.read(Controller, "Int", pointerArray*)
    if UpdateGUI
    ++ChampID
    GuiControl, %GUIwindow%, ReadChampLvlByIDID, `ID: %ChampID% Lvl: %var% %A_Hour%:%A_Min%:%A_Sec%.%A_MSec%
    return var
}

ReadChampSeatByID(UpdateGUI := 0, GUIwindow := "MyWindow:", ChampID := 0)
{
    Controller := idle.getAddressFromOffsets(ptrGCbase, ptrAGCoffsets*)
    pointerArray := [0xA0, 0x10, 0x18, 0x10]
    --ChampID
    var := 0x20 + (ChampID * 0x8)
    pointerArray.Push(var, 0x18, 0x130) ; 128-v397? ; TODO may need to go to 138 for v.408
    var := idle.read(Controller, "Int", pointerArray*)
    if UpdateGUI
    ++ChampID
    GuiControl, %GUIwindow%, ReadChampSeatByIDID, `ID: %ChampID% Seat: %var% %A_Hour%:%A_Min%:%A_Sec%.%A_MSec%
    return var
}

ReadChampSlotByID(UpdateGUI := 0, GUIwindow := "MyWindow:", ChampID := 0)
{
    Controller := idle.getAddressFromOffsets(ptrGCbase, ptrAGCoffsets*)
    pointerArray := [0xA0, 0x10, 0x18, 0x10]
    --ChampID
    var := 0x20 + (ChampID * 0x08)
    pointerArray.Push(var, 0x2F0) ; 2E8 -v408 ; 2e4 -v397?
    var := idle.read(Controller, "Int", pointerArray*)
    if UpdateGUI
    ++ChampID
    GuiControl, %GUIwindow%, ReadChampSlotByIDID, `ID: %ChampID% Slot: %var% %A_Hour%:%A_Min%:%A_Sec%.%A_MSec%
    return var
}

ReadChampBenchedByID(UpdateGUI := 0, GUIwindow := "MyWindow:", ChampID := 0)
{
    Controller := idle.getAddressFromOffsets(ptrGCbase, ptrAGCoffsets*)
    pointerArray := [0xA0, 0x10, 0x18, 0x10]
    --ChampID
    var := 0x20 + (ChampID * 0x8)
    pointerArray.Push(var, 0x2FC) ; 2F4 -v408 ; 2F0 -v397?
    var := idle.read(Controller, "Char", pointerArray*)
    if UpdateGUI
    ++ChampID
    GuiControl, %GUIwindow%, ReadChampBenchedByIDID, `ID: %ChampID% Benched: %var% %A_Hour%:%A_Min%:%A_Sec%.%A_MSec%
    return var
}

; // ReadMonstersSpawned //////////////////////////////////////////////////////////////////////////
global offsetMSpwn := [0x18, 0x230]  ; These are the offsets to get "ReadMonstersSpawned"
global lastMSpwn  := 0 ; We'll store last read value here so that logfile shows transition
ReadMonstersSpawned(UpdateGUI := 0, GUIwindow := "MyWindow:")
{
    return ReadMem(lastMSpwn, "ReadMonstersSpawned", offsetMSpwn, UpdateGUI, GUIwindow) 
}

; // ReadCurrentObjID /////////////////////////////////////////////////////////////////////////////
global offsetCurObj := [0x30, 0x18, 0x10]  ; These are the offsets to get "ReadCurrentObjID"
global lastCurObj   := 0 ; We'll store last read value here so that logfile shows transition
ReadCurrentObjID(UpdateGUI := 0, GUIwindow := "MyWindow:")
{
    return ReadMem(lastCurObj, "ReadCurrentObjID", offsetCurObj, UpdateGUI, GUIwindow) 
}

ReadClickFamiliarBySlot(UpdateGUI := 0, GUIwindow := "MyWindow:", slot := 0)
{
    Controller := idle.getAddressFromOffsets(ptrGCbase, ptrAGCoffsets*)
    pointerArray := [0x70, 0x328, 0x10]
    var := 0x20 + (slot * 0x8)
    pointerArray.Push(var, 0x2E8, 0x1D8)
    var := idle.read(Controller, "Char", pointerArray*)
    if UpdateGUI
    GuiControl, %GUIwindow%, ReadClickFamiliarBySlotID, slot: %Slot% objectActive: %var% %A_Hour%:%A_Min%:%A_Sec%.%A_MSec%
    return var
}

ReadHeroAliveBySlot(UpdateGUI := 0, GUIwindow := "MyWindow:", slot := 0)
{
    Controller := idle.getAddressFromOffsets(ptrGCbase, ptrAGCoffsets*)
    pointerArray := [0x28, 0x18, 0x10]
    var := 0x20 + (slot * 0x8)
    pointerArray.Push(var, 0x251) ; 239 -v408
    var := idle.read(Controller, "Char", pointerArray*)
    if UpdateGUI
    GuiControl, %GUIwindow%, ReadHeroAliveBySlotID, slot: %Slot% heroAlive: %var% %A_Hour%:%A_Min%:%A_Sec%.%A_MSec%
    return var
}