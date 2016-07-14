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
    }
    
    func setQueue(queue: [MPMediaItem]){
        mediaItems = queue
        itemCollection = MPMediaItemCollection(items: mediaItems)
        audio.setQueueWithItemCollection(itemCollection)
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
    
    func getQueueCount() -> Int{
        return mediaItems.count
    }
    
    func skipToBeginning(){
        audio.skipToBeginning()
    }
    
    func getNowPlayingItem() -> MPMediaItem?{
        return audio.nowPlayingItem
    }
    
    func getNowPlayingTitle(){
        
    }
    
    func setNowplayingItem(index: Int){
        audio.skipToBeginning()
        if index < 0 || index > mediaItems.count - 1 {
            audio.nowPlayingItem = nil
            audio.pause()
        }
        else{
            audio.nowPlayingItem = itemCollection.items[index]
            itemIndex = index
        }
        audio.play()
    }
    
    func getRawState() -> Int{
        return audio.playbackState.rawValue
    }
    
    func getCurrentPlaybackTime() -> NSTimeInterval{
        return audio.currentPlaybackTime
    }
}