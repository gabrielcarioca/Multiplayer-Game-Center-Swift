//
//  GameKitHelper.swift
//  Multiplayer
//
//  Created by Gabriel Carioca on 8/6/15.
//  Copyright (c) 2015 Canopus. All rights reserved.
//

import UIKit
import GameKit

/**
Class responsible for handling the gameCenter methods. It authenticates the player, locates a match and also implements the GKMatchmakerViewControllerDelegate to handle the matchmaker view controller, doing stufs when the match starts or when cancelled. Use it's singleton sharedGameKitHelper.
*/
class GameKitHelper: NSObject, GKMatchDelegate, GKMatchmakerViewControllerDelegate {
    
    // View Controller to authenticate the player, if he is not connected to the gameCenter
    var authenticationViewController: UIViewController!
    
    var lastError: NSError? = nil
    
    //Flag for working with game center only when the player is connected
    var gameCenterConnected: Bool = true
    
    // The localPlayer connected in the device
    var localPlayer = GKLocalPlayer.localPlayer()

    var delegate: GameKitHelperDelegate? = nil
    
    // Singleton
    static var sharedGameKitHelper = GameKitHelper()
    
    // Match
    var matchStarted: Bool = false
    var match: GKMatch? = nil
    
    // Multi Players
    var playersDict: NSMutableDictionary!
    
    // Authenticate the Player
    func authenticateLocalPlayer()
    {
        println(__FUNCTION__)
        // WillSignIn
       self.delegate?.willSignIn?()
        
        // The player authenticates in an asynchronous way, so we need a notification to inform when the authentication was completed successfully
        // If the local player is already connected, return and notificate
        if GameKitHelper.sharedGameKitHelper.localPlayer.authenticated {
            NSNotificationCenter.defaultCenter().postNotificationName(Constants.LocalPlayerIsAuthenticated, object: nil)
            return
        }
        
        // Calling the authentication view controller
        self.localPlayer.authenticateHandler = {(viewController : UIViewController!, error : NSError!) -> Void in
            
            self.addLastError(error)
            
            if (viewController != nil)
            {
                self.addAuthenticationViewController(viewController)
            }
            
            // If the localPlayer authenticated successfully notificate
            else if (self.localPlayer.authenticated == true)
            {
                self.gameCenterConnected = true
                println("Local player ID: \(self.localPlayer.playerID)")
                println("Local player Alias: \(self.localPlayer.alias)")
                NSNotificationCenter.defaultCenter().postNotificationName(Constants.LocalPlayerIsAuthenticated, object: nil)

            }
            // If the localPlayer failed to authenticate
            else
            {
                self.gameCenterConnected = false
            }
            
            if (error != nil)
            {
                //  Handle error here
            }
        }
    }
    
    func lookupPlayers() {
        println("Looking up \(match?.players.count)")
        
        // Loading ID from players connected in the match
        var idsArray = NSMutableArray()
        if (match != nil) {
            for players in match!.players {
                if let player = players as? GKPlayer {
                    idsArray.addObject(player.playerID)
                }
            }
            
        }
        
        GKPlayer.loadPlayersForIdentifiers(idsArray as [AnyObject], withCompletionHandler: { (players, error) -> Void in
            if (error != nil) {
                // Handle error here
                // if we fail to retrieve player info return and end the match
                println("Error retrieving player info: \(error.localizedDescription)")
                self.matchStarted = false
                self.delegate?.matchEnded?()
            }
            else {
                // Get info from all players and start the match
                self.playersDict = NSMutableDictionary(capacity: players.count)
                for player1 in players {
                    if let player = player1 as? GKPlayer {
                        println("Found player: \(player.alias)")
                        self.playersDict.setObject(player, forKey: player.playerID)
                    }
                }
                self.playersDict.setObject(self.localPlayer, forKey: self.localPlayer.playerID)
                
                self.matchStarted = true
                self.delegate?.matchStarted?()
            }
        })
    }
    
    // Assign the authentication view controller and notificate to present it
    func addAuthenticationViewController(authenticationViewController: UIViewController) {
            self.authenticationViewController = authenticationViewController
            NSNotificationCenter.defaultCenter().postNotificationName(Constants.PresentAuthenticationViewController, object: self)
    }
    
    // Handle error
    func addLastError(error: NSError?) {
        if (error != nil) {
            self.lastError = (error!.copy() as! NSError)
        }
        if (lastError != nil) {
            println("GameKit Helper Error: \(self.lastError?.userInfo?.description)")
        }
    }
    
    /**
    Create a match with minPlayers to maxPlayers and create a matchmaker view controller to manage the match
    
    :param: minPlayers an Int representing the minimum number of players in the match
    :param: maxPlayers an Int representing the maximum number of players in the match
    :param: viewController the UIViewController to present the matchmaker view controller modally
    
    
    */
    func findMatchWithMinPlayers(minPlayers: Int, maxPlayers: Int, viewController: UIViewController, delegate: GameKitHelperDelegate) {
        if(!gameCenterConnected) {
            return
        }
        matchStarted = false
        self.match = nil
        self.delegate = delegate
        
        let request = GKMatchRequest()
        request.minPlayers = minPlayers
        request.maxPlayers = maxPlayers
        
        let mmvc = GKMatchmakerViewController(matchRequest: request)
        mmvc.matchmakerDelegate = self
        mmvc.modalPresentationStyle = UIModalPresentationStyle.OverFullScreen
        
        viewController.presentViewController(mmvc, animated: true, completion: nil)
        
    }
    
    // GKMatchmakerViewControllerDelegate
    // Called when the user cancelled the matchmaker view controller
    func matchmakerViewControllerWasCancelled(viewController: GKMatchmakerViewController!) {
        viewController.dismissViewControllerAnimated(true, completion: nil)
    }
    
    // Called when the matchmaker view controller fail to create a match
    func matchmakerViewController(viewController: GKMatchmakerViewController!, didFailWithError error: NSError!) {
        viewController.dismissViewControllerAnimated(true, completion: nil)
        println("Error finding match: \(error.localizedDescription)")
    }
    
    // Called when the match was found successfully
    func matchmakerViewController(viewController: GKMatchmakerViewController!, didFindMatch match: GKMatch!) {
        // Dismiss the matchmaker view controller
        viewController.dismissViewControllerAnimated(true, completion: nil)
        
        self.match = match
        match.delegate = self
        // If all players are connected, check them all and start the match
        if (!matchStarted && match.expectedPlayerCount == 0) {
            println("Ready to start match")
            self.lookupPlayers()
        }
    }
    
    // GKMatchDelegate
    // Called when receiving data from another player in the match
    func match(match: GKMatch!, didReceiveData data: NSData!, fromRemotePlayer player: GKPlayer!) {
        if (match != self.match) {
            println("Wrong match")
            return
        }
        
        // Calls the delegate to handle the received data
        delegate?.match?(match, didReceiveData: data, fromRemotePlayer: player)
    }
    
    // Called when the state of the match cnahges
    func match(match: GKMatch!, player playerID: String!, didChangeState state: GKPlayerConnectionState) {
        if (match != self.match) {
            println("Wrong match")
            return
        }
        
        switch(state) {
        case GKPlayerConnectionState.StateConnected:
            println("Player Connected")
            
            if (!matchStarted && match.expectedPlayerCount == 0) {
                println("Ready to start match")
                self.lookupPlayers()
            }
        case GKPlayerConnectionState.StateDisconnected:
            println("Player disconnected")
            matchStarted = false
            delegate?.matchEnded?()
        default:
            println("What the fuck is happening with this code?")
        }

    }
    
    // Called when the match fails for some reason
    func match(match: GKMatch!, didFailWithError error: NSError!) {
        if (match != self.match) {
            println("Wrong match")
            return
        }
        
        println("Failed with error: \(error.localizedDescription)")
        matchStarted = false
        delegate?.matchEnded?()
    }
    
}
