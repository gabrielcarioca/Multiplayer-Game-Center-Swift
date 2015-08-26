//
//  GameKitHelperDelegate.swift
//  Multiplayer
//
//  Created by Gabriel Carioca on 8/6/15.
//  Copyright (c) 2015 Canopus. All rights reserved.
//

import UIKit
import GameKit

@objc protocol GameKitHelperDelegate {
    optional func matchStarted()
    optional func matchEnded()
    optional func match(match: GKMatch, didReceiveData data: NSData, fromRemotePlayer player: GKPlayer)
    optional func willSignIn()
}
