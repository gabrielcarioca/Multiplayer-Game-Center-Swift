//
//  MultiplayerNetworkingDelegate.swift
//  Multiplayer
//
//  Created by Gabriel Carioca on 8/7/15.
//  Copyright (c) 2015 Canopus. All rights reserved.
//

import UIKit

@objc protocol MultiplayerNetworkingDelegate {
    optional func matchEnded()
    optional func setCurrentPlayerIndex(index: UInt32)
}
