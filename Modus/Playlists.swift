//
//  Playlists.swift
//  Modus
//
//  Created by Zain on 2016-08-04.
//  Copyright © 2016 Modus Applications. All rights reserved.
//

import Foundation
import RealmSwift
import MediaPlayer

class Playlists: Object{
    private var playlist = List<PlaylistItem>()
    dynamic private var playlistName: String = ""
    dynamic private var modifyDate: NSDate = NSDate()
    dynamic private var duration: NSTimeInterval = 0
    
    func getCount() -> Int{
        return playlist.count
    }
    
    func getTimeInterval() -> NSTimeInterval{
        return duration
    }
    
    func addItem(item: MPMediaItem){
        let playlistItem = PlaylistItem()
        if let title = item.title{
            playlistItem.title = title
        }
        if let album = item.albumTitle{
            playlistItem.album = album
        }
        if let artist = item.artist{
            playlistItem.artist = artist
        }
        playlistItem.duration = item.playbackDuration
        playlist.append(playlistItem)
        duration += item.playbackDuration
        modifyDate = NSDate()
    }
    
    func removeItem(item: MPMediaItem) -> Bool{
        let toDelete = PlaylistItem()
        if let title = item.title{
            toDelete.title = title
        }
        if let album = item.albumTitle{
            toDelete.album = album
        }
        if let artist = item.artist{
            toDelete.artist = artist
        }
        toDelete.duration = item.playbackDuration
        var index = 0
        for item in playlist{
            if item.compare(toDelete){
                duration -= toDelete.duration
                playlist.removeAtIndex(index)
                modifyDate = NSDate()
                print("playlist matched item and item removed")
                return true
            }
            else{
                index += 1
            }
        }
        print("playlist DID NOT match item")
        return false
    }
    
    func getItemsAsArray() -> [PlaylistItem]{
        var toReturn: [PlaylistItem] = []
        for i in 0...playlist.count-1{
            toReturn.append(playlist[i])
        }
        return toReturn
    }
    
    func getItemsAsList() -> List<PlaylistItem>{
        return playlist
    }
    
    func setName(name: String){
        playlistName = name
        modifyDate = NSDate()
    }
    
    func getName() -> String{
        return playlistName
    }
    
    func getModifyDate() -> NSDate{
        return modifyDate
    }
}