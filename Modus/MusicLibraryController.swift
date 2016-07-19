//
//  ViewController.swift
//  Modus
//
//  Created by Zain on 2016-06-27.
//  Copyright © 2016 Modus Applications. All rights reserved.
//

import Foundation
import UIKit
import RealmSwift
import MediaPlayer

class musicLibraryController: UIViewController{
    
    private var timer: NSTimer?
    private var timeRatio: Float = 0.00
    private var externalInputCheckTimer: NSTimer?
    private var player = Player()
    private var musicQueue: [MPMediaItem] = []
    private var albumQueue: [MPMediaItem] = []
    private var artistQueue: [MPMediaItem] = []
    
    private var newSongCount = 0 //don't save to Realm
    private var oldSongCount = 0 //save to Realm on each sync

    private var oldPlayerState = 1 //starts paused
    private var oldPlayerItem: MPMediaEntityPersistentID?
    private var previousCellIndex = 0
    private var currentCellIndex = 0
    
    private var firstPlay = false
    
    
    private let realm = try! Realm()
    private var appData: Results<AppData>?
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
    }
    private var orderToPlay = order.normal
    private var itemToDisplay = itemType.song
    
    @IBOutlet weak private var itemTable: UITableView!
    
    @IBOutlet weak private var sortType: UISegmentedControl!
    @IBOutlet weak private var subSortType: UISegmentedControl!
    
    @IBOutlet weak private var playerArtwork: UIImageView!
    @IBOutlet weak private var playerTitle: UILabel!
    @IBOutlet weak private var playerInfo: UILabel!
    @IBOutlet weak private var playerPlayButton: UIButton!
    @IBOutlet weak private var playerCurrTime: UILabel!
    @IBOutlet weak private var playerTotTime: UILabel!
    @IBOutlet weak private var playerProgress: UIProgressView!
    @IBOutlet weak var playOrder: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        retreiveData()
        syncLibrary()
        if musicQueue.isEmpty{
            return
        }
        setupPlayer()
        reloadTableInMainThread()
    }
    
    func retreiveData(){
        appData = realm.objects(AppData) //retrieve app data
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
                    "It seems you are new to modus! Welcome.\nCurrently, the tag editor is under maintenance.\nSwipe up on the mini player in the library to access the full player, and then click the artwork to show lyrics. Swipe artwork down to go back to the library.", preferredStyle: UIAlertControllerStyle.Alert)
                alertController.addAction(UIAlertAction(title: "Dismiss", style: UIAlertActionStyle.Default,handler: nil))
                
                self.presentViewController(alertController, animated: true, completion: nil)
            }
            else{
                oldSongCount = data[0].value //retrieve old
                print("app data retrieved... OSC = \(oldSongCount)")
            }
        }
    }
    
    func setupPlayer(){
        player.setQueue(musicQueue)
        externalInputCheckTimer = NSTimer.scheduledTimerWithTimeInterval(0.001, target: self, selector: #selector(musicLibraryController.checkExternalButtonPress), userInfo: nil, repeats: true) //60FPS bois
        itemTable.separatorStyle = UITableViewCellSeparatorStyle.SingleLineEtched
    }
    
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
    
    func syncLibrary(){
        sortType.selectedSegmentIndex = 4
        subSortType.selectedSegmentIndex = 0
        musicQueue = MPMediaQuery.songsQuery().items!
        albumQueue = MPMediaQuery.albumsQuery().items!
        removeDuplicateAlbums(&albumQueue)
        print("album count: \(albumQueue.count)")
        artistQueue = MPMediaQuery.artistsQuery().items!
        removeDuplicateArtists(&artistQueue)
        print("artist count: \(artistQueue.count)")
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
    
    func removeDuplicateAlbums(inout values: [MPMediaItem]){
        var j = 1
        var h = 0
        for _ in 0...values.count-2{
            if values[h].albumPersistentID == values[h+1].albumPersistentID{
                values.removeAtIndex(h)
                j += 1
            }
            else{
                h += 1
            }
        }
    }
    
    func removeDuplicateArtists(inout values: [MPMediaItem]){
        var j = 1
        var h = 0
        for _ in 0...values.count-2{
            if values[h].artistPersistentID == values[h+1].artistPersistentID{
                values.removeAtIndex(h)
                j += 1
            }
            else{
                h += 1
            }
        }
    }
    
    func reloadTableInMainThread(){
        dispatch_async(dispatch_get_main_queue(), {() -> Void in
            self.itemTable.reloadData()
        })
    }
    
    func songTap(sender: AnyObject) {
        print("song chosen")
        currentCellIndex = sender.view.tag
        playItem(currentCellIndex)
        if previousCellIndex != currentCellIndex{
            unBoldPrevItem(currentCellIndex)
        }
        if firstPlay == false{
            oldPlayerItem = player.getNowPlayingItem()?.persistentID
            firstPlay = true
        }
    }
    
    func albumTap(sender: AnyObject){
        print("album chosen")
        
    }
    
    func artistTap(sender: AnyObject){
        print("arist chosen")
        
    }
    
    func playItem(itemIndex: Int){
        timer?.invalidate()
        //check if new queue needed
        if sortChanged{
            player.setQueue(musicQueue) //set player queue to resorted queue
            sortChanged = false
        }
        player.setNowplayingItem(itemIndex)
        playerTotTime.text = stringFromTimeInterval((player.getNowPlayingItem()?.playbackDuration)!)
        timer = NSTimer.scheduledTimerWithTimeInterval(0.001, target: self, selector: #selector(musicLibraryController.audioProgress), userInfo: nil, repeats: true) //60FPS bois
        player.play()
        if let image = UIImage(named: "pause.png") {
            playerPlayButton.setImage(image, forState: .Normal)
        }
        print("currently playing \(player.getNowPlayingItem()?.title)")
        let indexpath = NSIndexPath(forRow: itemIndex, inSection: 0)
        if let cell = itemTable.cellForRowAtIndexPath(indexpath) as! itemCell? {
            cell.itemTitle.font = UIFont.boldSystemFontOfSize(17)
            cell.itemInfo.font = UIFont.boldSystemFontOfSize(17)
            cell.itemDuration.font = UIFont.boldSystemFontOfSize(15)
            playerArtwork.image = cell.artwork.image
            playerTitle.text = cell.itemTitle.text
            playerInfo.text = cell.itemInfo.text
        }
    }
    
    @IBAction func changeSort(sender: AnyObject) {
        sortChanged = true
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
            
        }
        else if sort == 0{
            
        }
    }
    
    @IBAction func changeSubSort(sender: AnyObject) {
        sortChanged = true
        let subSort = subSortType.selectedSegmentIndex
        if subSort == 4{
            reSort(&musicQueue)
        }
        else if subSort == 3{
            reSort(&albumQueue)
        }
        else if subSort == 2{
            reSort(&artistQueue)
        }
        else if subSort == 1{
            
        }
        else if subSort == 0{
            
        }
    }

    func reSort(inout query: [MPMediaItem]){
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
        if sort == 3{ //album
            itemToDisplay = itemType.album
            subSortType.setTitle("Alphabetical", forSegmentAtIndex: 0)
            subSortType.setTitle("Artist/Date", forSegmentAtIndex: 1)
            if subSort == 0{
                query.sortInPlace{
                    return $0.albumTitle < $1.albumTitle
                }
                print("sort: album alpha")
            }
            else if subSort == 1{
                query.sortInPlace{
                    if $0.artist == $1.artist{
                        return $0.releaseDate!.compare($1.releaseDate!) == NSComparisonResult.OrderedAscending
                    }
                    else{
                        return $0.artist < $1.artist
                    }
                }
                print("sort: album artist")
            }
            reloadTableInMainThread()
            return
        }
        if sort == 2{
            itemToDisplay = itemType.artist
            subSortType.setTitle("Alphabetical", forSegmentAtIndex: 0)
            subSortType.setTitle("Reverse Alpha", forSegmentAtIndex: 1)
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
        if sort == 1{ //recent NOT DONE
            itemToDisplay = itemType.song
            query = MPMediaQuery.songsQuery().items!
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
        if sort == 0{ //playlist NOT DONE
            itemToDisplay = itemType.song
            query = MPMediaQuery.songsQuery().items!
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
    }
    
    @IBAction func syncLibButton(sender: AnyObject) {
        syncLibrary()
    }
    
    @IBAction func playerPlayButton(sender: AnyObject) {
        if firstPlay == true{
            if player.getRawState() == 2{ //if paused
                print("play pressed")
                timer = NSTimer.scheduledTimerWithTimeInterval(0.001, target: self, selector: #selector(musicLibraryController.audioProgress), userInfo: nil, repeats: true) //60FPS bois
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
        if firstPlay == true && oldPlayerItem != player.getNowPlayingItem()?.persistentID{
            print("change externally pressed")
            oldPlayerItem = player.getNowPlayingItem()?.persistentID
            reloadTableInMainThread()
        }
        if firstPlay == false{
            player.pause()
        }
    }
    
    
    @IBAction func playerNextButton(sender: AnyObject) {
        print("next pressed")
        if firstPlay == true && (currentCellIndex+1) != player.getQueueCount() && orderToPlay == order.normal{ //if a song is in the "slot"
            currentCellIndex += 1
            player.playNext()
            unBoldPrevItem(currentCellIndex)
            updateMiniPlayer()
        }
        else if firstPlay == true && orderToPlay == order.shuffle{ //NOT IMPLEMENTED
            currentCellIndex += 1
            player.playNext()
            unBoldPrevItem(currentCellIndex)
            updateMiniPlayer()
        }
        
    }
    
    @IBAction func playerPrevButton(sender: AnyObject) {
        print("prev pressed")
        if firstPlay == true && currentCellIndex != 0 && orderToPlay == order.normal{
            if player.getCurrentPlaybackTime() <= NSTimeInterval(4){
                currentCellIndex += -1
                player.playPrev()
                unBoldPrevItem(currentCellIndex)
                updateMiniPlayer()
            }
            else{
                player.skipToBeginning()
            }
        }
        else if firstPlay == true && orderToPlay == order.shuffle{ //NOT IMPLEMENTED
            if player.getCurrentPlaybackTime() <= NSTimeInterval(4){
                currentCellIndex += -1
                player.playPrev()
                unBoldPrevItem(currentCellIndex)
                updateMiniPlayer()
            }
            else{
                player.skipToBeginning()
            }
        }
    }
    
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
            print("Resync Necessary: A - A")
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
    
    func unBoldPrevItem(itemIndex: Int){
        let prevIndexPath = NSIndexPath(forRow: previousCellIndex, inSection: 0)
        if let prevCell = itemTable.cellForRowAtIndexPath(prevIndexPath) as! itemCell? {
            prevCell.itemTitle.font = UIFont.systemFontOfSize(17)
            prevCell.itemInfo.font = UIFont.systemFontOfSize(17)
            prevCell.itemDuration.font = UIFont.systemFontOfSize(15)
            previousCellIndex = itemIndex
        }
    }
    
    func stringFromTimeInterval(interval: NSTimeInterval) -> String {
        let interval = Int(interval)
        let seconds = interval % 60
        let minutes = (interval / 60) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    func audioProgress(){
        changeCurrTime()
        timeRatio = Float(player.getCurrentPlaybackTime() / (player.getNowPlayingItem()?.playbackDuration)!)
        playerProgress.setProgress(timeRatio, animated: true)
    }
    
    func changeCurrTime(){
        playerCurrTime.text = stringFromTimeInterval(player.getCurrentPlaybackTime())
        if playerCurrTime.text == playerTotTime.text{
            print("trackshift")
            timer?.invalidate()
            if firstPlay == true && (currentCellIndex+1) != player.getQueueCount() && orderToPlay == order.normal{ //if a song is in the "slot"
                currentCellIndex += 1
                player.playNext()
                unBoldPrevItem(currentCellIndex)
                updateMiniPlayer()
            }
            else if firstPlay == true && orderToPlay == order.repeatItem{
                player.skipToBeginning()
            }
            else if firstPlay == true && orderToPlay == order.shuffle{ //NOT IMPLEMENTED
                currentCellIndex += 1
                player.playNext()
                unBoldPrevItem(currentCellIndex)
                updateMiniPlayer()
            }
            else{
                player.pause()
                //move to next album or next artist
            }
            timer = NSTimer.scheduledTimerWithTimeInterval(0.001, target: self, selector: #selector(musicLibraryController.audioProgress), userInfo: nil, repeats: true) //60FPS bois
        }
    }
    
    @IBAction func playOrderChanged(sender: AnyObject) {
        if orderToPlay == order.normal{ //normal
            print("order changed to shuffle")
            orderToPlay = order.shuffle
            if let image = UIImage(named: "arrows-1.png") {
                playOrder.setImage(image, forState: .Normal)
            }
        }
        else if orderToPlay == order.shuffle{ //shuffle
            print("order changed to repeat")
            orderToPlay = order.repeatItem
            if let image = UIImage(named: "exchange-arrows.png") {
                playOrder.setImage(image, forState: .Normal)
            }
        }
        else if orderToPlay == order.repeatItem{ //repeat
            print("order changed to normal")
            orderToPlay = order.normal
            if let image = UIImage(named: "arrows.png") {
                playOrder.setImage(image, forState: .Normal)
            }
        }
    }
    
    @IBAction func unwindFromOtherScreen(segue: UIStoryboardSegue){
        
    }
}

extension musicLibraryController: UITableViewDataSource {
    
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if itemToDisplay == itemType.song{
            return musicQueue.count
        }
        else if itemToDisplay == itemType.album{
            return albumQueue.count
        }
        else{
            return artistQueue.count
        }
    }
    
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
                print("Resync Necessary: A - A")
            }
            
            if let itemArtwork = item.valueForProperty(MPMediaItemPropertyArtwork){
                cell.artwork.image = itemArtwork.imageWithSize(CGSizeMake(60.0, 60.0))
                //print("artwork extracted")
            }
            else{
                cell.artwork.image = UIImage(named: "defaultArtwork.png")!
            }
            
            cell.tag = indexPath.row
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(musicLibraryController.songTap(_:)))
            cell.addGestureRecognizer(tapGesture)
            
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
            let item = albumQueue[row]
            cell.itemDuration.text = ""
            if let titleOfItem = item.valueForProperty(MPMediaItemPropertyAlbumTitle) as? String {
                cell.itemTitle.text = titleOfItem
            }
            else{
                print("Resync Necessary: T")
            }
            
            if let artistInfo = item.valueForProperty(MPMediaItemPropertyArtist) as? String {
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
                print("Resync Necessary: A - A")
            }
            
            if let itemArtwork = item.valueForProperty(MPMediaItemPropertyArtwork){
                cell.artwork.image = itemArtwork.imageWithSize(CGSizeMake(60.0, 60.0))
                //print("artwork extracted")
            }
            else{
                cell.artwork.image = UIImage(named: "defaultArtwork.png")!
            }

            cell.tag = indexPath.row
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(musicLibraryController.albumTap(_:)))
            cell.addGestureRecognizer(tapGesture)
        }
        else if itemToDisplay == itemType.artist{ //artist
            let item = artistQueue[row]
            cell.itemDuration.text = ""
            if let titleOfItem = item.valueForProperty(MPMediaItemPropertyArtist) as? String {
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
            
            /*if let itemArtwork = item.valueForProperty(MPMediaItemPropertyArtwork){ //artist artwork
                cell.artwork.image = itemArtwork.imageWithSize(CGSizeMake(60.0, 60.0))
                //print("artwork extracted")
            }
            else{
                //default artwork
            }*/

            cell.tag = indexPath.row
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(musicLibraryController.artistTap(_:)))
            cell.addGestureRecognizer(tapGesture)
        }
        
        return cell
    }
}

extension musicLibraryController: UITableViewDelegate {
    
}