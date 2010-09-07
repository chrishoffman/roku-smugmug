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
Sub RunUserInterface()
    SetTheme()
    
	' Pop up start of UI for some instant feedback while we load the icon data
	screen=uitkPreShowPosterMenu()
	if screen=invalid then
		print "unexpected error in uitkPreShowPosterMenu"
		return
	end if
	
	smugmug=CreateSmugmugConnection()
	if smugmug=invalid then
		print "unexpected error in CreateSmugmugConnection"
		return
	end if
    
    while true
        highlights=[]
        for each h in smugmug.highlights:highlights.Push(h):next
        
        if smugmug.isLinked then
            new_highlights=smugmug.getRandomRssHighlights("http://www.smugmug.com/hack/feed.mg?Type=nicknameRecentPhotos&Data="+smugmug.nickname+"&format=atom10", 1, false)
            if new_highlights.Count()>0 then highlights[2]=new_highlights[0]
        end if
        
        mainmenudata = [
            {ShortDescriptionLine1:"Browse SmugMug", ShortDescriptionLine2:"Browse Photos from SmugMug", HDPosterUrl:highlights[0], SDPosterUrl:highlights[0]},
            {ShortDescriptionLine1:"My SmugMug", ShortDescriptionLine2:"Browse my SmugMug account", HDPosterUrl:highlights[2], SDPosterUrl:highlights[2]},
        ]
        onselect = [0, smugmug, "BrowseSmugMug", "BrowseMySmugMug"]
        
        followlist=GetFollowList()
        mainmenudata.Append(smugmug.getFFMetaData(followlist))
        for each follow in followlist
            onselect.Push(["DisplayFriendsFamily",follow])
        end for
        
        mainmenudata.Push({ShortDescriptionLine1:"Settings", ShortDescriptionLine2:"Edit channel settings", HDPosterUrl:highlights[3], SDPosterUrl:highlights[3]})
        onselect.Push("return")
        
        selected=uitkDoPosterMenu(mainmenudata, screen, onselect)
        
        if selected=-1 then
            exit while
        else
            selected_name=screen.GetContentList()[selected].Lookup("ShortDescriptionLine1")
            
            if selected_name="Settings" then
                smugmug.BrowseSettings()
                screen.SetFocusedListItem(0)
            end if
        end if
    end while
End Sub

' ******************************************************
' Setup theme for the application 
' ******************************************************
Sub SetTheme()
    app = CreateObject("roAppManager")
    theme = CreateObject("roAssociativeArray")
    
    theme.OverhangOffsetSD_X = "72"
    theme.OverhangOffsetSD_Y = "34"
    theme.OverhangLogoSD  = "pkg:/images/Logo_Overhang_Smugmug_SD.png"
    theme.OverhangSliceSD = "pkg:/images/Home_Overhang_BackgroundSlice_SD43.png"
    
    theme.OverhangOffsetHD_X = "123"
    theme.OverhangOffsetHD_Y = "48"
    theme.OverhangLogoHD  = "pkg:/images/Logo_Overhang_Smugmug_HD.png"
    theme.OverhangSliceHD = "pkg:/images/Home_Overhang_BackgroundSlice_HD.png"
    
    app.SetTheme(theme)
End Sub