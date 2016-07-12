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
import MediaPlayer
import RealmSwift

class musicLibraryController: UIViewController{
    
    var mediaItems: [MPMediaItem] = []
    
    var newSongCount = 0 //don't save to Realm
    var oldSongCount = 0 //save to Realm on each sync

    let player = MPMusicPlayerController.systemMusicPlayer()
    var previousItem = 0
    var currentItem = 0
    var firstPlay = false
    var itemCollection: MPMediaItemCollection = MPMediaItemCollection(items: [])
    let realm = try! Realm()
    var appData: Results<AppData>?
    
    @IBOutlet weak var itemTable: UITableView!
    
    @IBOutlet weak var sortType: UISegmentedControl!
    @IBOutlet weak var subSortType: UISegmentedControl!
    
    @IBOutlet weak var playerArtwork: UIImageView!
    @IBOutlet weak var playerTitle: UILabel!
    @IBOutlet weak var playerInfo: UILabel!
    @IBOutlet weak var playerPlayButton: UIButton!
    @IBOutlet weak var playerCurrTime: UILabel! //not done
    @IBOutlet weak var playerTotTime: UILabel!
    @IBOutlet weak var playerProgress: UIProgressView! //not done
    
    override func viewDidLoad() {
        super.viewDidLoad()
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

            }
            else{
                oldSongCount = data[0].value //retrieve old
                print("app data retrieved... OSC = \(oldSongCount)")
            }
            
        }
        player.pause()
        player.nowPlayingItem = nil
        syncLibrary()
        itemTable.separatorStyle = UITableViewCellSeparatorStyle.SingleLineEtched
    }
    
    @IBAction func syncLibButton(sender: AnyObject) {
        syncLibrary()
    }
    
    //add action for sort change, syncLibrary()
    
    func cellTap(sender: AnyObject) {
        print("cell pressed")
        currentItem = sender.view.tag
        let itemIndex = playItem(currentItem)
        
        let prevIndexPath = NSIndexPath(forRow: previousItem, inSection: 0)
        if previousItem != itemIndex{
            if let prevCell = itemTable.cellForRowAtIndexPath(prevIndexPath) as! itemCell? {
                prevCell.itemTitle.font = UIFont.systemFontOfSize(17)
                prevCell.itemInfo.font = UIFont.systemFontOfSize(17)
                previousItem = itemIndex
            }
        }
        if firstPlay == false{
            firstPlay = true
        }
    }
    
    @IBAction func playerPlayButton(sender: AnyObject) {
        if firstPlay == true{
            if player.playbackState.rawValue == 2{ //if paused
                print("play pressed")
                player.prepareToPlay()
                player.play()
                if let image = UIImage(named: "pause.png") {
                    playerPlayButton.setImage(image, forState: .Normal)
                }
                print("currently playing \(player.nowPlayingItem?.title)")
            }
            else if player.playbackState.rawValue == 1{ //if playing
                print("pause pressed")
                player.pause()
                if let image = UIImage(named: "play.png") {
                    playerPlayButton.setImage(image, forState: .Normal)
                }
                print("currently paused")
            }

        }
    }
    
    @IBAction func playerNextButton(sender: AnyObject) {
        print("next pressed")
        if firstPlay == true && (currentItem+1) != itemCollection.items.count{ //if a song is in the "slot"
            currentItem += 1
            let itemIndex = playItem(currentItem)
            let prevIndexPath = NSIndexPath(forRow: previousItem, inSection: 0)
            if let prevCell = itemTable.cellForRowAtIndexPath(prevIndexPath) as! itemCell? { //sometimes unbolding fucks up
                prevCell.itemTitle.font = UIFont.systemFontOfSize(17)
                prevCell.itemInfo.font = UIFont.systemFontOfSize(17)
                previousItem = itemIndex
            }


        }
    }
    
    @IBAction func playerPrevButton(sender: AnyObject) {
        print("prev pressed")
        if firstPlay == true && currentItem != 0{
            currentItem += -1
            let itemIndex = playItem(currentItem)
            let prevIndexPath = NSIndexPath(forRow: previousItem, inSection: 0)
            if let prevCell = itemTable.cellForRowAtIndexPath(prevIndexPath) as! itemCell? {
                prevCell.itemTitle.font = UIFont.systemFontOfSize(17)
                prevCell.itemInfo.font = UIFont.systemFontOfSize(17)
                previousItem = itemIndex
            }
        }
    }
    
    func playItem(current: Int) -> Int{
        let itemIndex = current
        itemCollection = MPMediaItemCollection(items: mediaItems)
        
        player.setQueueWithItemCollection(itemCollection)
        player.nowPlayingItem = itemCollection.items[itemIndex]
        playerTotTime.text = stringFromTimeInterval(itemCollection.items[itemIndex].playbackDuration)
        player.prepareToPlay()
        //
        player.play()
        if let image = UIImage(named: "pause.png") {
            playerPlayButton.setImage(image, forState: .Normal)
        }
        print("currently playing \(player.nowPlayingItem?.title)")
        
        let indexpath = NSIndexPath(forRow: itemIndex, inSection: 0)
        if let cell = itemTable.cellForRowAtIndexPath(indexpath) as! itemCell? {
            cell.itemTitle.font = UIFont.boldSystemFontOfSize(17)
            cell.itemInfo.font = UIFont.boldSystemFontOfSize(17)
            playerArtwork.image = cell.artwork.image
            playerTitle.text = cell.itemTitle.text
            playerInfo.text = cell.itemInfo.text
            
        }
        
        return itemIndex

    }
    
    func stringFromTimeInterval(interval: NSTimeInterval) -> String {
        let interval = Int(interval)
        let seconds = interval % 60
        let minutes = (interval / 60) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    func audioProgress(state: Int){ //closure?
        var playRatio = 0.0
        if state == 0{ //playing
            while (playRatio <= 1){
                playerProgress.progress = Float(playRatio)
                playRatio = player.currentPlaybackTime / (player.nowPlayingItem?.playbackDuration)!
            }
        }
        if state == 1{ //pause
            
        }
        if state == 2{ //switch
            
        }
    }
    
    func syncLibrary(){
        mediaItems.removeAll()
        mediaItems = sortItems()
        newSongCount = mediaItems.count - oldSongCount
        let alertController = UIAlertController(title: "modus", message:
            "New songs synced: \(newSongCount)\nTotal songs synced: \(mediaItems.count)", preferredStyle: UIAlertControllerStyle.Alert)
        alertController.addAction(UIAlertAction(title: "Dismiss", style: UIAlertActionStyle.Default,handler: nil))
        
        self.presentViewController(alertController, animated: true, completion: nil)
        print("New songs synced: \(newSongCount)\nTotal songs synced: \(mediaItems.count)")
        oldSongCount+=newSongCount
        newSongCount = 0
        let realm = try! Realm()
        try! realm.write() {
            appData![0].value = oldSongCount
            appData![0].modificationTime = NSDate()
        }
        //update table cells
        itemTable.reloadData()
    }
    
    func sortItems() -> [MPMediaItem]{
        let sort = sortType.selectedSegmentIndex
        let subSort = subSortType.selectedSegmentIndex
        if sort == 4{
            if subSort == 0{
                return MPMediaQuery.songsQuery().items!
            }
            else if subSort == 1{
                var query = MPMediaQuery.songsQuery().items!
                query.sortInPlace{
                    //print("\($0.title)'s playcount is \($0.playCount)\nand \($1.title)'s playcount is \($1.playCount)")
                    return $0.playCount > $1.playCount
                }
                return query
            }
        }
        print("sort unknown")
        return MPMediaQuery.songsQuery().items!
    }
}

extension musicLibraryController: UITableViewDataSource {
    
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return mediaItems.count
    }
    
    // 2
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCellWithIdentifier("itemCell", forIndexPath: indexPath) as! itemCell
        
        // 1
        let row = indexPath.row
        
        // 2
        let item = mediaItems[row]
        
        // 3
  
        if let titleOfItem = item.valueForProperty(MPMediaItemPropertyTitle) as? String {
            cell.itemTitle.text = titleOfItem
        }
        else{
            print("Resync Necessary: T")
            syncLibrary()
        }
        
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
            syncLibrary()
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
        
        return cell
    }
}

extension musicLibraryController: UITableViewDelegate {
    
}
