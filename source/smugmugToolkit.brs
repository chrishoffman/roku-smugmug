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
' ***** Object Constructor
' ***** Object Constructor
' ********************************************************************
' ********************************************************************
Function CreateSmugMugConnection() As Object
    smugmug = {
        http: CreateObject("roUrlTransfer"),
        
        'Http requests
        ExecServerAPI: ExecServerAPI,
        ExecRSSRequest: ExecRSSRequest,
        
        'My SmugMug
        BrowseMySmugMug: BrowseMySmugMug,
        
        'Albums
        BrowseAlbums: BrowseAlbums,
        DisplayAlbum: DisplayAlbum,
        newAlbumListFromXML: newAlbumListFromXML,
        newAlbumFromXML: newAlbumFromXML,
        getAlbumMetaData: getAlbumMetaData,
        
        'Images
        newImageListFromXML: newImageListFromXML,
        newImageFromXML: newImageFromXML,
        getImageURL: getImageURL,
        newImageListFromRSS: newImageListFromRSS,
        newImageFromRSS: newImageFromRSS,
        BrowseImages: BrowseImages,
        getRandomRssHighlights: GetRandomRssHighlights,
        
        'Categories
        BrowseCategories: BrowseCategories,
        newCategoryListFromXML: newCategoryListFromXML,
        newCategoryFromXML: newCategoryFromXML,
        
        'Special sections
        RandomPhotos: RandomPhotos,
        BrowseSmugMug: BrowseSmugmug,
        DisplayPopular: DisplayPopular,
        BrowseSmugMugCategories: BrowseSmugmugCategories,
        PhotoSearch: PhotoSearch,
        
        'Videos
        BrowseVideos: BrowseVideos,
        DisplayVideo: DisplayVideo,
        
        'Friends & Family
        BrowseFriendsFamily: BrowseFriendsFamily,
        DisplayFriendsFamily: DisplayFriendsFamily,
        getFFMetaData: getFFMetaData,
        
        'Settings
        BrowseSettings: BrowseSettings,
        EditFollowing: EditFollowing,
        SlideshowSpeed: SlideshowSpeed,
        FollowNew: FollowNew,
        DelinkPlayer: DelinkPlayer,
        About: About, 
        
        'Slideshow
        DisplaySlideShow: DisplaySlideShow,
        DisplayImageSet: DisplayImageSet,
        AddNextImageToSlideShow: AddNextImageToSlideShow,
        PrepDisplaySlideShow: PrepDisplaySlideShow,
        ProcessSlideShowEvent: ProcessSlideShowEvent,
        
        'Encryption
        digest: CreateObject("roEVPDigest"),
        md5: function(str):ba=CreateObject("roByteArray"):m.digest.Setup("md5"):ba.FromAsciiString(str):return m.digest.process(ba):end function,
        hmac: CreateObject("roHMAC"),
        sha1: function(str,key):sigkey=CreateObject("roByteArray"):sigkey.fromAsciiString(key):ba=CreateObject("roByteArray"):m.hmac.Setup("sha1",sigkey):ba.FromAsciiString(str):return m.hmac.process(ba).toBase64String():end function,
        
        'Oauth
        endpoint: "http://api.smugmug.com/services/api/rest/1.2.2/",
        api_key: "APIKEY",
        api_secret: "APISECRET",
        oauth_signature_method: "HMAC-SHA1",
        oauth_token: RegRead("oauth_token", "Authentication"),
        oauth_token_secret: RegRead("oauth_token_secret", "Authentication"),
        GenOauthSig: GenOauthSig,
        
        'Url
        urlencodeRFC3986: urlencodeRFC3986,
        urlencodeParams: urlencodeParams,
        PopularUrlBase: "http://www.smugmug.com/hack/feed.mg?Type=popular&format=atom10&Data=",
        RandomUrlBase: "http://www.smugmug.com/photos/random.mg?",
        RecentUrlBase: "http://www.smugmug.com/hack/feed.mg?Type=nicknameRecentPhotos&format=atom10&Data=",
        
        'Registration
        doRegistration: doRegistration,
        getRegistrationCode: getRegistrationCode,
        displayRegistrationScreen: displayRegistrationScreen,
        checkRegistrationStatus: checkRegistrationStatus,
        
        regUrlBase: "LINKING WEBSITE",
        regUrlGetRegCode: "/getRegCode",
        regUrlGetRegResult: "/getRegResult",
        regUrlWebSite: "LINKING WEBSITE",
    }
    
    rsp=smugmug.ExecServerAPI("smugmug.service.ping")
    if not isxmlelement(rsp) then
        return invalid
    end if
    
    'Check if account is linked
    smugmug.IsLinked=false
    if smugmug.oauth_token<>invalid then
        rsp=smugmug.ExecServerAPI("smugmug.auth.checkAccessToken")
        if isxmlelement(rsp) then
            smugmug.IsLinked=true
            smugmug.displayname=rsp.auth.user@displayname
            smugmug.nickname=rsp.auth.user@nickname
            smugmug.access=rsp.auth.token@access
        else
            'Remove entries if oauth is no longer valid
            RegDelete("oauth_token", "Authentication")
            RegDelete("oauth_token_secret", "Authentication")
        end if
    end if
    
    'Cache some random images from all time popular feed
    smugmug.highlights=smugmug.getRandomRssHighlights(smugmug.PopularUrlBase+"all",10)
    
    'Set Slideshow Duration
    ssdur=RegRead("SlideshowDuration","Settings")
    if ssdur=invalid then
        smugmug.SlideshowDuration=3
    else
        smugmug.SlideshowDuration=Val(ssdur)
    end if
    
    return smugmug
End Function

' ********************************************************************
' ********************************************************************
' ***** Http Requests
' ***** Http Requests
' ********************************************************************
' ********************************************************************
Function ExecServerAPI(method, param_list=[] As Object, nickname=invalid As Dynamic, raise_error=true As Boolean) As Dynamic
    exec_api_start:
    if nickname<>invalid and nickname<>m.nickname then
        site_pw=GetSitePassword(nickname)
        if site_pw<>invalid then
            param_list.Push("SitePassword="+site_pw)
        end if
    end if
    
    if method="smugmug.service.ping" then 
        param_list.Append(["APIKey="+m.api_key,"method="+method])
        apiurlstr=m.endpoint+"?"+m.urlencodeParams(param_list)
    else if m.isLinked or Instr(1, method, "smugmug.auth.") then
        time=CreateObject("roDateTime")
        
        copy_param_list = [
            "oauth_consumer_key="+m.api_key,
            "oauth_signature_method=HMAC-SHA1",
            "oauth_timestamp="+itostr(time.asSeconds()),
            "oauth_nonce="+m.md5(itostr(time.asSeconds())+itostr(Int(Rnd(0)*1000000))),
            "oauth_version=1.0",
            "method="+method,
        ]
        for each p in param_list:copy_param_list.Push(p):next
        
        if m.oauth_token<>invalid then
            copy_param_list.Push("oauth_token="+m.oauth_token)
        end if
        
        sig=m.GenOauthSig("GET",copy_param_list)
        copy_param_list.Push("oauth_signature="+sig)
        
        Sort(copy_param_list)
        
        apiurlstr=m.endpoint+"?"+m.urlencodeParams(copy_param_list)
    else if m.session_id=invalid then
        m.http.SetUrl(m.endpoint+"?method=smugmug.login.anonymously&APIKey="+m.api_key)
        xml=m.http.GetToString()
        rsp=ParseXML(xml)
        if rsp=invalid then 
            ShowErrorDialog("Error retrieving results","Unable to obtain session")
            return -1
        end if
        
        if rsp@stat="ok"
            m.session_id=rsp.Login.Session@id
            param_list.Append(["SessionID="+m.session_id,"method="+method])
            apiurlstr=m.endpoint+"?"+m.urlencodeParams(param_list)
        else
            ShowErrorDialog(rsp.err@msg,"Unable to obtain session")
            return -1
        end if
    else
        param_list.Append(["SessionID="+m.session_id,"method="+method])
        apiurlstr=m.endpoint+"?"+m.urlencodeParams(param_list)
    end if
    
    print "ExecServerAPI: ";method
    print apiurlstr
    m.http.SetUrl(apiurlstr)
    xml=m.http.GetToString()
    'print xml
    rsp=ParseXML(xml)
    if rsp=invalid then
        ShowErrorDialog("API return invalid. Try again later","Bad response")
        return -1
    end if
    
    if not rsp@stat="ok" then
        print "API Error: code="+rsp.err@code+" message="+rsp.err@msg
        err_code=rsp.err@code
        err_msg=rsp.err@msg
        
        pretty_error={
            e3: "Session expired.  Please restart channel",
            e4: "Incorrect password",
            e16: "Nickname not found",
            e32: "Authentication Revoked by User",
            e98: "The SmugMug service is currently unavailable.  Try again later",
            e99: "The SmugMug service is currently unavailable.  Try again later",
        }
        
        if pretty_error.Lookup("e"+err_code)<>invalid then
            pretty_msg=pretty_error.Lookup("e"+err_code)
        else
            pretty_msg=err_msg
        end if
        
        if raise_error then ShowErrorDialog(pretty_msg,"API Error")
        if err_code="4" and Instr(1, err_msg, "SitePassword") then
            RegDelete(nickname,"SitePassword")
            site_pw=GetSitePassword(nickname,true)
            if site_pw<>invalid then
                goto exec_api_start
            end if
        end if
        
        return Val(err_code)
    end if
    
    return rsp
End Function

Function GenOauthSig(method, param_list=[]) As String
    Sort(param_list)
    
    str=m.urlencodeParams(param_list)
    'print str
    
    'print "str=";str
    
    apisigstr=method+"&"+m.urlencodeRFC3986(m.endpoint)+"&"+m.urlencodeRFC3986(str)
    
    sigkey=m.urlencodeRFC3986(m.api_secret)+"&"+m.urlencodeRFC3986(m.oauth_token_secret)
    'print "apisigstr: ";apisigstr
    api_sig=m.sha1(apisigstr,sigkey)
    'print "api_sig:";api_sig
    return api_sig
End Function

Function GetSitePassword(nickname, req=false)
    reg_pw=RegRead(nickname,"SitePassword")
    if isstr(reg_pw) then
        return reg_pw
    else if req then
        hint="Enter site password."
        pw=getKeyboardInput("Site password required","Enter site password.","Submit","Cancel")
        if pw<>invalid then RegWrite(nickname,pw,"SitePassword")
        return pw
    end if
    
    return invalid
End Function

Function ExecRSSRequest(url As String) As Dynamic
    m.http.SetUrl(url)
    xml=m.http.GetToString()
    'print xml
    rss=ParseXML(xml)
    if rss=invalid then return invalid
    
    return rss
End Function

' ********************************************************************
' ********************************************************************
' ***** My SmugMug
' ***** My SmugMug
' ********************************************************************
' ********************************************************************
Sub BrowseMySmugMug()
    if not m.isLinked then
        yn=ShowDialog2Buttons("Link account", "Your account is not linked.  Would you like to link your account now?  If you do not have an account with SmugMug, go to "+m.regUrlBase+"/signup to sign up for a free trial and save $5.", "Yes", "No")
        if yn=0 then
            regstat=m.doRegistration()
            if regstat>0 then return
        else
            return
        end if
    end if

	screen=uitkPreShowPosterMenu("","My SmugMug")

    highlights=m.getRandomRssHighlights("http://www.smugmug.com/hack/feed.mg?Type=nicknameRecentPhotos&Data="+m.nickname+"&format=atom10",4)
    for i=0 to 3
        if highlights[i]=invalid then
            highlights[i]="pkg:/images/smuggy.png"
        end if
    end for
    
    menudata=[
        {ShortDescriptionLine1:"Albums", ShortDescriptionLine2:"Browse Recently Updated Albums", HDPosterUrl:highlights[0], SDPosterUrl:highlights[0]},
        {ShortDescriptionLine1:"Categories", ShortDescriptionLine2:"Browse Albums by Category", HDPosterUrl:highlights[1], SDPosterUrl:highlights[1]},
        {ShortDescriptionLine1:"Friends and Family", ShortDescriptionLine2:"Browse Friends and Family Albums", HDPosterUrl:highlights[2], SDPosterUrl:highlights[2]},
        {ShortDescriptionLine1:"Random Photos", ShortDescriptionLine2:"Display slideshow of random photos", HDPosterUrl:highlights[3], SDPosterUrl:highlights[3]},
    ]
    onselect=[0, m, "BrowseAlbums", "BrowseCategories", "BrowseFriendsFamily", "RandomPhotos"]
    
    uitkDoPosterMenu(menudata, screen, onselect)
End Sub

' ********************************************************************
' ********************************************************************
' ***** Albums
' ***** Albums
' ********************************************************************
' ********************************************************************
Sub BrowseAlbums(nickname=m.nickname, displayname=m.displayname)    
    breadcrumb_name=""
    if nickname<>m.nickname and displayname<>m.displayname then
        breadcrumb_name=displayname
    end if
    screen=uitkPreShowPosterMenu(breadcrumb_name,"Albums")
    
    rsp=m.ExecServerAPI("smugmug.albums.get",["Extras=Password,Passworded,Highlight,LastUpdated,External,ImageCount","NickName="+nickname],nickname)
    if not isxmlelement(rsp) then return
    albums=m.newAlbumListFromXML(rsp.albums.album,true,nickname)
    
    onselect = [1, albums, m, function(albums, smugmug, set_idx):smugmug.DisplayAlbum(albums[set_idx]):end function]
    uitkDoPosterMenu(getAlbumMetaData(albums), screen, onselect)
End Sub

Sub DisplayAlbum(album As Object)
    if album.HasPassword() and not album.HasExternal() then
        ShowErrorDialog("Cannot display album with a password and external linking disabled","Album not available")
        return
    else if album.GetImageCount()=0 then
        ShowErrorDialog("Album is empty","Album empty")
        return
    end if
    
    medialist=album.GetImages()
    if medialist=invalid then return
    imagelist=medialist.imagelist
    videolist=medialist.videolist
    
    title=album.GetTitle()
    
    if videolist.Count()>0 then        
        if imagelist.Count()>0 then 'Combined photo and photo album
            screen=uitkPreShowPosterMenu("", title)
            
            albummenudata = [
                {ShortDescriptionLine1:Pluralize(imagelist.Count(),"Photo"),
                 HDPosterUrl:imagelist[0].GetURL("S"),
                 SDPosterUrl:imagelist[0].GetURL("S")},
                {ShortDescriptionLine1:Pluralize(videolist.Count(),"Video"),
                 HDPosterUrl:videolist[0].GetURL("S"),
                 SDPosterUrl:videolist[0].GetURL("S")},
            ]
			onclick=[0, m, ["DisplayImageSet",imagelist,title], ["BrowseVideos",videolist,title]]
            
			uitkDoPosterMenu(albummenudata, screen, onclick)
        else 'Video only album
            m.BrowseVideos(videolist, title)
        end if
    else 'Photo only album
        m.DisplayImageSet(imagelist, title)
    end if
End Sub

Function getAlbumMetaData(albums As Object)
    albummetadata=[]
    for each album in albums
        highlight=album.GetHighlightURL()
        albummetadata.Push({ShortDescriptionLine1: album.GetTitle(), HDPosterUrl: album.GetHighlightURL(), SDPosterUrl: album.GetHighlightURL()})
    next
    return albummetadata
End Function

Function newAlbumListFromXML(xmllist As Object, sortlist=true As Boolean, nickname=invalid As Dynamic) As Object
    albumlist=CreateObject("roList")
    for each record in xmllist
        album=m.newAlbumFromXML(record, nickname)
        
        albumlist.Push(album)
    next

    'Sort by update date, reverse to descending date order
    if sortlist then
        Sort(albumlist, function(album):return album.GetLastUpdated():end function)
        Reverse(albumlist)
    end if
    
    return albumlist
End Function

Function newAlbumFromXML(xml As Object, nickname As String) As Object
    album = CreateObject("roAssociativeArray")
    album.smugmug=m
    album.xml=xml
    album.nickname=nickname
    album.GetTitle=function():return m.xml@Title:end function
    album.GetID=function():return m.xml@id:end function
    album.GetKey=function():return m.xml@Key:end function
    album.GetImageCount=function():return Val(m.xml@ImageCount):end function
    album.GetPassword=aGetPassword
    album.HasPassword=function():return strtobool(m.xml@Passworded):end function
    album.HasExternal=function():return strtobool(m.xml@External):end function
    album.GetLastUpdated=function():return m.xml@LastUpdated:end function
    album.GetHighlightURL=aGetHighlightURL
    album.GetImages=aGetImages
    return album
End Function

Function aGetHighlightURL() As String
    if m.xml.highlight@id<>invalid then
        return m.smugmug.getImageURL(m.xml.highlight@id, m.xml.highlight@key, "S")
    else if m.HasPassword()=1 then
        return "pkg:/images/smuggy.png"
    else
        return m.smugmug.RandomUrlBase+"AlbumID="+m.GetID()+"&AlbumKey="+m.GetKey()+"&Size=S"
    end if
End Function

Function aGetImages(automated=false) As Dynamic
    params=["AlbumID="+m.GetID(),"AlbumKey="+m.GetKey(),"Extras=LargeURL,MediumURL,SmallURL,ThumbURL,Duration,Video320URL,Video640URL,Video960URL,Video1280URL,Hidden,Caption,Width,Height","Sandboxed=1"]
    if m.HasPassword() and not automated then
        pw=m.GetPassword()
        if pw=invalid return invalid
        params.Push("Password="+pw)
    end if
    
    if automated then
        raise_error=false
    else
        raise_error=true
    end if
    
    rsp=m.smugmug.ExecServerAPI("smugmug.images.get",params,m.nickname,raise_error)
    if not isxmlelement(rsp) then 
        if rsp=4 then RegDelete(m.GetID(),"AlbumPassword")
        return invalid
    end if
    return m.smugmug.newImageListFromXML(rsp.album.images.image)
End Function

Function aGetPassword()
    if isstr(m.xml@Password) 
        return m.xml@Password
    else
        reg_pw=RegRead(m.GetID(),"AlbumPassword")
        if isstr(reg_pw) then
            return reg_pw
        else
            hint="Enter album password."
            if isstr(m.xml@PasswordHint) then
                hint="Hint: "+m.xml@PasswordHint
            end if
            pw=getKeyboardInput("Password required",hint,"Submit","Cancel")
            if pw<>invalid then RegWrite(m.GetID(),pw,"AlbumPassword")
            return pw
        end if
    end if
End Function


' ********************************************************************
' ********************************************************************
' ***** Images
' ***** Images
' ********************************************************************
' ********************************************************************
Function newImageListFromXML(xmllist As Object) As Object
    medialist=CreateObject("roAssociativeArray")
    imagelist=CreateObject("roList")
    videolist=CreateObject("roList")
    for each record in xmllist
        media=newImageFromXML(record)
        if media.IsHidden()=0 then
            if media.IsVideo()=0
                imagelist.Push(media)
            else
                videolist.Push(media)
            end if
        end if
    next
    
    medialist.imagelist=imagelist
    medialist.videolist=videolist
    
    return medialist
End Function

Function newImageFromXML(xml As Object) As Object
    image = CreateObject("roAssociativeArray")
    image.xml=xml
    image.GetCaption=function():return m.xml@caption:end function
    image.GetID=function():return m.xml@id:end function
    image.GetKey=function():return m.xml@key:end function
    image.GetURL=getAPIImageURL
    image.Get=function(name):return m.xml.GetAttributes()[name]:end function
    image.IsVideo=iIsVideo
    image.IsHidden=iIsHidden
    return image
End Function

Sub BrowseImages(images AS Object, title="" As String)
    screen=uitkPreShowPosterMenu(title,"Photos")
    
    while true
        selected=uitkDoPosterMenu(getImageMetaData(images), screen)
        print selected
        if selected>-1 then
            m.DisplayImageSet(images, title, selected)
        else
            return
        end if
    end while
End Sub

'This is an owner only function, so when on another user we only get public photos
Function iIsHidden() As Boolean
    if m.xml@hidden=invalid then return 0
    return Val(m.xml@hidden)
End Function

Function iIsVideo() As Boolean
    if m.xml@Duration<>invalid then return 1
    return 0
End Function

Function getImageURL(image_id, image_key, size="L" As String, ext="jpg" As String) As String
    url="http://www.smugmug.com/photos/"+image_id+"_"+image_key+"-"+size+"."+ext
    return url
End Function

Function getAPIImageURL(size="L" As String, ext="jpg" As String) As String
    width=Val(m.Get("Width"))
    height=Val(m.Get("Height"))
    
    if size="L" then
        if width<=600 or height<=450 then
            size="M"
        end if
    else if size="M" then
        if width<=400 or height<=300 then
            size="S"
        end if
    end if
    
    if size="L" then
        size="LargeURL"
        size2="MediumURL"
	else if size="M" then
		size="MediumURL"
		size2="SmallURL"
    else if size="S" then
        size="SmallURL"
        size2="ThumbURL"
    end if
    
    url=m.Get(size)
    if url=invalid then url=m.Get(size2)
    if url=invalid then url=""
    
    return url
End Function

'RSS Image
Function newImageListFromRSS(xmllist As Object) As Object
    print "in newImageListFromRSS"
    imagelist=CreateObject("roList")
    for each record in xmllist
        imagelist.Push(newImageFromRSS(record))
    next
    return imagelist
End Function

Function newImageFromRSS(xml As Object) As Object
    image = CreateObject("roAssociativeArray")
    image.xml=xml
    image.GetCaption=function():return m.xml.title.GetText():end function
    image.GetID=function():return getImageIdFromURL(m.xml.link@href, "id"):end function
    image.GetKey=function():return getImageIdFromURL(m.xml.link@href, "key"):end function
    image.GetURL=function(size):return getImageURL(m.GetID(), m.GetKey(), size):end function
    return image
End Function

'Parse id and key from image URL
Function getImageIdFromURL(url As String, typ As String) As String
    'Getting image string (<id>_<key>)
    image_str=Right(url, Len(url)-InStr(1, url, "#"))

    'Get id
    delim_pos=InStr(1, image_str, "_")
    if typ="id" then
        return Left(image_str, delim_pos-1)
    else if typ="key"
        return Right(image_str,Len(image_str)-delim_pos)
    end if
End Function

Function getImageMetaData(images As Object)
    imagemetadata=[]
    for each image in images
        print image.GetCaption()
        imagemetadata.Push({ShortDescriptionLine1: image.GetCaption(), HDPosterUrl: image.GetURL("S"), SDPosterUrl: image.GetURL("S")})
    next
    return imagemetadata
End Function

Function getRandomRssHighlights(url As String, image_count As Integer, random=true As Boolean) As Object
    highlights=[]
    rsp=m.ExecRSSRequest(url)
    if rsp=invalid then
        for i=0 to image_count-1
            highlights.Push("pkg:/images/smuggy.png")
        end for
        return highlights
    end if
    
    images=newImageListFromRSS(rsp.entry)
    highlights=[]
    image_cache={}
    counter=1 'Counter to prevent infinite loop
    while highlights.Count()<image_count
        if counter>50 or counter>images.Count() then exit while
        
        if random then
            image_idx=Rnd(images.Count()-1)
        else
            image_idx=counter-1
        end if
        
        if not image_cache.Lookup(itostr(image_idx))=1 then
            highlights.Push(images[image_idx].GetURL("S"))
            image_cache.AddReplace(itostr(image_idx),1)
        end if
        
        counter=counter+1
    end while
    
    return highlights
End Function


' ********************************************************************
' ********************************************************************
' ***** Categories
' ***** Categories
' ********************************************************************
' ********************************************************************
Sub BrowseCategories(nickname=m.nickname As String, parentname="" As String, categories=invalid As Dynamic)
    if categories=invalid then
        bread="Categories"
    else
        bread="Subcategories"
    end if
    screen=uitkPreShowPosterMenu(parentname, bread)
    
    'Get user category tree
    if categories=invalid then
        rsp=m.ExecServerAPI("smugmug.users.getTree",["Extras=Password,Passworded,Highlight,LastUpdated,ImageCount","Empty=0","NickName="+nickname],nickname)
        if not isxmlelement(rsp) then return
        categories=m.newCategoryListFromXML(rsp.categories.category, nickname)
    end if
    
    categoryList=[]
    for each cat in categories
        categoryList.Push(cat.GetName())
    end for
    
    content_callback=[categories, m, CategoriesContentCallback]
    onclick_callback=[categories, m, CategoriesOnclickCallback]
    
    uitkDoCategoryMenu(categoryList, screen, content_callback, onclick_callback)
End Sub

Function CategoriesContentCallback(categories, smugmug, cat_idx) As Object
    category=categories[cat_idx]
    metadata=[]
    if category.HasSubcategories()=true then
        highlight=category.GetSubcategories()[0].GetAlbums()[0].GetHighlightURL()
        metadata.Push({ShortDescriptionLine1: "Subcategories", HDPosterUrl: highlight, SDPosterUrl: highlight})
    end if
    albummetadata=getAlbumMetaData(category.GetAlbums())
    for each album in albummetadata
        metadata.Push(album)
    end for
    
    return metadata
End Function

Sub CategoriesOnclickCallback(categories, smugmug, cat_idx, set_idx)
    category=categories[cat_idx]
    
    'Reset album index to correct position
    if category.HasSubcategories()=true then
        set_idx=set_idx-1
    end if

    if set_idx=-1 then
        smugmug.BrowseCategories(category.nickname, category.GetName(), category.GetSubcategories())
    else
        smugmug.DisplayAlbum(category.GetAlbums()[set_idx])
    end if
End Sub

Function newCategoryListFromXML(xmllist As Object, nickname As String, catid="" As String) As Object
    'Create name mapping AA
    namemap=CreateObject("roAssociativeArray")
    if catid="" then
        rsp=m.ExecServerAPI("smugmug.categories.get",["NickName="+nickname],nickname)
        if not isxmlelement(rsp) then return invalid
        for each rec in rsp.categories.category
            namemap.AddReplace(rec@id, rec@Name)
        next
    else
        rsp=m.ExecServerAPI("smugmug.subcategories.get",["CategoryID="+catid,"NickName="+nickname],nickname)
        if not isxmlelement(rsp) then return invalid
        for each rec in rsp.subcategories.subcategory
            namemap.AddReplace(rec@id, rec@Name)
        next
    end if
    
    categorylist=CreateObject("roList")
    for each record in xmllist
        category=m.newCategoryFromXML(record, namemap, nickname)
        if category.GetAlbums().Count() > 0 or category.HasSubcategories() then
            categorylist.Push(category)
        end if
    next

    'Sort categories by name
    Sort(categorylist, function(category):return category.GetSortName():end function)
    
    return categorylist
End Function

Function newCategoryFromXML(xml As Object, namemap As Object, nickname As String) As Object
    subcategories=[]
    if xml.subcategories.subcategory.Count()>0 then
        subcategories=m.newCategoryListFromXML(xml.subcategories.subcategory, nickname, xml@id)
    end if
    
    category = CreateObject("roAssociativeArray")
    category.smugmug=m
    category.xml=xml
    category.namemap=namemap
    category.nickname=nickname
    category.subcategories=subcategories
    category.GetID=function():return m.xml@id:end function
    category.GetAlbums=function():return m.smugmug.newAlbumListFromXML(m.xml.albums.album, false, m.nickname):end function
    category.HasSubcategories=cHasSubcategories
    category.GetSubcategories=function():return m.subcategories:end function
    category.GetName=function():return m.namemap.Lookup(m.xml@id):end function
    category.GetSortName=cGetSortName
    return category
End Function

Function cHasSubcategories() As Boolean
    if m.subcategories.Count()>0 then
        return true
    end if
    
    return false
End Function

Function cGetSortName() As String
    name=m.GetName()
    if name="Other" then return "zzzzzzzz"
    return name
End Function


' ********************************************************************
' ********************************************************************
' ***** Browse SmugMug
' ***** Browse SmugMug
' ********************************************************************
' ********************************************************************
Sub BrowseSmugmug()
    screen=uitkPreShowPosterMenu("","Browse SmugMug")
    
    highlights=m.highlights
    
    menudata=[
        {ShortDescriptionLine1:"Popular Photos", ShortDescriptionLine2:"Browse Today's Popular Photos", HDPosterUrl:highlights[4], SDPosterUrl:highlights[4]},
        {ShortDescriptionLine1:"Popular Photos by Category", ShortDescriptionLine2:"Browse Popular Photos by Category", HDPosterUrl:highlights[5], SDPosterUrl:highlights[5]},
        {ShortDescriptionLine1:"Keyword Search", ShortDescriptionLine2:"Search Recent Images By Keyword", HDPosterUrl:highlights[6], SDPosterUrl:highlights[6]},
        {ShortDescriptionLine1:"Search", ShortDescriptionLine2:"Photo Search", HDPosterUrl:highlights[7], SDPosterUrl:highlights[7]},
    ]
    onselect = [0, m, "DisplayPopular", "BrowseSmugmugCategories", "PhotoSearch", ["PhotoSearch","search"]]
    
    uitkDoPosterMenu(menudata, screen, onselect)
End Sub

Sub DisplayPopular()
    rsp=m.ExecRSSRequest(m.PopularUrlBase+"today")
    if rsp=invalid then
        ShowErrorDialog("Bad feed response. Try again.","Bad Feed")
        return
    end if
    images=newImageListFromRSS(rsp.entry)
    
    m.DisplayImageSet(images,"Popular")
End Sub

Sub BrowseSmugmugCategories()
    screen=uitkPreShowPosterMenu("","Browse Categories")
    port=screen.GetMessagePort()
    
    categorydata=[]
    categoryimages=[]
    
    counter=0
    categories=GetStaticCategories()
    while categories.IsNext()
        category=categories.Next()
        
        rsp=m.ExecRSSRequest("http://www.smugmug.com/hack/feed.mg?Type=popularCategory&Data="+m.http.UrlEncode(category)+"&format=atom10")
        if rsp=invalid then
            ShowErrorDialog("Bad feed response. Try again.","Bad Feed")
            return
        end if
        images=newImageListFromRSS(rsp.entry)
        
        categorydata.Push({ShortDescriptionLine1:category, HDPosterUrl:images[0].GetURL("S"), SDPosterUrl:images[0].GetURL("S")})
        categoryimages.Push(images)
        
        msg = port.GetMessage()
        if type(msg) = "roPosterScreenEvent" then
            if msg.isListItemSelected() then
				selected=msg.GetIndex()
                m.DisplayImageSet(categoryimages[selected],screen.GetContentList()[selected].Lookup("ShortDescriptionLine1"))
            else if msg.isScreenClosed() then
                return
            end if
        end if
        
        counter=counter+1
        if counter=3 then
            screen.SetContentList(categorydata)
            counter=0
        end if
    end while
    
    if counter>0 then screen.SetContentList(categorydata)
    
    while true
        msg = wait(0, port)
        if type(msg) = "roPosterScreenEvent" then
            if msg.isListItemSelected() then
				selected=msg.GetIndex()
                m.DisplayImageSet(categoryimages[selected],screen.GetContentList()[selected].Lookup("ShortDescriptionLine1"))
            else if msg.isScreenClosed() then
                return
            end if
        end if        
    end while
End Sub

Sub PhotoSearch(searchtype="keyword")
    port=CreateObject("roMessagePort") 
    screen=CreateObject("roSearchScreen")
    if searchtype="keyword" then
        screen.SetBreadcrumbText("", "Keyword Search")
    else
        screen.SetBreadcrumbText("", "Search")
    end if
    screen.SetMessagePort(port)
    
    history=CreateObject("roSearchHistory")
    screen.SetSearchTerms(history.GetAsArray())
    
    screen.Show()
    
    while true
        msg = wait(0, port)
        
        if type(msg) = "roSearchScreenEvent" then
            print "Event: "; msg.GetType(); " msg: "; msg.GetMessage()
            if msg.isScreenClosed() then
                return
            else if msg.isFullResult()
                keyword=msg.GetMessage()
                dialog=ShowPleaseWait("Please wait","Searching images for "+keyword)
                rsp=m.ExecRSSRequest("http://smugmug.com/hack/feed.mg?Type="+searchtype+"&Data="+m.http.UrlEncode(keyword)+"&format=atom10")
                if rsp=invalid then
                    ShowErrorDialog("Bad feed response. Try again.","Bad Feed")
                    return
                end if
                images=newImageListFromRSS(rsp.entry)
                dialog.Close()
                if images.Count()>0 then
                    history.Push(keyword)
                    screen.AddSearchTerm(keyword)
                    m.DisplayImageSet(images)
                else
                    ShowErrorDialog("No images match your search","Search results")
                end if
            else if msg.isCleared() then
                history.Clear()
            end if
        end if
    end while
End Sub

' ********************************************************************
' ********************************************************************
' ***** Random Slideshow
' ***** Random Slideshow
' ********************************************************************
' ********************************************************************
Sub RandomPhotos(nickname=m.nickname)
    ss=m.PrepDisplaySlideShow()
    
    rsp=m.ExecServerAPI("smugmug.albums.get",["Extras=Password,Passworded,Highlight,LastUpdated,ImageCount","NickName="+nickname],nickname)
    if not isxmlelement(rsp) then return
    albums=m.newAlbumListFromXML(rsp.albums.album, true, nickname)
    
    ss.SetPeriod(m.SlideshowDuration)
    port=ss.GetMessagePort()
    
    image_univ=[]
    for i=0 to albums.Count()-1
        image_count=albums[i].GetImageCount()
        for j=0 to image_count-1
            image_univ.Push([i,j])
        end for
    end for
    
    album_cache={}
    album_skip={}
    while true
        next_image:
        'Select image from total universe
        selected_idx=Rnd(image_univ.Count())-1
        
        'Caching image lookup results, saves us some API calls
        album_idx=image_univ[selected_idx][0]
        
        'Skip if passworded
        if album_skip.DoesExist(itostr(album_idx)) then goto next_image
        
        if album_cache.DoesExist(itostr(album_idx)) then
            albumimages=album_cache.Lookup(itostr(album_idx))
        else
            medialist=albums[album_idx].GetImages(true)
            if medialist=invalid then 
                album_skip.AddReplace(itostr(album_idx),1)
                goto next_image
            end if
            albumimages=medialist.imagelist
            album_cache.AddReplace(itostr(album_idx), albumimages)
        end if
        
        image_idx=image_univ[selected_idx][1]
        image=albumimages[image_idx]
        
        if image<>invalid then
            image.Info={}
            image.Info.TextOverlayUL="Album: "+albums[album_idx].GetTitle()
            
            imagelist=[image]
            
            m.AddNextimageToSlideShow(ss, imagelist, 0)
            while true
                msg = port.GetMessage()
                if msg=invalid then exit while
                if m.ProcessSlideShowEvent(ss, msg, imagelist) then return
            end while
            
            'Sleeping for Slideshow Duration - 2.5 seconds
            sleep((m.SlideshowDuration-2.5)*1000)
        end if
    end while
End Sub

' ********************************************************************
' ********************************************************************
' ***** Friends & Family
' ***** Friends & Family
' ********************************************************************
' ********************************************************************
Sub BrowseFriendsFamily()
    screen=uitkPreShowPosterMenu()
    
    rsp=m.ExecServerAPI("smugmug.friends.get")
    if not isxmlelement(rsp) then return
    friends=newFFListFromXML(rsp.friends.friend)
    
    rsp=m.ExecServerAPI("smugmug.family.get")
    if not isxmlelement(rsp) then return
    family=newFFListFromXML(rsp.family.family)
    
    ff_list=[]
    ff_data=[]
    if friends.Count()>0 then 
        ff_list.Push("Friends")
        ff_data.Push(friends)
    end if
    if family.Count()>0 then 
        ff_list.Push("Family")
        ff_data.Push(family)
    end if
    
    if ff_list.Count()>1 then
        screen=uitkPreShowPosterMenu("","Friends & Family")
        
        content_callback=[ff_data, m, function(ff_data, smugmug, cat_idx):return smugmug.getFFMetaData(ff_data[cat_idx]):end function]
        onclick_callback=[ff_data, m, function(ff_data, smugmug, cat_idx, set_idx):smugmug.DisplayFriendsFamily(ff_data[cat_idx][set_idx]):end function]
        uitkDoCategoryMenu(ff_list, screen, content_callback, onclick_callback)
    else if ff_list.Count()=1 then
        screen=uitkPreShowPosterMenu("",ff_list[0])
        
        onselect = [1, ff_data[0], m, function(ff, smugmug, set_idx):smugmug.DisplayFriendsFamily(ff[set_idx]):end function]
        uitkDoPosterMenu(m.getFFMetaData(ff_data[0]), screen, onselect)
    else
        uitkDoMessage("You are not linked to any friends or family.  To find out more about linking to friend and family go to http://www.smugmug.com/help/friends-and-family.", screen)
    end if
End Sub

Sub DisplayFriendsFamily(ff As Object)
    screen=uitkPreShowPosterMenu("",ff.Lookup("DisplayName"))
    
    'Get highlights from recent photo feed
    highlights=m.getRandomRssHighlights(m.RecentUrlBase+ff.Lookup("nickname"),3)
    for i=0 to 2
        if highlights[i]=invalid then
            highlights[i]="pkg:/images/smuggy.png"
        end if
    end for
    
    menudata = [
         {ShortDescriptionLine1:"Albums", ShortDescriptionLine2:"Browse Recently Updated Albums", HDPosterUrl:highlights[0], SDPosterUrl:highlights[0]},
         {ShortDescriptionLine1:"Categories", ShortDescriptionLine2:"Browse Albums by Category", HDPosterUrl:highlights[1], SDPosterUrl:highlights[1]},
         {ShortDescriptionLine1:"Random Photos", ShortDescriptionLine2:"Display slideshow of random photos", HDPosterUrl:highlights[2], SDPosterUrl:highlights[2]},
    ]
	
	nickname=ff.Lookup("NickName")
	displayname=ff.Lookup("DisplayName")
	onclick=[0, m, ["BrowseAlbums",nickname,displayname], ["BrowseCategories",nickname,displayname], ["RandomPhotos",nickname]]
    
	uitkDoPosterMenu(menudata, screen, onclick)
End Sub

Function newFFListFromXML(xmllist As Object)
    fflist=[]
    for each ff in xmllist
        fflist.Push({DisplayName:ff@DisplayName, NickName:ff@NickName, URL:ff@URL})
    end for
    
    Sort(fflist, function(ff):return ff.Lookup("DisplayName"):end function)
    
    return fflist
End Function

Function getFFMetaData(ff As Object, desc1="DisplayName" As String, desc2="URL" As String)
    ffmetadata=[]
    for each f in ff
        highlight=m.getRandomRssHighlights(m.RecentUrlBase+f.Lookup("nickname"),1,false)[0]
        if highlight=invalid then
            highlight="pkg:/images/smuggy.png"
        end if
        ffmetadata.Push({ShortDescriptionLine1: f.Lookup(desc1), ShortDescriptionLine2: f.Lookup(desc2), HDPosterUrl: highlight, SDPosterUrl: highlight})
    next
    
    return ffmetadata
End Function


' ********************************************************************
' ********************************************************************
' ***** Videos
' ***** Videos
' ********************************************************************
' ********************************************************************
Sub BrowseVideos(videos As Object, title As String)
    if videos.Count()=1 then
        m.DisplayVideo(GetVideoMetaData(videos)[0])
    else
        screen=uitkPreShowPosterMenu(title,"Videos")
        metadata=GetVideoMetaData(videos)
        
        onselect = [1, metadata, m, function(video, smugmug, set_idx):smugmug.DisplayVideo(video[set_idx]):end function]
        uitkDoPosterMenu(metadata, screen, onselect)
    end if
End Sub

Function GetVideoMetaData(videos As Object)
    metadata=[]
    
    'Ignoring 1920 since Roku player only supports 720p
    res=[320, 640, 960, 1280]
    bitrates=[660, 1400, 2000, 3200]
    qualities=["SD", "SD", "SD", "HD"]
    
    for each video in videos
        meta=CreateObject("roAssociativeArray")
        meta.ContentType="movie"
        meta.Title=video.GetCaption()
        meta.ShortDescriptionLine1=meta.Title
        meta.SDPosterUrl=video.GetURL("S")
        meta.HDPosterUrl=video.GetURL("S")
        meta.StreamBitrates=bitrates
        meta.StreamQualities=qualities
        meta.StreamFormat="mp4"
        
        meta.StreamBitrates=[]
        meta.StreamQualities=[]
        meta.StreamUrls=[]
        width=Val(video.Get("Width"))
        for i=0 to res.Count()-1
            url=video.Get("Video"+itostr(res[i])+"URL")
            if url<>invalid and res[i] <= width then
                meta.StreamUrls.Push(url)
                meta.StreamBitrates.Push(bitrates[i])
                meta.StreamQualities.Push(qualities[i])
                if res[i]>960 then
                    meta.IsHD=True
                    meta.HDBranded=True
                end if
            end if
        end for
        meta.Length=video.Get("Duration")
        
        metadata.Push(meta)
    end for
    
    return metadata
End Function


Function DisplayVideo(content As Object)
    print "Displaying video: "
    p = CreateObject("roMessagePort")
    video = CreateObject("roVideoScreen")
    video.setMessagePort(p)
    
    video.SetContent(content)
    video.show()
    
    while true
        msg = wait(0, video.GetMessagePort())
        if type(msg) = "roVideoScreenEvent"
            if msg.isScreenClosed() then 'ScreenClosed event
                print "Closing video screen"
                video.Close()
                exit while
            else if msg.isRequestFailed()
                print "play failed: "; msg.GetMessage()
            else
                print "Unknown event: "; msg.GetType(); " msg: "; msg.GetMessage()
            end if
        end if
    end while
End Function


' ********************************************************************
' ********************************************************************
' ***** DisplaySlideShow
' ***** DisplaySlideShow
' ********************************************************************
' ********************************************************************
Sub AddNextImageToSlideShow(ss, imagelist, counter)
    if imagelist.IsNext() then
        image=imagelist.Next()
        if image.Info=invalid then
            image.Info={}
        end if
        image.Info.url=image.GetURL("L")
        
        if counter>0 then image.Info.TextOverlayUR=itostr(counter)+" of "+itostr(imagelist.Count())
        image.Info.TextOverlayBody=image.GetCaption()
        ss.AddContent(image.Info)
    end if
End Sub

Function PrepDisplaySlideShow()
    print "---- Prep DisplaySlideShow  ----"
    
    ss = CreateObject("roSlideShow")
    ss.Show()
    mp = CreateObject("roMessagePort")
    if mp=invalid then print "roMessagePort Create Failed":stop
    ss.SetMessagePort(mp)
    ss.SetPeriod(0)
    'ss.SetDisplayMode("best-fit")
    ss.SetDisplayMode("scale-to-fit")
    ss.AddContent( {url : "file://pkg:/images/slideshow_splash.png"} )
    
    return ss
End Function

function ProcessSlideShowEvent(ss, msg, imagelist, onscreenimage=invalid, title=invalid)
    if type(msg)="roSlideShowEvent" then
        'print "roSlideShowEvent. Type ";msg.GetType();", index ";msg.GetIndex();", Data ";msg.GetData();", msg ";msg.GetMessage()
        if msg.isScreenClosed() then
            return true
        else if msg.IsPaused() then
            ss.SetTextOverlayIsVisible(true)
        else if msg.isRemoteKeyPressed() and msg.GetIndex()=3 and ss.CountButtons()=0 then
            ss.SetTextOverlayIsVisible(false)
            ss.ClearButtons()
            if onscreenimage<>invalid then 'This means we are streaming images
                ss.AddButton(0, "Browse Photos")
                ss.AddButton(1, "Cancel")
            end if
        else if msg.IsResumed() then
            ss.SetTextOverlayIsVisible(false)
            ss.ClearButtons()
		else if msg.isButtonPressed() then
			ss.ClearButtons()
			ss.SetTextOverlayIsVisible(false)
			if msg.GetIndex()=0 then 
                ss.Close()'Since we are browsing, this slideshow is no longer necessary
                m.BrowseImages(imagelist, title)
                return true
            end if
        else if msg.isPlaybackPosition() and onscreenimage<>invalid
            onscreenimage[0]=msg.GetIndex()
            if onscreenimage[0]=imagelist.Count()   'last photo shown
                'Restart slide show, skip splash screen
                ss.SetNext(1, false)
            end if
        end if
    end if
    
    return false
End Function

Sub DisplaySlideShow(ss, imagelist, title)
    print "---- Do DisplaySlideShow  ----"
    
    imagelist.Reset()   ' reset ifEnum
    if not imagelist.IsNext() then return
    sleep(1000) ' let image decode faster; no proof this actually helps
    ss.SetPeriod(m.SlideshowDuration)
    onscreenimage=[0]  'using a list so i can pass reference instead of pass by value
    port=ss.GetMessagePort()

    ' add all the images to the slide show as fast as possible, while still processing events
    counter=1
    while imagelist.IsNext()
        m.AddNextimageToSlideShow(ss, imagelist, counter)
        while true
            msg = port.GetMessage()
            if msg=invalid then exit while
            if m.ProcessSlideShowEvent(ss, msg, imagelist, onscreenimage, title) then return
        end while
        counter=counter+1
    end while

    ' all images have been added to the slide show at this point, so just process events
    while true
        msg = wait(0, port)
        if m.ProcessSlideShowEvent(ss, msg, imagelist, onscreenimage, title) then return
    end while
End Sub

Sub DisplayImageSet(imagelist As Object, title="" As String, start=0 As Integer)
    ss=m.PrepDisplaySlideShow()
    
    'Change order if start is specified
    if start>0 then
        counter=0
        image_idx=start
        copy_imagelist=[]
        while counter<imagelist.Count()
            copy_imagelist.Push(imagelist[image_idx])
            
            if image_idx=imagelist.Count()-1 then
                image_idx=0
            else
                image_idx=image_idx+1
            end if
            
            counter=counter+1
        end while
        
        imagelist=copy_imagelist
    end if
    
    m.DisplaySlideShow(ss, imagelist, title)
    ss.Close() ' take down roSlideShow
End Sub

' ********************************************************************
' ********************************************************************
' ***** URL URL URL
' ***** URL URL URL
' ********************************************************************
' ********************************************************************
Function urlencodeRFC3986(str As String) As String
    str=m.http.URLEncode(str)
    str=strReplace(str, "~", "%7E")
    
    return str
End Function

Function urlencodeParams(param_list=[]) As String
    str=""
    for each p in param_list
        eq_pos=instr(1,p,"=")
        str=str+m.urlencodeRFC3986(Left(p,eq_pos-1))+"="+m.urlencodeRFC3986(Mid(p,eq_pos+1))+"&"
    end for
    
    return Left(str,str.Len()-1)
End Function
