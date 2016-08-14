//
//  PlaylistItem.swift
//  Modus
//
//  Created by Zain on 2016-08-04.
//  Copyright © 2016 Modus Applications. All rights reserved.
//

import Foundation
import RealmSwift

class PlaylistItem: Object{
    dynamic var title: String = ""
    dynamic var album: String = ""
    dynamic var artist: String = ""
    dynamic var duration: NSTimeInterval = 0
    
    func compare(toCompare: PlaylistItem) -> Bool{
        if title == toCompare.title && album == toCompare.album && artist == toCompare.artist && duration == toCompare.duration{
            return true
        }
        return false
    }
}