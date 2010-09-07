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

' ********************************************************************
' ********************************************************************
' ***** Registration
' ***** Registration
' ********************************************************************
' ********************************************************************
Function doRegistration() As Integer
    
    regscreen = m.displayRegistrationScreen()

    'main loop get a new registration code, display it and check to see if its been linked
    while true
        'Reset token values for request token signature
        m.oauth_token=RegRead("oauth_token", "Authentication")
        m.oauth_token_secret=""
        
        duration = 0
        
        rsp=m.ExecServerAPI("smugmug.auth.getRequestToken")
        m.oauth_token=rsp.auth.token@id
        m.oauth_token_secret=rsp.auth.token@secret
        
        sn = CreateObject("roDeviceInfo").GetDeviceUniqueId() 
        regCode = m.getRegistrationCode(sn)
        
        'if we've failed to get the registration code, bail out, otherwise we'll
        'get rid of the retreiving... text and replace it with the real code       
        if regCode = "" then return 2
        regscreen.SetRegistrationCode(regCode)
        print "Enter registration code " + regCode + " at " + m.regUrlWebSite + " for " + sn
        
        'make an http request to see if the device has been registered on the backend
        while true
        
            status = m.checkRegistrationStatus(sn, regCode)
            if status < 3 return status
            
            getNewCode = false
            retryInterval = m.retryInterval
            retryDuration = m.retryDuration
            print "retry duration "; itostr(duration); " at ";  itostr(retryInterval);
            print " sec intervals for "; itostr(retryDuration); " secs max"
          
            'wait for the retry interval to expire or the user to press a button
            'indicating they either want to quit or fetch a new registration code
            while true
                print "Wait for " + itostr(retryInterval)
                msg = wait(retryInterval * 1000, regscreen.GetMessagePort())
                duration = duration + retryInterval
                if msg = invalid exit while
                
                if type(msg) = "roCodeRegistrationScreenEvent"
                    if msg.isScreenClosed()
                        print "Screen closed"
                        return 1
                    elseif msg.isButtonPressed()
                        print "Button pressed: "; msg.GetIndex(); " " msg.GetData()
                        if msg.GetIndex() = 0
                            regscreen.SetRegistrationCode("retrieving code...")
                            getNewCode = true
                            exit while
                        endif
                        if msg.GetIndex() = 1 return 1
                    endif
                endif
            end while
            
            if duration >= retryDuration then
                ans=ShowDialog2Buttons("Request timed out", "Unable to link to SmugMug within time limit.", "Try Again", "Back")
                if ans=0 then 
                    regscreen.SetRegistrationCode("retrieving code...")
                    getNewCode = true
                else
                    return 1
                end if
            end if
            
            if getNewCode exit while
            
            print "poll prelink again..."
        end while
    end while

End Function


'********************************************************************
'** display the registration screen in its initial state with the
'** text "retreiving..." shown.  We'll get the code and replace it
'** in the next step after we have something onscreen for teh user 
'********************************************************************
Function displayRegistrationScreen() As Object
    regsite   = "go to " + m.regUrlWebsite
    regscreen = CreateObject("roCodeRegistrationScreen")
    regscreen.SetMessagePort(CreateObject("roMessagePort"))
    
    regscreen.SetTitle("")
    regscreen.AddParagraph("Please link your Roku player to your SmugMug account")
    regscreen.AddFocalText(" ", "spacing-dense")
    regscreen.AddFocalText("From your computer,", "spacing-dense")
    regscreen.AddFocalText(regsite, "spacing-dense")
    regscreen.AddFocalText("and enter this code to activate:", "spacing-dense")
    regscreen.SetRegistrationCode("retrieving code...")
    regscreen.AddParagraph("This screen will automatically update as soon as your activation completes")
    regscreen.AddParagraph("You have 5 minutes to enter your activation code.")
    regscreen.AddButton(0, "Get a new code")
    regscreen.AddButton(1, "Back")
    regscreen.Show()
    
    return regscreen
End Function


'********************************************************************
'** Fetch the prelink code from the registration service. return
'** valid registration code on success or an empty string on failure
'********************************************************************
Function getRegistrationCode(sn As String) As String
    if sn = "" then return ""
    
    url=m.regUrlBase+m.regUrlGetRegCode+"?partner=roku&deviceTypeName=roku&deviceID="+sn+"&oauth_token="+m.oauth_token
    m.http.SetUrl(url)
    rsp=m.http.GetToString()
    
    xml=ParseXML(rsp)
    print "GOT: " + rsp
    print "Reason: " + m.http.GetFailureReason()
    
    if xml=invalid then
        print "Can't parse getRegistrationCode response"
        ShowConnectionFailed()
        return ""
    endif
    
    if xml.GetName() <> "result"
        Dbg("Bad register response: ",  xml.GetName())
        ShowConnectionFailed()
        return ""
    endif
    
    if islist(xml.GetBody()) = false then
        Dbg("No registration information available")
        ShowConnectionFailed()
        return ""
    endif

    'default values for retry logic
    retryInterval = 30  'seconds
    retryDuration = 900 'seconds (aka 15 minutes)
    regCode = ""

    'handle validation of response fields 
    for each e in xml.GetBody()
        if e.GetName() = "regCode" then
            regCode = e.GetBody()  'enter this code at website
        elseif e.GetName() = "retryInterval" then
            retryInterval = strtoi(e.GetBody())
        elseif e.GetName() = "retryDuration" then
            retryDuration = strtoi(e.GetBody())
        endif
    next
    
    if regCode = "" then
        Dbg("Parse yields empty registration code")
        ShowConnectionFailed()
    endif
    
    m.retryDuration = retryDuration
    m.retryInterval = retryInterval
    m.regCode = regCode
    
    return regCode
End Function


'******************************************************************
'** Check the status of the registration to see if we've linked
'** Returns:
'**     0 - We're registered. Proceed.
'**     1 - Reserved. Used by calling function.
'**     2 - We're not registered. There was an error, abort.
'**     3 - We're not registered. Keep trying.
'******************************************************************
Function checkRegistrationStatus(sn As String, regCode As String) As Integer
    url=m.regUrlBase+m.regUrlGetRegResult+"?partner=roku&deviceID="+sn+"&regCode="+regCode
    m.http.SetUrl(url)
    
    print "checking registration status"
    
    while true
        rsp = m.http.GetToString()
        print rsp
        xml=ParseXML(rsp)
        if xml=invalid then
            print "Can't parse check registration status response"
            ShowConnectionFailed()
            return 2
        endif
        
        if xml.GetName() <> "result" then
            print "unexpected check registration status response: ", xml.GetName()
            ShowConnectionFailed()
            return 2
        endif
        
        if islist(xml.GetBody()) = true then
            for each e in xml.GetBody()
                if e.GetName() = "status" then
                    status = e.GetBody()
                    
                    if status="complete" then
                        rsp=m.ExecServerAPI("smugmug.auth.getAccessToken")
                        if not rsp=invalid then
                            m.oauth_token=rsp.auth.token@id
                            m.oauth_token_secret=rsp.auth.token@secret
                            m.nickname=rsp.auth.user@nickname
                            m.displayname=rsp.auth.user@displayname
                            m.isLinked=true
                            
                            RegWrite("oauth_token", m.oauth_token, "Authentication")
                            RegWrite("oauth_token_secret",m.oauth_token_secret, "Authentication")
                            
                            showCongratulationsScreen()
                            return 0
                        else
                            ShowConnectionFailed()
                            return 2
                        end if
                    else if status="failure" then
                        ShowConnectionFailed()
                        return 2
                    else
                        return 3
                    endif
                endif
            next
        endif
    end while
End Function

'******************************************************
'Show congratulations screen
'******************************************************
Sub showCongratulationsScreen()
    port = CreateObject("roMessagePort")
    screen = CreateObject("roParagraphScreen")
    screen.SetMessagePort(port)
    
    screen.AddHeaderText("Congratulations!")
    screen.AddParagraph("You have successfully linked your Roku player to your SmugMug account")
    screen.AddParagraph("Select 'start' to begin.")
    screen.AddButton(1, "start")
    screen.Show()
    
    while true
        msg = wait(0, screen.GetMessagePort())
        
        if type(msg) = "roParagraphScreenEvent"
            if msg.isScreenClosed()
                print "Screen closed"
                exit while                
            else if msg.isButtonPressed()
                print "Button pressed: "; msg.GetIndex(); " " msg.GetData()
                exit while
            else
                print "Unknown event: "; msg.GetType(); " msg: "; msg.GetMessage()
                exit while
            endif
        endif
    end while
End Sub

