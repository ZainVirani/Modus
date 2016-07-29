//
//  ViewController.swift
//  Modus
//
//  Created by Zain Virani on 2016-06-27.
//  Copyright © 2016 Modus Applications. All rights reserved.
//

import Foundation
import UIKit
import RealmSwift
import MediaPlayer

class musicLibraryController: UIViewController{
    
    //INTERNAL VARS
    
    private var timer: NSTimer?
    private var timeRatio: Float32 = 0.00
    //TODO: replace externalICT with unlock notification and minibar down notification
        //var instanceOfCustomObject: LockViewController = LockViewController()
        //instanceOfCustomObject.registerAppforDetectLockState();
    private var externalInputCheckTimer: NSTimer?
    
    private var player = Player()
    
    private var musicQueue: [MPMediaItem] = []
    private var albumQueue: [MPMediaItem] = []
    private var artistQueue: [MPMediaItem] = []
    private var subAlbumQueue: [MPMediaItem] = []
    private var subMusicQueue: [MPMediaItem] = []
    private var subArtistQueue: [MPMediaItem] = []
    //private var recentAlbums: [MPMediaItem] = []
    //private var recentSongs: [MPMediaItem] = []
    
    private var shuffleQueue: [Int] = []
    private var shuffleIndex = 1
    private var newSongCount = 0 //don't save to Realm
    private var oldSongCount = 0 //save to Realm on each sync
    private var oldPlayerState = 1 //starts paused
    private var oldPlayerItem: Int?
    private var previousCellIndex = 0
    private var currentCellIndex = 0
    private var firstPlay = false
    private var sortChanged = false
    
    private enum order{
        case normal
        case shuffle
        case repeatItem
    }
    
    private enum itemType{
        case song
        case album
        case artist
        case subAlbum
        case subSong
        case subArtist
    }
    
    private enum oldSub{
        case subAlbum
        case album
        case recentAlb
    }
    
    private var oldSubItem = oldSub.album
    private var oldSubRow = 0
    private var oldAlbumSubSort = -1
    private var orderToPlay = order.normal
    private var itemToDisplay = itemType.song
    private var preSearchSort = -1
    private var preSearchSubSort = -1
    
    //REALM VARS
    
    private let realm = try! Realm()
    private var appData: Results<AppData>?
    //private var realmRecentAlbums: Results<RecentAlbums>?
    
    //TABLE/SORT/SEARCH
    
    @IBOutlet weak private var itemTable: UITableView!
    @IBOutlet weak private var sortType: UISegmentedControl!
    @IBOutlet weak private var subSortType: UISegmentedControl!
    @IBOutlet weak private var searchBar: UISearchBar!
    private var oldSearchText = ""
    private var oldSearchDisp = itemType.song
    private var backToSearch = true
    private let searchController = UISearchController(searchResultsController: nil)
    
    //MINI PLAYER
    
    @IBOutlet weak private var playerArtwork: UIImageView!
    @IBOutlet weak private var playerTitle: UILabel!
    @IBOutlet weak private var playerInfo: UILabel!
    @IBOutlet weak private var playerPlayButton: UIButton!
    @IBOutlet weak private var playerCurrTime: UILabel!
    @IBOutlet weak private var playerTotTime: UILabel!
    @IBOutlet weak private var playerProgress: UISlider!
    @IBOutlet weak private var playOrder: UIButton!
    
    //viewDidLoad calls functions to retrieve app data, sync the user's iTunes library, initialize the system music player and populate the tableView.
    //If the music queue is empty (no songs are on the device) the player is not initialized and the table is not populated
    override func viewDidLoad() {
        super.viewDidLoad()
        retreiveData()
        syncLibrary()
        if musicQueue.isEmpty{
            return
        }
        else{
            setupPlayer()
            reloadTableInMainThread()
        }
    }
    
    //retrieveData pulls app data from realm and stores it in the correct variable(s)
    func retreiveData(){
        appData = realm.objects(AppData) //retrieve app data
        //realmRecentAlbums = realm.objects(RecentAlbums)
        if let data = appData{
            if data.isEmpty{
                let newAppData = AppData() //create new
                newAppData.name = "oldSongCount"
                newAppData.value = oldSongCount
                newAppData.content = "contains old song count"
                try! realm.write() {
                    realm.add(newAppData)
                }
                print("app data created")
                let alertController = UIAlertController(title: "modus", message:
                    "It seems you are new to modus! Welcome.\nCurrently, the tag editor and full player are under maintenance.", preferredStyle: UIAlertControllerStyle.Alert)
                alertController.addAction(UIAlertAction(title: "Dismiss", style: UIAlertActionStyle.Default,handler: nil))
                
                self.presentViewController(alertController, animated: true, completion: nil)
            }
            else{
                oldSongCount = data[0].value //retrieve old
                print("app data retrieved... OSC = \(oldSongCount)")
            }
        }
        /*if let recAlb = realmRecentAlbums{
            if recAlb.isEmpty{
                print("no rec alb data found")
            }
            else{
                recentAlbums = recAlb[0].albumArray
                recentSongs = recAlb[0].songsArray
                print("rec alb retrieved... RAC = \(recentAlbums.count)")
                print("rec son retrieved... RSC = \(recentSongs.count)")
            }
        }*/
    }
    
    //setupPlayer uses an instance of the Player class to set the first queue and starts a timer to check for external inputs (external from the app)
    //This function also sets up a few other settings that don't fit in to the scope of other functions
    func setupPlayer(){
        player.setQueue(musicQueue)
        playerProgress.setThumbImage(UIImage(named: "circle.png"), forState: UIControlState.Normal)
        externalInputCheckTimer = NSTimer.scheduledTimerWithTimeInterval(0.001, target: self, selector: #selector(musicLibraryController.checkExternalButtonPress), userInfo: nil, repeats: true)
        itemTable.separatorStyle = UITableViewCellSeparatorStyle.SingleLineEtched
        searchBar.delegate = self
        let textFieldInsideSearchBar = searchBar.valueForKey("searchField") as? UITextField
        textFieldInsideSearchBar?.textColor = UIColor.whiteColor()
    }
    
    //isLibraryEmpty relays a message to the user if there are no songs in the music queue
    func isLibraryEmpty() -> Bool{
        if musicQueue.isEmpty{
            let alertController = UIAlertController(title: "modus", message:
                "No items found.\nMake sure there are music files on the device, then reload the app.", preferredStyle: UIAlertControllerStyle.Alert)
            alertController.addAction(UIAlertAction(title: "Dismiss", style: UIAlertActionStyle.Default,handler: nil))
            
            self.presentViewController(alertController, animated: true, completion: nil)
            return true
        }
        return false
    }
    
    //syncLibrary scrapes the device for all "songs" (MPMediaItem), it also acquires "albums" and "artists"
    //NOTE that albums and artists are not true albums and artists, simply a single MPMediaItem representing the album or artist duplicate albums and artists are removed, as well as empty artists
    //isLibraryEmpty is called to make sure the user knows the app will crash when 0 songs are on the device
    //the number of synced songs is saved to realm
    func syncLibrary(){
        sortType.selectedSegmentIndex = 4 //song
        subSortType.selectedSegmentIndex = 0 //alphabetical
        musicQueue = MPMediaQuery.songsQuery().items!
        albumQueue = MPMediaQuery.albumsQuery().items!
        if albumQueue.count > 1{
            removeDuplicateAlbums(&albumQueue)
        }
        artistQueue = MPMediaQuery.artistsQuery().items!
        if artistQueue.count > 1{
            removeDuplicateArtists(&artistQueue)
            removeEmptyArtists(&artistQueue, albums: albumQueue)
        }
        print("album count: \(albumQueue.count)")
        print("initial artist count: \(artistQueue.count)")
        print("non empty artist count: \(artistQueue.count)")
        sortChanged = false
        reSort(&musicQueue)
        if isLibraryEmpty(){
            return
        }
        newSongCount = musicQueue.count - oldSongCount
        print("New songs synced: \(newSongCount)\nTotal songs synced: \(musicQueue.count)")
        oldSongCount+=newSongCount
        newSongCount = 0
        let realm = try! Realm()
        try! realm.write() {
            appData![0].value = oldSongCount
            appData![0].modificationTime = NSDate()
        }
    }
    
    //removes duplicate albums from an alphabetically sorted list of albums
    func removeDuplicateAlbums(inout values: [MPMediaItem]){
        var j = 1
        var h = 0
        for _ in 0...values.count-2{
            if values[h].albumPersistentID == values[h+1].albumPersistentID || values[h].albumTitle == values[h+1].albumTitle{
                //print("rem \(values[h].albumPersistentID) \(values[h].albumTitle) \(values[h+1].albumPersistentID) \(values[h+1].albumTitle)")
                values.removeAtIndex(h)
                j += 1
            }
            else{
                h += 1
            }
        }
    }
    
    //removes duplicate artists from an alphabetically sorted list of artists
    func removeDuplicateArtists(inout values: [MPMediaItem]){
        var h = 0
        for _ in 0...values.count-2{
            if values[h].artistPersistentID == values[h+1].artistPersistentID{
                values.removeAtIndex(h)
            }
            else{
                h += 1
            }
        }
    }
    
    //removes artists with 0 albums from a list of artists
    func removeEmptyArtists(inout artists: [MPMediaItem], albums: [MPMediaItem]){
        var removed = 0
        var i = 0
        for _ in 0...artists.count-1{
            var albumCount = 0
            for j in 0...albums.count-1{
                if albums[j].artist == artists[i].artist {
                    albumCount = 1
                    i += 1
                    break
                }
            }
            if albumCount == 0{
                artists.removeAtIndex(i)
                removed += 1
            }
        }
    }
    
    //re-populates table cell data
    func reloadTableInMainThread(){
        dispatch_async(dispatch_get_main_queue(), {() -> Void in
            self.itemTable.reloadData()
        })
    }
    
    //This function is assigned to a cell's cellTapped fucntion when the itemToDisplay is .song or .subSong
    //songTap takes the row of cell that was pressed (equivalent to the index of the item to be played in the queue) as a parameter and assigns it to currentCellIndex. The item is played by calling playItem()
    //The previous cell's font is unbolded, and the current cell's font is bolded to indicate that the song indexed by the cell is playing
    func songTap(row: Int) {
        print("song chosen")
        currentCellIndex = row
        playItem(currentCellIndex)
        if previousCellIndex != currentCellIndex{
            unBoldPrevItem(currentCellIndex)
        }
        oldPlayerItem = player.getNowPlayingIndex()
        if firstPlay == false{
            firstPlay = true
        }
        
        //////////////////////////////////////////////////////////////////////////////////////
        //NON-PERSISTENT RECENT SORTING (more accurate, not persistent between app launches)//
        //DO NOT DELETE                                                        DO NOT DELETE//
        //////////////////////////////////////////////////////////////////////////////////////
        
        /*if sortType.selectedSegmentIndex != 1 && sortType.selectedSegmentIndex != 4{
            if oldSubItem == oldSub.album{
                if recentAlbums.count > 1{
                    for i in 0...recentAlbums.count-1{
                        if i == recentAlbums.count{
                            break
                        }
                        if recentAlbums[i].albumPersistentID == albumQueue[oldSubRow].albumPersistentID{
                            recentAlbums.removeAtIndex(i)
                            print("dup rem")
                        }
                    }
                }
                recentAlbums.append(albumQueue[oldSubRow])
                print("album added to recent \(albumQueue[oldSubRow].albumTitle)")
            }
            else if oldSubItem == oldSub.subAlbum{
                if recentAlbums.count > 1{
                    for i in 0...recentAlbums.count-1{
                        if i == recentAlbums.count{
                            break
                        }
                        if recentAlbums[i].albumPersistentID == subAlbumQueue[oldSubRow].albumPersistentID{
                            recentAlbums.removeAtIndex(i)
                            print("dup rem")
                        }
                    }
                }
                recentAlbums.append(subAlbumQueue[oldSubRow])
                print("album added to recent \(subAlbumQueue[oldSubRow].albumTitle)")
            }
            if recentAlbums.count == 51{
                recentAlbums.removeFirst()
            }
            /*let realm = try! Realm()
            try! realm.write() {
                realmRecentAlbums![0].albumArray = recentAlbums
            }*/
        }*/
        
        /*if recentSongs.count > 1{
            for i in 0...recentSongs.count-1{
                if i >= recentSongs.count{
                    break
                }
                if recentSongs[i].persistentID == player.getNowPlayingItem()?.persistentID{
                    recentAlbums.removeAtIndex(i)
                    print("dup rem")
                }
            }
        }
        recentSongs.append(player.getNowPlayingItem()!)
        print("song added to recent \(player.getNowPlayingItem()!.title)")
        if recentSongs.count == 51{
            recentSongs.removeFirst()
        }*/
        
        /*let realm = try! Realm()
        try! realm.write() {
            realmRecentAlbums![0].songsArray = recentSongs
        }*/
    }
    
    //sliderChange handles track seeking while audio is playing
    @IBAction func sliderChange(sender: AnyObject) {
        let slider: UISlider = (sender as! UISlider)
        let setRatio = Double(slider.value)
        let setTime: NSTimeInterval = (player.getNowPlayingItem()?.playbackDuration)! * setRatio
        player.skipTo(setTime)
        print("player skipping to \(stringFromTimeInterval(setTime))")
    }
    
    //This function is assigned to a cell's cellTapped fucntion when the itemToDisplay is .album or .subAlbum
    //albumTap takes an indexPath as a parameter
    //The subMusicQueue is populated with songs that belong to the album that was tapped
    //The subMusicQueue is then sorted by track number
    //oldSubRow is used for non-persistent accurate recent sorting DO NOT DELETE
    //The table is repopulated according to itemToDisplay (now .subSong i.e. songs belonging to the album tapped)
    func albumTap(path: NSIndexPath){
        subMusicQueue.removeAll()
        subSortType.setEnabled(true, forSegmentAtIndex: 0)
        subSortType.setTitle("Back", forSegmentAtIndex: 0)
        subSortType.setEnabled(false, forSegmentAtIndex: 1)
        subSortType.setTitle("", forSegmentAtIndex: 1)
        subSortType.selectedSegmentIndex = -1
        sortType.selectedSegmentIndex = -1
        print("album chosen")
        if let cell = itemTable.cellForRowAtIndexPath(path) as! itemCell? {
            subMusicQueue = musicQueue.filter { (item) -> Bool in
                return item.albumTitle == cell.itemTitle.text
            }
        }
        print("sub-music count: \(subMusicQueue.count)")
        
        //TODO: sort by disc number then tracknumber
        subMusicQueue.sortInPlace{
            if $0.albumTrackNumber == 0 || $1.albumTrackNumber == 0{
                print("track number error in sorting")
                let alertController = UIAlertController(title: "modus", message:
                    "Some track number information could not be retrieved.", preferredStyle: UIAlertControllerStyle.Alert)
                alertController.addAction(UIAlertAction(title: "Dismiss", style: UIAlertActionStyle.Default,handler: nil))
                
                self.presentViewController(alertController, animated: true, completion: nil)
                
                return $0.albumTitle < $1.albumTitle
            }
            return $0.albumTrackNumber < $1.albumTrackNumber
        }
        oldSubRow = path.row //DO NOT DELETE
        itemToDisplay = itemType.subSong
        reloadTableInMainThread()
    }
    
    //This function is assigned to a cell's cellTapped fucntion when the itemToDisplay is .artist
    //artistTap takes an indexPath as a parameter
    //The subAlbumQueue is populated with albums that belong to the artist that was tapped
    //The subAlbumQueue is then sorted by release date
    //The table is repopulated according to itemToDisplay (now .subAlbum i.e. albums belonging to the artist tapped)
    func artistTap(path: NSIndexPath){
        oldSubItem = oldSub.subAlbum
        subAlbumQueue.removeAll()
        subSortType.setEnabled(true, forSegmentAtIndex: 0)
        subSortType.setTitle("Back", forSegmentAtIndex: 0)
        subSortType.setEnabled(false, forSegmentAtIndex: 1)
        subSortType.setTitle("", forSegmentAtIndex: 1)
        subSortType.selectedSegmentIndex = -1
        sortType.selectedSegmentIndex = -1
        print("arist chosen")
        if let cell = itemTable.cellForRowAtIndexPath(path) as! itemCell? {
            subAlbumQueue = albumQueue.filter { (item) -> Bool in
                return item.artist == cell.itemTitle.text
            }
        }
        print("sub-album count: \(subAlbumQueue.count)")
        subAlbumQueue.sortInPlace{
            if let releaseDate1 = $0.releaseDate , let releaseDate2 = $1.releaseDate{
                return releaseDate1.compare(releaseDate2) == NSComparisonResult.OrderedAscending
            }
            else if let yearNumber1: Int = ($0.valueForKey("year") as? Int)! , let yearNumber2: Int = ($1.valueForKey("year") as? Int)!{
                return yearNumber1 < yearNumber2
            }
            else{
                print("release date error in sorting")
                let alertController = UIAlertController(title: "modus", message:
                    "Some release date information could not be retrieved.", preferredStyle: UIAlertControllerStyle.Alert)
                alertController.addAction(UIAlertAction(title: "Dismiss", style: UIAlertActionStyle.Default,handler: nil))
                
                self.presentViewController(alertController, animated: true, completion: nil)
                
                return $0.albumTitle < $1.albumTitle
            }
        }
        itemToDisplay = itemType.subAlbum
        reloadTableInMainThread()
    }
    
    //A timer tracking a song's current playback time is stopped
    //If the sort type was changed and a song was tapped a new "queue" must be given to the system music player
    //The cell at indexPath's font is bolded to indicate it's status to the user (playing)
    //The mini-player's artwork, title, and info are set to the cell's artwork, title, info
    //The itemIndex (cell row) is passed to the system player (the item at index in the queue is set as the now playing item)
    //The mini-player's duration label is set and a timer to change the slider value is initialized
    //The player is started and the play buttion image is set to "pause.png"
    //The queue keeping track of previously played shuffled items is reset and if the current play order is shuffle,
    //the now playing song is appended
    func playItem(itemIndex: Int){
        timer?.invalidate()
        //check if new queue needed
        if sortChanged{
            if itemToDisplay == itemType.song{
                player.setQueue(musicQueue) //set player queue to resorted queue
            }
            else if itemToDisplay == itemType.subSong{
                player.setQueue(subMusicQueue) //set player queue to resorted queue
            }
            sortChanged = false
        }
        let indexpath = NSIndexPath(forRow: itemIndex, inSection: 0)
        if let cell = itemTable.cellForRowAtIndexPath(indexpath) as! itemCell? {
            cell.itemTitle.font = UIFont.boldSystemFontOfSize(17)
            cell.itemInfo.font = UIFont.boldSystemFontOfSize(17)
            cell.itemDuration.font = UIFont.boldSystemFontOfSize(15)
            playerArtwork.image = cell.artwork.image
            playerTitle.text = cell.itemTitle.text
            playerInfo.text = cell.itemInfo.text
        }
        player.setNowplayingItem(itemIndex)
        playerTotTime.text = stringFromTimeInterval((player.getNowPlayingItem()?.playbackDuration)!)
        timer = NSTimer.scheduledTimerWithTimeInterval(0.001, target: self, selector: #selector(musicLibraryController.audioProgress), userInfo: nil, repeats: true)
        player.play()
        if let image = UIImage(named: "pause.png") {
            playerPlayButton.setImage(image, forState: .Normal)
        }
        print("currently playing \(player.getNowPlayingItem()?.title)")
        shuffleQueue.removeAll()
        shuffleIndex = 1
        if orderToPlay == order.shuffle{
            shuffleQueue.append(currentCellIndex)
        }
    }
    
    //If the sortType segmentedIndex is changed the corresponding queue is resorted according to sort and subSort types
    @IBAction func changeSort(sender: AnyObject) {
        sortChanged = true
        subSortType.setEnabled(true, forSegmentAtIndex: 0)
        subSortType.setEnabled(true, forSegmentAtIndex: 1)
        subSortType.selectedSegmentIndex = 0
        let sort = sortType.selectedSegmentIndex
        if sort == 4{
            reSort(&musicQueue)
        }
        else if sort == 3{
            oldSubItem = oldSub.album //oldSubItem keeps track of where the "Back" button redirects to
            reSort(&albumQueue)
        }
        else if sort == 2{
            reSort(&artistQueue)
        }
        else if sort == 1{
            reSort(&subMusicQueue) //irrelevant parameter
        }
        else if sort == 0{
            
        }
    }
    
    //If the subSortType segmentedIndex is changed the corresponding queue is resorted according to sort and subSort types
    //If the subSortType is changed when none is selected that means the "Back Button" was pressed, and the previousTable sorting is reloaded
    @IBAction func changeSubSort(sender: AnyObject) {
        sortChanged = true
        subSortType.setEnabled(true, forSegmentAtIndex: 0)
        subSortType.setEnabled(true, forSegmentAtIndex: 1)
        let sort = sortType.selectedSegmentIndex
        if sort == 4{
            reSort(&musicQueue)
        }
        else if sort == 3{
            reSort(&albumQueue)
        }
        else if sort == 2{
            reSort(&artistQueue)
        }
        else if sort == 1{
            reSort(&subMusicQueue) //irrelevant parameter
        }
        else if sort == 0{
            
        }
        else if sort == -1{
            print("back pressed")
            previousTable()
        }
        else if sort == -2{
            print("cancel search")
            searchBar.text = ""
            oldSearchText = ""
            sortType.selectedSegmentIndex = preSearchSort
            subSortType.selectedSegmentIndex = preSearchSubSort
            backToSearch = true
            reSort(&artistQueue)
        }
    }
    
    //We have been using oldSubItem to keep track of where the user is and where they would want to go back to after viewing a sub-queue of songs or albums
    //Once back is pressed, the user wants to go back to the exact same sort arrangement they had prior to entering a sub-queue view
    func previousTable(){
        if oldSearchText != ""{
            searchBar.text = oldSearchText
            itemToDisplay = oldSearchDisp
            backToSearch = false
            searchBarSearchButtonClicked(searchBar)
            return
        }
        if itemToDisplay == itemType.subSong{ //current view displays songs, so we want to go back to displaying the albums
            switch oldSubItem{
            case .album: //album sorting
                print("back to alb")
                sortType.selectedSegmentIndex = 3
                subSortType.selectedSegmentIndex = oldAlbumSubSort
                reSort(&albumQueue)
            case .subAlbum: //a list of subAlbums from a specific artists (meaning we can use the same subAlbumQueue to display them)
                print("back to subAlb")
                subSortType.selectedSegmentIndex = -1
                itemToDisplay = itemType.subAlbum
                reloadTableInMainThread()
            case .recentAlb: //back to the list of recently played albums
                print("back to recAlb")
                sortType.selectedSegmentIndex = 1
                subSortType.selectedSegmentIndex = 1
                reSort(&subAlbumQueue)
            }
        }
        else if itemToDisplay == itemType.subAlbum{ //current view displays albums, so we want to go back to displaying the artists
            print("back to art")
            sortType.selectedSegmentIndex = 2
            subSortType.selectedSegmentIndex = 0
            reSort(&artistQueue)
        }
    }
    
    //Acquires recently played songs.
    //The last played date of a song is saved via the system music player WHEN A SONG COMPLETES
    //I have written code to replace this with a version that saves recently played songs to a queue when it starts but it is not persistent between app launches (see above)
    //getRecentSongs sorts the musicQueue by lastPlayedDate (newest first) and then assigns the first 50 songs to the subMusicQueue
    func getRecentSongs(){
        var error = false
        musicQueue.sortInPlace{
            if let playDate1 = $0.lastPlayedDate , let playDate2 = $1.lastPlayedDate{
                return playDate1.compare(playDate2) == NSComparisonResult.OrderedDescending
            }
            else if let _ = $0.lastPlayedDate{
                return true
            }
            else if  let _ = $1.lastPlayedDate{
                return false
            }
            else{
                error = true
                return NSDate.distantPast().compare(NSDate.distantPast()) == NSComparisonResult.OrderedDescending
            }
        }
        if error{
            print("recently played date error in getRecentSongs")
        }
        subMusicQueue.removeAll()
        if musicQueue.count > 50{
            for i in 0...49{
                subMusicQueue.append(musicQueue[i])
            }
        }
        else{
            for i in 0...musicQueue.count{
                subMusicQueue.append(musicQueue[i])
            }
        }
    }
    
    //getRecentAlbums assigns an album to the subAlbumQueue from the complete albumQueue for each song in the subMusicQueue after running getRecentSongs
    //in other words it gets the most recently played albums for the last 50 songs (i.e. <= 50 albums will be on this list)
    func getRecentAlbums(){
        getRecentSongs()
        subAlbumQueue.removeAll()
        var tempQ: [MPMediaItem] = []
        for song in subMusicQueue{
            tempQ = albumQueue.filter { (item) -> Bool in
                return item.albumPersistentID == song.albumPersistentID || item.albumTitle == song.albumTitle
            }
            if tempQ.count > 0{
                subAlbumQueue.append(tempQ[0])
            }
            else{
                print("GRA retrieval error")
            }
        }
        var seen: [MPMediaItem] = []
        var index = 0
        for element in subAlbumQueue {
            if seen.contains(element) {
                subAlbumQueue.removeAtIndex(index)
            } else {
                seen.append(element)
                index += 1
            }
        }

    }
    
    //reSort re-sorts an array based on the segmented indexes sortType and subSortType
    //the sortTypes are: Song, Album, Artist, Recent, Playlist
    //the subSortTypes vary depending on the sortType.selectedSegmentIndex
    //for sortType.selectedSegmentIndex == 1 [RECENT], we use getRecentTYPE() instead of sorting the query parameter because a different array is required for each subSortType
    func reSort(inout query: [MPMediaItem]){
        var error = false
        let sort = sortType.selectedSegmentIndex
        let subSort = subSortType.selectedSegmentIndex
        if sort == 4{ //song
            itemToDisplay = itemType.song
            subSortType.setTitle("Alphabetical", forSegmentAtIndex: 0)
            subSortType.setTitle("Playcount", forSegmentAtIndex: 1)
            if subSort == 0{
                query.sortInPlace{
                    return $0.title < $1.title
                }
                print("sort: song alpha")
            }
            else if subSort == 1{
                query.sortInPlace{
                    return $0.playCount > $1.playCount
                }
                print("sort: song playcount")
            }
            reloadTableInMainThread()
            return
        }
        else if sort == 3{ //album
            itemToDisplay = itemType.album
            subSortType.setTitle("Alphabetical", forSegmentAtIndex: 0)
            subSortType.setTitle("Artist/Date", forSegmentAtIndex: 1)
            if subSort == 0{
                query.sortInPlace{
                    return $0.albumTitle < $1.albumTitle
                }
                oldAlbumSubSort = 0
                print("sort: album alpha")
            }
            else if subSort == 1{
                query.sortInPlace{
                    if $0.artist == $1.artist{
                        if let releaseDate1 = $0.releaseDate , let releaseDate2 = $1.releaseDate{
                            return releaseDate1.compare(releaseDate2) == NSComparisonResult.OrderedAscending
                        }
                        else if let yearNumber1: Int = ($0.valueForKey("year") as? Int)! , let yearNumber2: Int = ($1.valueForKey("year") as? Int)!{
                            return yearNumber1 < yearNumber2
                        }
                        else{
                            error = true
                            return $0.albumTitle < $1.albumTitle
                        }
                    }
                    else{
                        return $0.artist < $1.artist
                    }
                }
                if error{
                    print("release date error in sorting")
                    let alertController = UIAlertController(title: "modus", message:
                        "Some release date information could not be retrieved.", preferredStyle: UIAlertControllerStyle.Alert)
                    alertController.addAction(UIAlertAction(title: "Dismiss", style: UIAlertActionStyle.Default,handler: nil))
                    
                    self.presentViewController(alertController, animated: true, completion: nil)
                }
                oldAlbumSubSort = 1
                print("sort: album artist")
            }
            reloadTableInMainThread()
            return
        }
        else if sort == 2{
            itemToDisplay = itemType.artist
            subSortType.setTitle("Alphabetical", forSegmentAtIndex: 0)
            subSortType.setTitle("Reversed", forSegmentAtIndex: 1)
            if subSort == 0{
                query.sortInPlace{
                    return $0.artist < $1.artist
                }
                print("sort: artist alpha")
            }
            else if subSort == 1{
                query.sortInPlace{
                    return $0.artist > $1.artist
                }
                print("sort: artist reverse")
            }
            reloadTableInMainThread()
            return
        }
        else if sort == 1{ //recent
            subSortType.setTitle("Songs", forSegmentAtIndex: 0)
            subSortType.setTitle("Albums", forSegmentAtIndex: 1)
            if subSort == 0{
                itemToDisplay = itemType.subSong
                getRecentSongs()
                //subMusicQueue = recentSongs.reverse()
                print("sort: recent songs")
            }
            else if subSort == 1{
                oldSubItem = oldSub.recentAlb
                itemToDisplay = itemType.subAlbum
                getRecentAlbums()
                //subAlbumQueue = recentAlbums.reverse()
                //getRecentSongs()
                //subMusicQueue = subMusicQueue.reverse()
                print("sort: recent albums")
            }
            reloadTableInMainThread()
            return
        }
        else if sort == 0{ //playlist NOT IMPLEMENTED
            itemToDisplay = itemType.song
            subSortType.setTitle("Recent", forSegmentAtIndex: 0)
            subSortType.setTitle("Playcount", forSegmentAtIndex: 1)
            if subSort == 0{
                
                print("sort: recent")
            }
            else if subSort == 1{
                
                print("sort: recent playcount")
            }
            reloadTableInMainThread()
            return

        }
        print("re-sort unknown")
        reloadTableInMainThread()
        return
    }
    
    //the "Sync Library" button action simply calls syncLibrary()
    @IBAction func syncLibButton(sender: AnyObject) {
        syncLibrary()
    }
    
    //This function uses the raw state of the player to decide whether to switch to a play or pause button, and correspondingly starts or pauses player playback
    @IBAction func playerPlayButton(sender: AnyObject) {
        if firstPlay == true{
            if player.getRawState() == 2{ //if paused
                print("play pressed")
                timer = NSTimer.scheduledTimerWithTimeInterval(0.001, target: self, selector: #selector(musicLibraryController.audioProgress), userInfo: nil, repeats: true)
                player.play()
                if let image = UIImage(named: "pause.png") {
                    playerPlayButton.setImage(image, forState: .Normal)
                }
                print("currently playing \(player.getNowPlayingItem()?.title)")
            }
            else if player.getRawState() == 1{ //if playing
                print("pause pressed")
                player.pause()
                if let image = UIImage(named: "play.png") {
                    playerPlayButton.setImage(image, forState: .Normal)
                }
                print("currently paused")
            }
            
        }
    }
    
    //This function is called by the externalInputCheckTimer periodically
    //When the system player's state is changed, either by the player in the lock-screen or on the toolbar, the UI updates accordingly
    //Similarly, when a song is changed by an external player, the UI updates accordingly
    func checkExternalButtonPress(){
        if firstPlay == true && oldPlayerState == player.getRawState(){
            if player.getRawState() == 2{ //if paused
                print("pause externally pressed")
                oldPlayerState = 1
                if let image = UIImage(named: "play.png") {
                    playerPlayButton.setImage(image, forState: .Normal)
                }
            }
            else if player.getRawState() == 1{ //if playing
                print("play externally pressed")
                oldPlayerState = 2
                if let image = UIImage(named: "pause.png") {
                    playerPlayButton.setImage(image, forState: .Normal)
                }
            }
        }
        if firstPlay == true && oldPlayerItem != player.getNowPlayingIndex(){
            print("song changed")
            unBoldPrevItem(oldPlayerItem!)
            boldCurrItem(player.getNowPlayingIndex()!)
            oldPlayerItem = player.getNowPlayingIndex()
            currentCellIndex = player.getNowPlayingIndex()!
            previousCellIndex = currentCellIndex
        }
        if firstPlay == false{
            player.pause()
        }
    }
    
    //When the user presses next, this function decides which song to play next, or whether or not it has reached the end of the queue and the player should pause
    //It also handles play order, i.e. if the play order is shuffle it finds a random song to play or continues down the shuffleQueue
    //If the play order is repeat it acts as normal (repeat order only comes into play when the song reaches the end of its duration)
    @IBAction func playerNextButton(sender: AnyObject) {
        timer!.invalidate()
        print("next pressed")
        if firstPlay == true && (currentCellIndex+1) != player.getQueueCount() && (orderToPlay == order.normal || orderToPlay == order.repeatItem){ //if a song is in the "slot"
            currentCellIndex += 1
            player.playNext()
            unBoldPrevItem(currentCellIndex)
            boldCurrItem(currentCellIndex)
            updateMiniPlayer()
        }
        else if firstPlay == true && orderToPlay == order.shuffle{
            if shuffleIndex == 1{
                currentCellIndex = Int(arc4random_uniform(UInt32(musicQueue.count-1)))
                player.setNowplayingItem(currentCellIndex)
                shuffleQueue.append(currentCellIndex)
                unBoldPrevItem(currentCellIndex)
                boldCurrItem(currentCellIndex)
                updateMiniPlayer()
            }
            else if shuffleIndex > 1{
                shuffleIndex -= 1
                currentCellIndex = shuffleQueue[shuffleQueue.count - shuffleIndex]
                player.setNowplayingItem(currentCellIndex)
                unBoldPrevItem(currentCellIndex)
                boldCurrItem(currentCellIndex)
                updateMiniPlayer()
            }
        }
        oldPlayerItem = player.getNowPlayingIndex()
        timer = NSTimer.scheduledTimerWithTimeInterval(0.001, target: self, selector: #selector(musicLibraryController.audioProgress), userInfo: nil, repeats: true)
        
        //////////////////////////////////////////////////////////////////////////////////////
        //NON-PERSISTENT RECENT SORTING (more accurate, not persistent between app launches)//
        //DO NOT DELETE                                                        DO NOT DELETE//
        //////////////////////////////////////////////////////////////////////////////////////
        
        /*if recentSongs.count > 1{
            for i in 0...recentSongs.count-1{
                if i == recentSongs.count{
                    break
                }
                if recentSongs[i].persistentID == player.getNowPlayingItem()?.persistentID{
                    recentAlbums.removeAtIndex(i)
                    print("dup rem")
                }
            }
        }
        recentSongs.append(player.getNowPlayingItem()!)
        print("song added to recent \(player.getNowPlayingItem()!.title)")
        if recentSongs.count == 51{
            recentSongs.removeFirst()
        }*/
    }
    
    //When the user presses previous, this function decides which song to play next, or whether or not it has reached the beginning of the queue and the player should repeat the first song
    //It also handles play order, i.e. if the play order is shuffle it goes to the previous song in the shuffleQueue
    //If the play order is repeat it acts as normal (repeat order only comes into play when the song reaches the end of its duration)
    //Additionally, if the currently playing song's playback time is above 4 seconds it goes back to the beginning of the song
    @IBAction func playerPrevButton(sender: AnyObject) {
        timer!.invalidate()
        print("prev pressed")
        if firstPlay == true && currentCellIndex != 0 && (orderToPlay == order.normal || orderToPlay == order.repeatItem){
            if player.getCurrentPlaybackTime() <= NSTimeInterval(4){
                currentCellIndex += -1
                player.playPrev()
                unBoldPrevItem(currentCellIndex)
                boldCurrItem(currentCellIndex)
                updateMiniPlayer()
            }
            else{
                player.skipToBeginning()
            }
        }
        else if firstPlay == true && orderToPlay == order.shuffle{
            if player.getCurrentPlaybackTime() <= NSTimeInterval(4) && shuffleQueue.count >= (shuffleIndex+1){
                currentCellIndex = shuffleQueue[shuffleQueue.count - shuffleIndex - 1]
                player.setNowplayingItem(currentCellIndex)
                unBoldPrevItem(currentCellIndex)
                boldCurrItem(currentCellIndex)
                updateMiniPlayer()
                shuffleIndex += 1
            }
            else{
                player.skipToBeginning()
            }
        }
        oldPlayerItem = player.getNowPlayingIndex()
        timer = NSTimer.scheduledTimerWithTimeInterval(0.001, target: self, selector: #selector(musicLibraryController.audioProgress), userInfo: nil, repeats: true)
        
        //////////////////////////////////////////////////////////////////////////////////////
        //NON-PERSISTENT RECENT SORTING (more accurate, not persistent between app launches)//
        //DO NOT DELETE                                                        DO NOT DELETE//
        //////////////////////////////////////////////////////////////////////////////////////
        
        /*if recentSongs.count > 1{
            for i in 0...recentSongs.count-1{
                if i == recentSongs.count{
                    break
                }
                if recentSongs[i].persistentID == player.getNowPlayingItem()?.persistentID{
                    recentAlbums.removeAtIndex(i)
                    print("dup rem")
                }
            }
        }
        recentSongs.append(player.getNowPlayingItem()!)
        print("song added to recent \(player.getNowPlayingItem()!.title)")
        if recentSongs.count == 51{
            recentSongs.removeFirst()
        }*/
    }
    
    //This function updates the mini-player with information from the now playing item
    func updateMiniPlayer(){
        let nowPlaying = player.getNowPlayingItem()!
        
        if let titleOfItem = nowPlaying.valueForProperty(MPMediaItemPropertyTitle) as? String {
            playerTitle.text = titleOfItem
        }
        
        if let artistInfo = nowPlaying.valueForProperty(MPMediaItemPropertyArtist) as? String {
            if let albumInfo = nowPlaying.valueForProperty(MPMediaItemPropertyAlbumTitle) as? String {
                playerInfo.text = "\(artistInfo) - \(albumInfo) - \(stringFromTimeInterval(nowPlaying.playbackDuration))"
            }
            else{
                playerInfo.text = "\(artistInfo) - \(stringFromTimeInterval(nowPlaying.playbackDuration))"
            }
        }
        else{
            print("Resync Necessary: A - A (mini)")
        }
        
        if let itemArtwork = nowPlaying.valueForProperty(MPMediaItemPropertyArtwork){
            playerArtwork.image = itemArtwork.imageWithSize(CGSizeMake(60.0, 60.0))
            //print("artwork extracted")
        }
        else{
            //default artwork
        }
        
        playerTotTime.text = stringFromTimeInterval(nowPlaying.playbackDuration)
    }
    
    //This function unbolds the cell text at row previousCellIndex, and sets previousCellIndex to the itemIndex (for the next time this function is called)
    func unBoldPrevItem(itemIndex: Int){
        let prevIndexPath = NSIndexPath(forRow: previousCellIndex, inSection: 0)
        if let prevCell = itemTable.cellForRowAtIndexPath(prevIndexPath) as! itemCell? {
            prevCell.itemTitle.font = UIFont.systemFontOfSize(17)
            prevCell.itemInfo.font = UIFont.systemFontOfSize(17)
            prevCell.itemDuration.font = UIFont.systemFontOfSize(15)
            previousCellIndex = itemIndex
        }
    }
    
    func boldCurrItem(itemIndex: Int){
        let currIndexPath = NSIndexPath(forRow: itemIndex, inSection: 0)
        if let currCell = itemTable.cellForRowAtIndexPath(currIndexPath) as! itemCell? {
            currCell.itemTitle.font = UIFont.boldSystemFontOfSize(17)
            currCell.itemInfo.font = UIFont.boldSystemFontOfSize(17)
            currCell.itemDuration.font = UIFont.boldSystemFontOfSize(15)
        }
    }

    
    //A simple converter from NSTimeInterval to a string format AB:YZ where AB is minutes and YZ is seconds
    func stringFromTimeInterval(interval0: NSTimeInterval) -> String {
        if interval0.isNaN{
            return ""
        }
        let interval = Int(interval0)
        let seconds = interval % 60
        let minutes = (interval / 60) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    //This function is called by timer every millisecond
    //It updates the current playback time by way of ratio (current time / total time) and sets that value on the slider
    //It also calls a function to change the currTime label on the miniplayer
    func audioProgress(){
        changeCurrTime()
        timeRatio = Float32(player.getCurrentPlaybackTime() / (player.getNowPlayingItem()?.playbackDuration)!)
        playerProgress.setValue(timeRatio, animated: true)
    }
    
    //This function handles changes to the currTime label on the miniplayer
    //It also makes sure trackshifting is handled correctly when currTime.text = totTime.text
    //Trackshifting plays the next song in the queue when in normal play order (or pauses if it is the last song in the queue)
    //If the order is shuffle it either continues down the shuffleQueue or finds a new random song
    //If the order is repeat it skips to the beginning of the current track
    //It then reinitializes timer
    func changeCurrTime(){
        playerCurrTime.text = stringFromTimeInterval(player.getCurrentPlaybackTime())
        if playerCurrTime.text == playerTotTime.text && firstPlay == true{
            print("trackshift")
            timer?.invalidate()
            switch orderToPlay{
            case .normal:
                if (currentCellIndex+1) != player.getQueueCount() { //if a song is in the "slot"
                    currentCellIndex += 1
                    player.playNext()
                    unBoldPrevItem(currentCellIndex)
                    updateMiniPlayer()
                }
                else{
                    player.pause()
                }
            case .shuffle:
                if shuffleIndex == 1{
                    currentCellIndex = Int(arc4random_uniform(UInt32(musicQueue.count-1)))
                    player.setNowplayingItem(currentCellIndex)
                    shuffleQueue.append(currentCellIndex)
                    unBoldPrevItem(currentCellIndex)
                    updateMiniPlayer()
                }
                else if shuffleIndex > 1{
                    shuffleIndex -= 1
                    currentCellIndex = shuffleQueue[shuffleQueue.count - shuffleIndex]
                    player.setNowplayingItem(currentCellIndex)
                    unBoldPrevItem(currentCellIndex)
                    updateMiniPlayer()
                }
            case .repeatItem:
                player.skipToBeginning()
            }
            timer = NSTimer.scheduledTimerWithTimeInterval(0.001, target: self, selector: #selector(musicLibraryController.audioProgress), userInfo: nil, repeats: true)
            oldPlayerItem = player.getNowPlayingIndex()
            
            //////////////////////////////////////////////////////////////////////////////////////
            //NON-PERSISTENT RECENT SORTING (more accurate, not persistent between app launches)//
            //DO NOT DELETE                                                        DO NOT DELETE//
            //////////////////////////////////////////////////////////////////////////////////////
            
            /*if recentSongs.count > 1{
                for i in 0...recentSongs.count-1{
                    if i == recentSongs.count{
                        break
                    }
                    if recentSongs[i].persistentID == player.getNowPlayingItem()?.persistentID{
                        recentAlbums.removeAtIndex(i)
                        print("dup rem")
                    }
                }
            }
            recentSongs.append(player.getNowPlayingItem()!)
            print("song added to recent \(player.getNowPlayingItem()!.title)")
            if recentSongs.count == 51{
                recentSongs.removeFirst()
            }*/
        }
    }
    
    //This function handles changes in the play order
    //It correctly sets the orderToPlay enumeration based on the current play order, and also sets the playOrder button image accordingly
    @IBAction func playOrderChanged(sender: AnyObject) {
        switch orderToPlay{
        case .normal:
            print("order changed to shuffle")
            orderToPlay = order.shuffle
            if let image = UIImage(named: "arrows-1.png") {
                playOrder.setImage(image, forState: .Normal)
            }
            shuffleQueue.append(currentCellIndex)
        case .shuffle:
            print("order changed to repeat")
            orderToPlay = order.repeatItem
            if let image = UIImage(named: "exchange-arrows.png") {
                playOrder.setImage(image, forState: .Normal)
            }
        case .repeatItem:
            print("order changed to normal")
            orderToPlay = order.normal
            if let image = UIImage(named: "arrows.png") {
                playOrder.setImage(image, forState: .Normal)
            }
        }
    }
    
    //This function handles unwinds from the TagEditor or FullPlayer
    @IBAction func unwindFromOtherScreen(segue: UIStoryboardSegue){
        
    }
}

//This extension handles changes in the itemTable
extension musicLibraryController: UITableViewDataSource {
    
    //Multiple sections not needed
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }
    
    //Returns number of cells needed based on the queue or subQueue
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch itemToDisplay {
        case .song:
            return musicQueue.count
        case .album:
            return albumQueue.count
        case .artist:
            return artistQueue.count
        case .subSong:
            return subMusicQueue.count
        case .subAlbum:
            return subAlbumQueue.count
        case .subArtist:
            return subArtistQueue.count
        }
    }
    
    //Populates the table using items in the queue
    //The queue accessed depends on what item needs to be displayed
    //The item to display in the current cell must correspond with the index of the queue
    //The cell's title, info, artwork, and item duration are all set accordingly
    //If the item is an album or artist the item duration is empty
    //If the item is a song or subSong AND the item is currently playing, its text is bolded (if not, it is normal)
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCellWithIdentifier("itemCell", forIndexPath: indexPath) as! itemCell
        let row = indexPath.row
        
        if itemToDisplay == itemType.song{ //song
            let item = musicQueue[row]
            if let titleOfItem = item.valueForProperty(MPMediaItemPropertyTitle) as? String {
                cell.itemTitle.text = titleOfItem
            }
            else{
                print("Resync Necessary: T")
            }
            cell.itemDuration.text = stringFromTimeInterval(item.playbackDuration)
            
            if let artistInfo = item.valueForProperty(MPMediaItemPropertyArtist) as? String {
                if let albumInfo = item.valueForProperty(MPMediaItemPropertyAlbumTitle) as? String {
                    cell.itemInfo.text = "\(artistInfo) - \(albumInfo)"
                }
                else{
                    cell.itemInfo.text = "\(artistInfo)"
                }
            }
            else{
                cell.itemInfo.text = "Artist Info Retrieval Error"
                print("Resync Necessary: A - A song")

            }
            
            if let itemArtwork = item.valueForProperty(MPMediaItemPropertyArtwork){
                cell.artwork.image = itemArtwork.imageWithSize(CGSizeMake(60.0, 60.0))
                //print("artwork extracted")
            }
            else{
                cell.artwork.image = UIImage(named: "defaultArtwork.png")!
            }
            
            if player.getNowPlayingItem()?.persistentID == item.persistentID && firstPlay == true{ //bold playing item on reSort
                cell.itemTitle.font = UIFont.boldSystemFontOfSize(17)
                cell.itemInfo.font = UIFont.boldSystemFontOfSize(17)
                cell.itemDuration.font = UIFont.boldSystemFontOfSize(15)
                playerTotTime.text = stringFromTimeInterval((player.getNowPlayingItem()?.playbackDuration)!)
                playerArtwork.image = cell.artwork.image
                playerTitle.text = cell.itemTitle.text
                playerInfo.text = cell.itemInfo.text
            }
            else{
                cell.itemTitle.font = UIFont.systemFontOfSize(17)
                cell.itemInfo.font = UIFont.systemFontOfSize(17)
                cell.itemDuration.font = UIFont.systemFontOfSize(15)
            }
        }
        else if itemToDisplay == itemType.album{ //album
            cell.itemTitle.font = UIFont.systemFontOfSize(17)
            cell.itemInfo.font = UIFont.systemFontOfSize(17)
            cell.itemDuration.font = UIFont.systemFontOfSize(15)
            let item = albumQueue[row]
            cell.itemDuration.text = ""
            if let titleOfItem = item.valueForProperty(MPMediaItemPropertyAlbumTitle) as? String {
                cell.itemTitle.text = titleOfItem
            }
            else{
                print("Resync Necessary: T")
            }
            
            if let artistInfo = item.valueForProperty(MPMediaItemPropertyAlbumArtist) as? String {
                if let yearNumber: Int = (item.valueForKey("year") as? Int)!{
                    if yearNumber != 0{
                    cell.itemInfo.text = "\(artistInfo) - \(yearNumber)"
                    }
                    else{
                        cell.itemInfo.text = "\(artistInfo)"
                    }
                }
                else{
                    cell.itemInfo.text = "\(artistInfo)"
                }
            }
            else{
                cell.itemInfo.text = "Artist Info Retrieval Error"
                print("Resync Necessary: A - A alb")

            }
            
            if let itemArtwork = item.valueForProperty(MPMediaItemPropertyArtwork){
                cell.artwork.image = itemArtwork.imageWithSize(CGSizeMake(60.0, 60.0))
                //print("artwork extracted")
            }
            else{
                cell.artwork.image = UIImage(named: "defaultArtwork.png")!
            }
        }
        else if itemToDisplay == itemType.artist{ //artist
            cell.itemTitle.font = UIFont.systemFontOfSize(17)
            cell.itemInfo.font = UIFont.systemFontOfSize(17)
            cell.itemDuration.font = UIFont.systemFontOfSize(15)
            let item = artistQueue[row]
            cell.itemDuration.text = ""
            if let titleOfItem = item.valueForProperty(MPMediaItemPropertyAlbumArtist) as? String {
                cell.itemTitle.text = titleOfItem
            }
            else{
                print("Resync Necessary: T")
            }
            
            var albumCount = 0
            var latestAlbumArtwork: UIImage = UIImage(named: "defaultArtwork.png")!
            var latestAlbumDate: NSDate = NSDate.distantPast()
            for i in 0...albumQueue.count-1{
                if albumQueue[i].artist == item.artist{
                    albumCount += 1
                    if let albumDate = albumQueue[i].releaseDate{
                        if albumDate.compare(latestAlbumDate) == NSComparisonResult.OrderedDescending{
                            latestAlbumDate = albumQueue[i].releaseDate!
                            if let itemArtwork = albumQueue[i].valueForProperty(MPMediaItemPropertyArtwork){
                                latestAlbumArtwork = itemArtwork.imageWithSize(CGSizeMake(60.0, 60.0))!
                            }
                        }
                    }
                    else{
                        if let itemArtwork = albumQueue[i].valueForProperty(MPMediaItemPropertyArtwork){
                            latestAlbumArtwork = itemArtwork.imageWithSize(CGSizeMake(60.0, 60.0))!
                        }
                    }
                }
            }
            cell.itemInfo.text = "Albums: \(albumCount)"
            cell.artwork.image = latestAlbumArtwork
        }
        else if itemToDisplay == itemType.subAlbum{ //sub album
            cell.itemTitle.font = UIFont.systemFontOfSize(17)
            cell.itemInfo.font = UIFont.systemFontOfSize(17)
            cell.itemDuration.font = UIFont.systemFontOfSize(15)
            let item = subAlbumQueue[row]
            cell.itemDuration.text = ""
            if let titleOfItem = item.valueForProperty(MPMediaItemPropertyAlbumTitle) as? String {
                cell.itemTitle.text = titleOfItem
            }
            else{
                print("Resync Necessary: T")
            }
            
            if let artistInfo = item.valueForProperty(MPMediaItemPropertyAlbumArtist) as? String {
                if let yearNumber: Int = (item.valueForKey("year") as? Int)!{
                    if yearNumber != 0{
                        cell.itemInfo.text = "\(artistInfo) - \(yearNumber)"
                    }
                    else{
                        cell.itemInfo.text = "\(artistInfo)"
                    }
                }
                else{
                    cell.itemInfo.text = "\(artistInfo)"
                }
            }
            else{
                cell.itemInfo.text = "Artist Info Retrieval Error"
                print("Resync Necessary: A - A subAlb")
            }
            
            if let itemArtwork = item.valueForProperty(MPMediaItemPropertyArtwork){
                cell.artwork.image = itemArtwork.imageWithSize(CGSizeMake(60.0, 60.0))
                //print("artwork extracted")
            }
            else{
                cell.artwork.image = UIImage(named: "defaultArtwork.png")!
            }
        }
        else if itemToDisplay == itemType.subSong{ //sub song
            let item = subMusicQueue[row]
            if let titleOfItem = item.valueForProperty(MPMediaItemPropertyTitle) as? String {
                cell.itemTitle.text = titleOfItem
            }
            else{
                print("Resync Necessary: T")
            }
            cell.itemDuration.text = stringFromTimeInterval(item.playbackDuration)
            
            if let artistInfo = item.valueForProperty(MPMediaItemPropertyArtist) as? String {
                if let albumInfo = item.valueForProperty(MPMediaItemPropertyAlbumTitle) as? String {
                    cell.itemInfo.text = "\(artistInfo) - \(albumInfo)"
                }
                else{
                    cell.itemInfo.text = "\(artistInfo)"
                }
            }
            else{
                cell.itemInfo.text = "Artist Info Retrieval Error"
                print("Resync Necessary: A - A subSong")

            }
            
            if let itemArtwork = item.valueForProperty(MPMediaItemPropertyArtwork){
                cell.artwork.image = itemArtwork.imageWithSize(CGSizeMake(60.0, 60.0))
                //print("artwork extracted")
            }
            else{
                cell.artwork.image = UIImage(named: "defaultArtwork.png")!
            }
            
            if player.getNowPlayingItem()?.persistentID == item.persistentID && firstPlay == true{ //bold playing item on reSort
                cell.itemTitle.font = UIFont.boldSystemFontOfSize(17)
                cell.itemInfo.font = UIFont.boldSystemFontOfSize(17)
                cell.itemDuration.font = UIFont.boldSystemFontOfSize(15)
                playerTotTime.text = stringFromTimeInterval((player.getNowPlayingItem()?.playbackDuration)!)
                playerArtwork.image = cell.artwork.image
                playerTitle.text = cell.itemTitle.text
                playerInfo.text = cell.itemInfo.text
            }
            else{
                cell.itemTitle.font = UIFont.systemFontOfSize(17)
                cell.itemInfo.font = UIFont.systemFontOfSize(17)
                cell.itemDuration.font = UIFont.systemFontOfSize(15)
            }
        }
        else if itemToDisplay == itemType.subArtist{
            cell.itemTitle.font = UIFont.systemFontOfSize(17)
            cell.itemInfo.font = UIFont.systemFontOfSize(17)
            cell.itemDuration.font = UIFont.systemFontOfSize(15)
            let item = subArtistQueue[row]
            cell.itemDuration.text = ""
            if let titleOfItem = item.valueForProperty(MPMediaItemPropertyAlbumArtist) as? String {
                cell.itemTitle.text = titleOfItem
            }
            else{
                print("Resync Necessary: T")
            }
            
            var albumCount = 0
            var latestAlbumArtwork: UIImage = UIImage(named: "defaultArtwork.png")!
            var latestAlbumDate: NSDate = NSDate.distantPast()
            for i in 0...albumQueue.count-1{
                if albumQueue[i].artist == item.artist{
                    albumCount += 1
                    if let albumDate = albumQueue[i].releaseDate{
                        if albumDate.compare(latestAlbumDate) == NSComparisonResult.OrderedDescending{
                            latestAlbumDate = albumQueue[i].releaseDate!
                            if let itemArtwork = albumQueue[i].valueForProperty(MPMediaItemPropertyArtwork){
                                latestAlbumArtwork = itemArtwork.imageWithSize(CGSizeMake(60.0, 60.0))!
                            }
                        }
                    }
                    else{
                        if let itemArtwork = albumQueue[i].valueForProperty(MPMediaItemPropertyArtwork){
                            latestAlbumArtwork = itemArtwork.imageWithSize(CGSizeMake(60.0, 60.0))!
                        }
                    }
                }
            }
            cell.itemInfo.text = "Albums: \(albumCount)"
            cell.artwork.image = latestAlbumArtwork
        }
        return cell
    }
}

//This extention calls specific functions when a cell is tapped
//The function called depends on the type of item being displayed in the cell
extension musicLibraryController: UITableViewDelegate {

    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        switch itemToDisplay {
        case .song:
            songTap(indexPath.row)
        case .album:
            albumTap(indexPath)
        case .artist:
            artistTap(indexPath)
        case .subSong:
            songTap(indexPath.row)
        case .subAlbum:
            albumTap(indexPath)
        case .subArtist:
            artistTap(indexPath)
        }
    }
}

//Handles searches
extension musicLibraryController: UISearchBarDelegate {

    //Speed up searching by invalidating external input timer
    func searchBarTextDidBeginEditing(searchBar: UISearchBar){
        externalInputCheckTimer!.invalidate()
        print("stopped timer")
    }
    
    //Reinitialize external input timer when finished searching
    func searchBarTextDidEndEditing(searchBar: UISearchBar){
        externalInputCheckTimer = NSTimer.scheduledTimerWithTimeInterval(0.001, target: self, selector: #selector(musicLibraryController.checkExternalButtonPress), userInfo: nil, repeats: true)
        print("timer reinitialized")
    }
    
    func searchBarSearchButtonClicked(searchBar: UISearchBar){
        if let searchTerm = searchBar.text{
            oldSearchText = searchTerm
            if backToSearch == true{
                preSearchSort = sortType.selectedSegmentIndex
                preSearchSubSort = subSortType.selectedSegmentIndex
            }
            subSortType.setEnabled(true, forSegmentAtIndex: 0)
            subSortType.setTitle("Cancel", forSegmentAtIndex: 0)
            subSortType.setEnabled(false, forSegmentAtIndex: 1)
            subSortType.setTitle("", forSegmentAtIndex: 1)
            subSortType.selectedSegmentIndex = -1
            sortType.selectedSegmentIndex = -2
            oldSearchDisp = itemToDisplay
            switch itemToDisplay{
            case .song:
                sortChanged = true
                print(".song search")
                subMusicQueue.removeAll()
                subMusicQueue = musicQueue.filter { (item) -> Bool in
                    if item.title!.lowercaseString.containsString(searchTerm.lowercaseString){
                        return item.title!.lowercaseString.containsString(searchTerm.lowercaseString)
                    }
                    else if item.albumTitle!.lowercaseString.containsString(searchTerm.lowercaseString){
                        return item.albumTitle!.lowercaseString.containsString(searchTerm.lowercaseString)
                    }
                    else if item.artist!.lowercaseString.containsString(searchTerm.lowercaseString){
                        return item.artist!.lowercaseString.containsString(searchTerm.lowercaseString)
                    }
                    else{
                        return false
                    }
                }
                itemToDisplay = itemType.subSong
            case .album:
                print(".album search")
                subAlbumQueue.removeAll()
                subAlbumQueue = albumQueue.filter { (item) -> Bool in
                    if item.albumTitle!.lowercaseString.containsString(searchTerm.lowercaseString){
                        return item.albumTitle!.lowercaseString.containsString(searchTerm.lowercaseString)
                    }
                    else if item.artist!.lowercaseString.containsString(searchTerm.lowercaseString){
                        return item.artist!.lowercaseString.containsString(searchTerm.lowercaseString)
                    }
                    else{
                        return false
                    }
                }
                itemToDisplay = itemType.subAlbum
            case .artist:
                print(".artist search")
                subArtistQueue.removeAll()
                subArtistQueue = artistQueue.filter { (item) -> Bool in
                    return item.artist!.lowercaseString.containsString(searchTerm.lowercaseString)
                }
                itemToDisplay = itemType.subArtist
            case .subSong:
                sortChanged = true
                print(".subSong search")
                subMusicQueue.removeAll()
                subMusicQueue = musicQueue.filter { (item) -> Bool in
                    if item.title!.lowercaseString.containsString(searchTerm.lowercaseString){
                        return item.title!.lowercaseString.containsString(searchTerm.lowercaseString)
                    }
                    else if item.albumTitle!.lowercaseString.containsString(searchTerm.lowercaseString){
                        return item.albumTitle!.lowercaseString.containsString(searchTerm.lowercaseString)
                    }
                    else if item.artist!.lowercaseString.containsString(searchTerm.lowercaseString){
                        return item.artist!.lowercaseString.containsString(searchTerm.lowercaseString)
                    }
                    else{
                        return false
                    }
                }
                itemToDisplay = itemType.subSong
            case .subAlbum:
                print(".subAlbum search")
                subAlbumQueue.removeAll()
                subAlbumQueue = albumQueue.filter { (item) -> Bool in
                    if item.albumTitle!.lowercaseString.containsString(searchTerm.lowercaseString){
                        return item.albumTitle!.lowercaseString.containsString(searchTerm.lowercaseString)
                    }
                    else if item.artist!.lowercaseString.containsString(searchTerm.lowercaseString){
                        return item.artist!.lowercaseString.containsString(searchTerm.lowercaseString)
                    }
                    else{
                        return false
                    }
                }
                itemToDisplay = itemType.subAlbum
            case .subArtist:
                print(".subArtist search")
                subArtistQueue.removeAll()
                subArtistQueue = artistQueue.filter { (item) -> Bool in
                    return item.artist!.lowercaseString.containsString(searchTerm.lowercaseString)
                }
                itemToDisplay = itemType.subArtist
            }
            reloadTableInMainThread()
        }
        self.view.endEditing(true)
    }
}