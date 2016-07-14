//
//  ViewController.swift
//  Modus
//
//  Created by Zain on 2016-06-27.
//  Copyright © 2016 Modus Applications. All rights reserved.
//

/*
 TODO
 print songs in table sorted by track
 play songs with button
 pause, next, prev, progress bar, retreive time
 sort by album, artist, genre, playlist, songs: recently played, play count, sort by release date
 tag editor
 import tags
 full music player
 volume control
 search (see makestagram part 2)
 cache collections and table data for switching views
 cancel search
 */
/*  TODO
 gather all songs
 sort by artist
 sort by album
 sort by song
 extract artwork, time
 place in table
 
 FORNOW
 gather all songs
 sort however (currently sorts alphabetically)
 extract artwork
 place in table
 */

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
    private var orderToPlay = order.normal
    
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
                    "It seems you are new to modus! Welcome.\nCurrently, the tag editor is under maintenance.\nHowever, feel free to use modus as your next great music player!\n Swipe up on the mini player in the library to access the full player, and then click the artwork to show lyrics. Swipe artwork down to go back to the library.", preferredStyle: UIAlertControllerStyle.Alert)
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
        reSort(&musicQueue)
        if musicQueue.isEmpty{
            let alertController = UIAlertController(title: "modus", message:
                "No items found.\nMake sure there are music files on the device, then reload the app.", preferredStyle: UIAlertControllerStyle.Alert)
            alertController.addAction(UIAlertAction(title: "Dismiss", style: UIAlertActionStyle.Default,handler: nil))
            
            self.presentViewController(alertController, animated: true, completion: nil)
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
    
    func reloadTableInMainThread(){
        dispatch_async(dispatch_get_main_queue(), {() -> Void in
            self.itemTable.reloadData()
        })
    }
    
    func cellTap(sender: AnyObject) {
        print("cell pressed")
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
        reSort(&musicQueue)
    }
    
    @IBAction func changeSubSort(sender: AnyObject) {
        reSort(&musicQueue)
    }

    func reSort(inout query: [MPMediaItem]){
        sortChanged = true
        let sort = sortType.selectedSegmentIndex
        let subSort = subSortType.selectedSegmentIndex
        if sort == 4{
            if subSort == 0{
                query.sortInPlace{
                    return $0.title < $1.title
                }
                print("sort: song alpha")
                reloadTableInMainThread()
                return
            }
            else if subSort == 1{
                query.sortInPlace{
                    return $0.playCount > $1.playCount
                }
                print("sort: song playcount")
                reloadTableInMainThread()
                return
            }
        }
        print("re-sort unknown")
        reloadTableInMainThread()
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
        else if firstPlay == true && orderToPlay == order.repeatItem{
            player.skipToBeginning()
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
        else if firstPlay == true && orderToPlay == order.repeatItem{
            player.skipToBeginning()
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
        print("order changed")
        if playOrder.imageView!.image == UIImage(named: "arrows.png"){ //normal
            print("to shuffle")
            orderToPlay = order.shuffle
            if let image = UIImage(named: "arrows-1.png") {
                playOrder.setImage(image, forState: .Normal)
            }
        }
        else if playOrder.imageView!.image == UIImage(named: "arrows-1.png"){ //shuffle
            print("to repeat")
            orderToPlay = order.repeatItem
            if let image = UIImage(named: "exchange-arrows.png") {
                playOrder.setImage(image, forState: .Normal)
            }
        }
        else if playOrder.imageView!.image == UIImage(named: "exchange-arrows.png"){ //repeat
            print("to normal")
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
        return musicQueue.count
    }
    
    // 2
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCellWithIdentifier("itemCell", forIndexPath: indexPath) as! itemCell
        
        // 1
        let row = indexPath.row
        
        // 2
        let item = musicQueue[row]
        
        // 3
  
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
            //default artwork
        }

        cell.tag = indexPath.row
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(musicLibraryController.cellTap(_:)))
        
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
        
        return cell
    }
}

extension musicLibraryController: UITableViewDelegate {
    
}