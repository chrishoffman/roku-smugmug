' *********************************************************
' *********************************************************
' **
' **  Roku DVP SmugMug Channel (BrightScript)
' **
' **  C. Hoffman, December 2009
' **
' **  Copyright (c) 2009 Chris Hoffman. All Rights Reserved.
' **
' *********************************************************
' *********************************************************

Sub BrowseSettings()
    screen=uitkPreShowPosterMenu("","Settings")
    
    highlights=m.highlights
    settingmenu = [
        {ShortDescriptionLine1:"Edit Following", ShortDescriptionLine2:"Follow other SmugMug users", HDPosterUrl:highlights[9], SDPosterUrl:highlights[9]},
        {ShortDescriptionLine1:"Slideshow Duration", ShortDescriptionLine2:"Change slideshow duration", HDPosterUrl:highlights[8], SDPosterUrl:highlights[8]},
        {ShortDescriptionLine1:"Deactivate Player", ShortDescriptionLine2:"Remove link from SmugMug account", HDPosterUrl:highlights[7], SDPosterUrl:highlights[7]},
        {ShortDescriptionLine1:"About", ShortDescriptionLine2:"About the channel", HDPosterUrl:highlights[6], SDPosterUrl:highlights[6]},
    ]
    onselect = [0, m, "EditFollowing","SlideshowSpeed","DelinkPlayer","About"]
    
    uitkDoPosterMenu(settingmenu, screen, onselect)
End Sub

Sub SlideshowSpeed()
    ssdur=RegRead("SlideshowDuration","Settings")
    if ssdur=invalid then
        durtext="not set (default 3 seconds)"
    else
        durtext=ssdur+" seconds"
    end if
    
    port = CreateObject("roMessagePort")
    dialog = CreateObject("roMessageDialog")
    dialog.SetMessagePort(port)
    
    dialog.SetTitle("Change Slideshow Duration")
    dialog.SetText("Current setting: "+durtext)
    dialog.AddButton(3, "3 seconds")
    dialog.AddButton(5, "5 seconds")
    dialog.AddButton(10, "10 seconds")
    dialog.Show()

    while true
        dlgMsg = wait(0, dialog.GetMessagePort())
        
        if type(dlgMsg) = "roMessageDialogEvent"
            if dlgMsg.isScreenClosed()
                print "Screen closed"
                return
            else if dlgMsg.isButtonPressed()
                RegWrite("SlideshowDuration",Str(dlgMsg.GetIndex()),"Settings")
                m.SlideshowDuration=dlgMsg.GetIndex()
                return
            end if
        end if
    end while
End Sub

Sub DelinkPlayer()
    ans=ShowDialog2Buttons("Deactivate Player","Remove link to you SmugMug account?","Confirm","Cancel")
    if ans=0 then 
        RegDelete("oauth_token","Authentication")
        RegDelete("oauth_secret","Authentication")
        m.isLinked=false
        m.oauth_token=invalid
        m.oauth_secret=invalid
        m.nickname=invalid
        m.displayname=invalid
    end if
End Sub

Sub About()
    ShowDialog1Button("About","The SmugMug Channel was developed by Chris Hoffman, a huge Roku and SmugMug fan.  The channel is not supported by SmugMug but if you have any questions, issues, or suggestions, feel free to e-mail Chris at rokusmugmug@gmail.com.","Back")
End Sub

Sub EditFollowing()
    screen=uitkPreShowPosterMenu("","Edit Following")
    
    while true
        settingmenu=[{ShortDescriptionLine1:"Follow New Person", ShortDescriptionLine2:"Follow someone's SmugMug photos", HDPosterUrl:"pkg:/images/smuggy.png", SDPosterUrl:"pkg:/images/smuggy.png"}]
        
        followlist=GetFollowList()
        if followlist.Count()>0 then
            settingmenu.Append(m.getFFMetaData(followlist,"nickname","DisplayName"))
        end if
        
        selected=uitkDoPosterMenu(settingmenu, screen)
        if selected=-1 exit while
        
        contentlist=screen.GetContentList()
        selected_name=contentlist[selected].Lookup("ShortDescriptionLine1")
        if selected_name="Follow New Person" then
            m.FollowNew()
        else
            ans=ShowDialog2Buttons("Removed user","Remove user "+selected_name+" from following?","Confirm","Cancel")
            if ans=0 then 
                RegDelete(selected_name,"Follow")
                if selected>contentlist.Count()-2 then screen.SetFocusedListItem(contentlist.Count()-2)
            end if
        end if
    end while
End Sub

Function GetFollowList()
    following=RegSectionKeys("Follow")
    
    followlist=[]
    for each follow in following
        followReg=strTokenize(RegRead(follow,"Follow"),"|")
        'For backwards compatibility, derive URL
        if followReg[1]=invalid then followReg[1]="http://"+follow+".smugmug.com"
        
        ff={nickname: follow, DisplayName: followReg[0], URL: followReg[1]}
        followlist.Push(ff)
    end for
    
    Sort(followlist,function(ff):return ff.Lookup("DisplayName"):end function)
    
    return followlist
End Function


Sub FollowNew()
    kinput=getKeyboardInput("Follow New Person","Enter the nickname of the user you would like to follow.")
    if kinput=invalid return
    
    rsp=m.ExecServerAPI("smugmug.users.getInfo",["NickName="+kinput])
    if not isxmlelement(rsp) then return
    
    RegWrite(kinput,rsp.user@displayname+"|"+rsp.user@url,"Follow")
End Sub