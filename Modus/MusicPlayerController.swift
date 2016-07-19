//
//  MusicPlayerController.swift
//  Modus
//
//  Created by Zain on 2016-07-13.
//  Copyright © 2016 Modus Applications. All rights reserved.
//

import UIKit
import MediaPlayer

class MusicPlayerController: UIViewController {
    
    var player: Player?
    var nowPlaying: MPMediaItem?

    @IBOutlet weak var artworkLyricDisplay: UIImageView!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        nowPlaying = player?.getNowPlayingItem()
        print(nowPlaying?.title)
        // Do any additional setup after loading the view.
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
