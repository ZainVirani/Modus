//
//  AppData.swift
//  Modus
//
//  Created by Zain on 2016-07-12.
//  Copyright © 2016 Modus Applications. All rights reserved.
//

import Foundation
import RealmSwift

class AppData: Object {
    dynamic var name = ""
    dynamic var value = 0
    dynamic var content = ""
    dynamic var modificationTime = NSDate()
}
