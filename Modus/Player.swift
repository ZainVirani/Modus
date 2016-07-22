//
//  Player.swift
//  Modus
//
//  Created by Zain on 2016-07-14.
//  Copyright © 2016 Modus Applications. All rights reserved.
//

import Foundation
import MediaPlayer

class Player{
    private var mediaItems: [MPMediaItem] = []
    private var itemCollection: MPMediaItemCollection = MPMediaItemCollection(items: [])
    private let audio = MPMusicPlayerController.systemMusicPlayer()
    private var itemIndex = 0
    
    init(){
        audio.pause()
        audio.nowPlayingItem = nil
        print("Player initialized")
        NSNotificationCenter.defaultCenter().addObserver(
            self,
            selector: #selector(nowPlayingItemChanged),
            name: MPMusicPlayerControllerNowPlayingItemDidChangeNotification,
            object: nil)
    }
    
    @objc func nowPlayingItemChanged(notif: NSNotification){
        print("ITEM CHANGED")
    }
    
    func setQueue(queue: [MPMediaItem]){
        mediaItems = queue
        itemCollection = MPMediaItemCollection(items: mediaItems)
        audio.setQueueWithItemCollection(itemCollection)
        print("Player queue set")
    }
    
    func isLibraryEmpty() -> Bool{
        return mediaItems.isEmpty
    }
    
    func play(){
        audio.play()
    }
    
    func pause(){
        audio.pause()
    }
    
    func playNext(){
        itemIndex += 1
        setNowplayingItem(itemIndex)
    }
    
    func playPrev(){
        itemIndex -= 1
        setNowplayingItem(itemIndex)
    }
    
    func getPreviouslyPlayedItem(){
        
    }
    
    func getQueueCount() -> Int{
        return mediaItems.count
    }
    
    func skipToBeginning(){
        audio.skipToBeginning()
    }
    
    func getNowPlayingItem() -> MPMediaItem?{
        return audio.nowPlayingItem
    }
    
    func setNowplayingItem(index: Int){
        if index < 0 || index > mediaItems.count - 1 {
            audio.nowPlayingItem = nil
            audio.pause()
            print("index not valid, player paused")
        }
        else{
            audio.nowPlayingItem = itemCollection.items[index]
            itemIndex = index
        }
        print("set as \(itemCollection.items[index].title)")
    }
    
    func skipTo(time: NSTimeInterval){
        audio.currentPlaybackTime = time
    }
    
    func getRawState() -> Int{
        return audio.playbackState.rawValue
    }
    
    func getCurrentPlaybackTime() -> NSTimeInterval{
        return audio.currentPlaybackTime
    }
    
    deinit {
          NSNotificationCenter.defaultCenter().removeObserver(MPMusicPlayerControllerNowPlayingItemDidChangeNotification)
    }
}