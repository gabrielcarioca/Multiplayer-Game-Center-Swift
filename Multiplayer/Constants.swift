//
//  Constants.swift
//  App do Marcelo
//
//  Created by Gabriel Carioca on 7/31/15.
//  Copyright (c) 2015 aulaBepid. All rights reserved.
//

import UIKit
import GameKit

class Constants {
    
    // Strings representing the name of notifications
    // String to the notification resposible for showing the gameCenter view controller
    static let PresentAuthenticationViewController = "present_authentication_view_controller"
    // String to notificate when the localPlayer is authenticated
    static let LocalPlayerIsAuthenticated = "local_player_authenticated"
    // String to notificate when a text message is received through the network
    static let ReceivedText = "received_text"
    
    // String to save the received text and use it in the code
    static var receivedText: String = ""
}
