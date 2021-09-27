; /////////////////////////////////////////////////////////////////////////////////////////////////
; //   >>>> USER WARNING:  Do NOT edit the header, it makes helping you in Discord HARDER! <<<<
; // Updates installed after the date below may result in the pointer addresses not being valid.
; // Epic Games IC Version:  v0.403
; /////////////////////////////////////////////////////////////////////////////////////////////////
global SC_ScriptDate    := "2021/09/26"   ; USER: Cut and paste these in Discord when asking for help
global SC_ScriptVersion := "2021.09.26.1" ; USER: Cut and paste these in Discord when asking for help
; /////////////////////////////////////////////////////////////////////////////////////////////////
; // Future Considerations / Areas of Interest
; // -use a class
; // -
; /////////////////////////////////////////////////////////////////////////////////////////////////
; // Changes
; // 20210918 1 - modified file header
; //            - moved DoChests() to main file
; // 20210924 1 - Initial fork update
; // 20210926 1 - decoupled advtoload, indentation fixes, added chest input validator helper
; /////////////////////////////////////////////////////////////////////////////////////////////////


;globals used to track chest opening and purchases
global gSCGemsSpent := 0
global gSCSilversOpened := 0
global gSCSilversOpenedStart :=
global gSCGoldsOpened := 0
global gSCGoldsOpenedStart :=
global gSCFirstRun := 1
global gSCRedRubiesSpentStart :=

;global variables used for server calls
global DummyData := "&language_id=1&timestamp=0&request_id=0&network_id=11&mobile_client_version=999"
global ActiveInstance :=
global InstanceID :=
global UserID :=
global UserHash := ""
;global advtoload :=
global gSilversHoarded := ;variable to store amount of chests hoarded
global gSilversOpened := ;variable to store amount of chests opened
global gGoldsHoarded := ;variable to store amount of chests hoarded
global gGoldsOpened := ;variable to store amount of chests opened
;global gEventSilversHoarded := ;variable to store amount of chests hoarded
;global gEventGoldsHoarded := ;variable to store amount of chests hoarded
global gRedRubies := ;variable to store amount of gems server thinks you have
global gRedRubiesSpent := ;variable to store amount of gems server thinks you have spent

ServerCall(callname, parameters) 
{
    URLtoCall := "http://ps6.idlechampions.com/~idledragons/post.php?call=" callname parameters
    ;GuiControl, MyWindow:, advparamsID, % URLtoCall
    WR := ComObjCreate("WinHttp.WinHttpRequest.5.1")
    WR.SetTimeouts("10000", "10000", "10000", "10000")
    Try {
        WR.Open("POST", URLtoCall, false)
        WR.SetRequestHeader("Content-Type","application/x-www-form-urlencoded")
        WR.Send()
        WR.WaitForResponse(-1)
        data := WR.ResponseText
    }
    return data
}

GetUserDetails() 
{
    getuserparams := DummyData "&include_free_play_objectives=true&instance_key=1&user_id=" UserID "&hash=" UserHash
    rawdetails := ServerCall("getuserdetails", getuserparams)
    Try
    {
        UserDetails := JSON.parse(rawdetails)
    }
    Catch
    {
        Return
    }
    InstanceID := UserDetails.details.instance_id
    GuiControl, MyWindow:, InstanceIDID, % InstanceID
    ActiveInstance := UserDetails.details.active_game_instance_id
    GuiControl, MyWindow:, ActiveInstanceID, % ActiveInstance
    for k, v in UserDetails.details.game_instances
    {
        if (v.game_instance_id == ActiveInstance) 
        {
            CurrentAdventure := v.current_adventure_id
            GuiControl, MyWindow:, CurrentAdventureID, % CurrentAdventure
        }
    }
    gSilversHoarded := UserDetails.details.chests.1
    gSilversOpened := UserDetails.details.stats.chests_opened_type_1
    gGoldsHoarded := UserDetails.details.chests.2
    gGoldsOpened := UserDetails.details.stats.chests_opened_type_2
    gRedRubies := UserDetails.details.red_rubies
    gRedRubiesSpent := UserDetails.details.red_rubies_spent
    rawdetails :=
    UserDetails := 
    return CurrentAdventure
}

LoadAdventure(advID := 0, p := 0, pt := 0)   ;p - patron, pt - patron tier
{
    if (advID == 0) 
    {
        MsgBox,,, % "Can't load adventure with ID == " . advID
    }
    advparams := DummyData "&patron_tier=" p "&user_id=" UserID "&hash=" UserHash "&instance_id=" InstanceID "&game_instance_id=" ActiveInstance "&adventure_id=" advID "&patron_id=" pt
    ServerCall("setcurrentobjective", advparams)
    return
}

; // Helper function to reduce code duplication
ValidateChestInput(Byref chests)
{
    if (chests < 1)
        return false
    if (chests > 99)
        chests := 99
    return true
}

BuyChests(chestID, chests)
{
    if (ValidateChestInput(chests))
    {
        chestparams := DummyData "&user_id=" UserID "&hash=" UserHash "&instance_id=" InstanceID "&chest_type_id=" chestid "&count=" chests
        ServerCall("buysoftcurrencychest", chestparams)
    }
    return
}

OpenChests(chestID, chests)
{
    if (ValidateChestInput(chests))
    {
        chestparams := "&gold_per_second=0&checksum=4c5f019b6fc6eefa4d47d21cfaf1bc68&user_id=" UserID "&hash=" UserHash "&instance_id=" InstanceID "&chest_type_id=" chestid "&game_instance_id=" ActiveInstance "&count=" chests
        ServerCall("opengenericchest", chestparams)
    }
    return
}