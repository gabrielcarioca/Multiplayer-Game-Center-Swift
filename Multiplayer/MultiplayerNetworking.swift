//
//  MultiplayerNetworking.swift
//  Multiplayer
//
//  Created by Gabriel Carioca on 8/7/15.
//  Copyright (c) 2015 Canopus. All rights reserved.
//

import UIKit
import GameKit

class MultiplayerNetworking: NSObject, GameKitHelperDelegate {
 
    let playerIdKey = "PlayerId"
    let randomNumberKey = "randomNumber"
    
    // States for the game
    enum GameState: UInt32 {
        case GameStateWaitingForMatch = 0
        case GameStateWaitingRandomNumber
        case GameStateWaitingForStart
        case GameStateActive
        case GameStateDone
    }
    
    // Different types of message
    enum MessageType: UInt32 {
        case MessageTypeRandomNumber = 0
        case MessageTypeGameBegin
        case MessageTypeMove
        case MessageTypeGameOver
    }
    
    // Base struct for knowing the type of the message
    struct Message {
        var messageType: MessageType
    }
    
    // Message to send a randomNumber, used in the code to determine who is player 1
    struct MessageRandomNumber {
        var message: Message
        var randomNumber: UInt32
    }
    
    // Message to inform the beginning of the game
    struct MessageGameBegin {
        var message: Message
    }
    
    // Message to send a text message. It should have another name
    struct MessageMove {
        var message: Message
        var text: String
        
        // Struct to archive the MessageMove
        struct ArchivedPacket {
            var messageArchived: Message
            var textLength: Int64
        }
        
        func archive() -> NSData{
            // Archiving the message to know the type of the message and the length of the string when encoding with NSUTF8StringEncoding
            var archivedPacket = ArchivedPacket(messageArchived: message, textLength: Int64(self.text.lengthOfBytesUsingEncoding(NSUTF8StringEncoding)))
            // Creating the NSData
            var metadata = NSData(bytes: &archivedPacket, length: sizeof(ArchivedPacket))
            
            // Appending the text string
            let archivedData = NSMutableData(data: metadata)
            archivedData.appendData(text.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)!)
            
            return archivedData
        }
        
        // Unarchive the message, with the type and the text
        static func unarchive(data: NSData) -> MessageMove {
            // The archivePacket, without the appended string in the bytes
            var archivedPacket = ArchivedPacket(messageArchived: Message(messageType: MessageType.MessageTypeMove), textLength: 0)
            let archivedStructLength = sizeof(ArchivedPacket)
            
            let archivedData = data.subdataWithRange(NSMakeRange(0, archivedStructLength))
            archivedData.getBytes(&archivedPacket, length: archivedStructLength)
            
            // The text appended to the NSData
            let textRange = NSMakeRange(archivedStructLength, Int(archivedPacket.textLength))
            
            let textData = data.subdataWithRange(textRange)
            let text = NSString(data: textData, encoding: NSUTF8StringEncoding) as! String
            
            // Returning the message with the text
            let messageMove = MessageMove(message: Message(messageType: MessageType.MessageTypeMove), text: text)
            
            return messageMove
        }
    }
    
    // Message to know when the game is over
    struct MessageGameOver {
        var message: Message
        var player1Won: Bool
    }
    
    // Our random number, used to know who is player 1 in the match
    var ourRandomNumber: UInt32!
    // The state of the game
    var gameState: GameState!
    // Flag to know if the localPlayer is the player 1
    var isPlayer1: Bool = false
    // Integer to know what is the position of the localPlayer in the players array
    var playerPosition: UInt32!
    // Flag to know if all players are connected and all sended the random number to determine the player 1
    var receivedAllRandomNumbers: Bool = false
    // The text received via MesageMove
    var receivedText: String!
    // An array with all players ordered based on the random number
    var orderOfPlayers = NSMutableArray()
    // Delegate to handle multiplayer Networking
    var delegate: MultiplayerNetworkingDelegate? = nil
    // Dictionary with the local player ID and the random Number
    var playerDict: NSDictionary!
    
    override init() {
        super.init()
        // Creating our random number
        ourRandomNumber = arc4random()
        // Finite State Machine of the game
        gameState = GameState.GameStateWaitingForMatch
        playerDict = NSDictionary(objects: [GameKitHelper.sharedGameKitHelper.localPlayer.playerID, NSInteger(ourRandomNumber)], forKeys: [playerIdKey, randomNumberKey])
    }
    
    
    func sendRandomNumber() {
        // Send the random number to all players in match to know who is player 1
        orderOfPlayers.addObject(playerDict)
        var message = MessageRandomNumber(message: Message(messageType: MessageType.MessageTypeRandomNumber), randomNumber: ourRandomNumber)
        var data = NSData(bytes: &message, length: sizeof(MessageRandomNumber))
        self.sendData(data)
    }
    
    func tryStartGame() {
        // If the match is ready to start, then start it
        if (isPlayer1 && gameState == GameState.GameStateWaitingForStart) {
            gameState = GameState.GameStateActive
            self.sendGameBegin()
            
            self.delegate?.setCurrentPlayerIndex?(0)
        }
    }
    
    func sendData(data: NSData) {
        // Send a NSData through the network
        var error: NSError?
        let gameKitHelper = GameKitHelper.sharedGameKitHelper
        
        var success: Bool = GameKitHelper.sharedGameKitHelper.match!.sendDataToAllPlayers(data, withDataMode: GKMatchSendDataMode.Reliable, error: &error)
        
        if (!success) {
            println("Error sending data\(error!.localizedDescription)")
            self.matchEnded()
        }
    }
    
    func matchEnded() {
        
    }
    
    func sendGameBegin() {
        // Send a message to inform the beginning of the game
        var message = MessageGameBegin(message: Message(messageType: MessageType.MessageTypeGameBegin))
        var data = NSData(bytes: &message, length: sizeof(MessageGameBegin))
        self.sendData(data)
    }
    
    func processReceivedRandomNumber(randomNumberDetails: NSDictionary) {
        // Handle the received handle number from another player in the match
        for random in orderOfPlayers {
            // If the player sent a new random number, remove the old one
            if let randomDict = random as? NSDictionary {
                if randomDict.objectForKey(playerIdKey) as! String == randomNumberDetails.objectForKey(playerIdKey) as! String {
                    orderOfPlayers.removeObject(randomDict)
                }
            }
        }
        // Adding the new received random number
        orderOfPlayers.addObject(randomNumberDetails)
        // Sort based on the random number to know who is player 1
        let sortByRandomNumber = NSSortDescriptor(key: randomNumberKey, ascending: false)
        let sortDescriptors = NSArray(array: [sortByRandomNumber])
        orderOfPlayers.sortUsingDescriptors(sortDescriptors as [AnyObject])

        if (self.allRandomNumbersAreReceived()) {
            // If all the players are connected and all of them sent the random number
            receivedAllRandomNumbers = true
        }
    }
    /**
    Checks if all the players are connected in the match and if all of them sent a random number

    :returns: A boolean indicating wheter all the players sent the random number or not
    */
    func allRandomNumbersAreReceived() -> Bool {
        // If all the players are connected and all of them sent the random number
        let receivedRandomNumbers = NSMutableArray()
        
        for dict1 in orderOfPlayers{
            if let dict = dict1 as? NSDictionary {
                receivedRandomNumbers.addObject(dict[randomNumberKey]!)
            }
        }
        
        let arrayOfUniqueRandomNumbers = NSSet(array: receivedRandomNumbers as [AnyObject]).allObjects
        
        if arrayOfUniqueRandomNumbers.count == GameKitHelper.sharedGameKitHelper.match!.players.count + 1 {
            return true
        }
        
        return false
    }
    /**
    Checks if the local player has the lowest random number to determine if he is player 1
    
    :returns: A boolean indicating whether the player is player1 or not, based on the randomNumber
    */
    func isLocalPlayerPlayer1() -> Bool {
        let dictionary = NSDictionary(dictionary: orderOfPlayers[0] as! NSDictionary)
        
        if (dictionary[playerIdKey]!.isEqualToString(GameKitHelper.sharedGameKitHelper.localPlayer.playerID)) {
            println("I'm player 1")
            return true
        }
        return false
    }
    
    // GameKitHelperDelegate
    // Called at the start of the match
    func matchStarted() {
        println("Match has started successfully")
        if (receivedAllRandomNumbers) {
            gameState = GameState.GameStateWaitingForStart
        }
        else {
            gameState = GameState.GameStateWaitingRandomNumber
        }
        sendRandomNumber()
        tryStartGame()
    }
    
    /** 
    Return the index of the player in the player array sorted based on the random number of each one in an ascending order
    
    :returns: An UInt32 representing the index of the player in the player array
    */
    func indexForLocalPlayer() -> UInt32 {
        let playerId = GameKitHelper.sharedGameKitHelper.localPlayer.playerID
        return self.indexForPlayerWithId(playerId)
    }
    
    /** 
    Return the index of the player with playerId
    
    :param: playerId the id of the player to look for in the players array
    
    :returns: An UInt32 representing the index of the player with playerId in the players array
    */
    func indexForPlayerWithId(playerId: String) -> UInt32{
        var index: UInt32 = 0
        for players in orderOfPlayers {
            if let player = players as? NSDictionary {
                if let playerIdToCompare = player[playerIdKey] as? String {
                    if playerIdToCompare == playerId {
                        break
                    }
                }
                index++
            }
        }
        return index
    }
    
    /**
    Process the received data through the network
    
    :param: match The match that the localPlayer is connected and playing
    :param: data The data received through the network
    :param: player The player who sent the data
    
    */
    func match(match: GKMatch, didReceiveData data: NSData, fromRemotePlayer player: GKPlayer) {
        
        var message = Message(messageType: MessageType.MessageTypeGameOver)
        data.getBytes(&message, length: sizeof(Message))
        
        // If the message is from a randomNumber type
        if (message.messageType == MessageType.MessageTypeRandomNumber) {
            var messageRandomNumber = UnsafeMutablePointer<MessageRandomNumber>.alloc(sizeof(MessageRandomNumber))

            data.getBytes(messageRandomNumber, length: sizeof(MessageRandomNumber))
            
            println("Received random number: \(messageRandomNumber.move().randomNumber)")
            
            var tie = false
            // If the random number form remote player is equal to the local player, generates a new one for both of the players and send it again
            if(messageRandomNumber.move().randomNumber == ourRandomNumber) {
                println("Tie")
                
                for random in orderOfPlayers {
                    
                    if let randomDict = random as? NSDictionary {
                        if randomDict == playerDict {
                            orderOfPlayers.removeObject(playerDict)
                        }
                    }
                }
                
                ourRandomNumber = arc4random()
                
                playerDict = NSDictionary(objects: [GameKitHelper.sharedGameKitHelper.localPlayer.playerID, NSInteger(ourRandomNumber)], forKeys: [playerIdKey, randomNumberKey])
                
                self.sendRandomNumber()
            }
            else {
                // If the received number is different from ours, add it to the players array
                let dictionary = NSDictionary(objects: [player.playerID, NSInteger(messageRandomNumber.move().randomNumber)], forKeys: [playerIdKey, randomNumberKey])
                self.processReceivedRandomNumber(dictionary)
                
                if (receivedAllRandomNumbers) {
                    isPlayer1 = self.isLocalPlayerPlayer1()
                    playerPosition = self.indexForLocalPlayer()
                    println("My position is \(self.playerPosition)")
                    
                }
                
                if (!tie && receivedAllRandomNumbers) {
                    if (gameState == GameState.GameStateWaitingRandomNumber) {
                        gameState = GameState.GameStateWaitingForStart
                    }
                    self.tryStartGame()
                }
            }
            
        }
        
        else if (message.messageType == MessageType.MessageTypeGameBegin) {
            // When receiving a message informing the start of the game
            println("Begin game message received")
            self.delegate?.setCurrentPlayerIndex?(self.indexForLocalPlayer())
        }
        
        else if (message.messageType == MessageType.MessageTypeMove) {
            // When receiving a message with a text. The name MessageMove is from a tutorial, change it later
            println("Move message received")

            let messageMove = MessageMove.unarchive(data)
            
            println("Recebi, estou funcionando, sucesso \(messageMove.text)")
            // Saving the received text in the Constants class
            Constants.receivedText = messageMove.text
            
            NSNotificationCenter.defaultCenter().postNotificationName(Constants.ReceivedText, object: nil)
            
        }
        
        else if (message.messageType == MessageType.MessageTypeGameOver) {
            println("Game over message received")
        }
    }
    
    func sendMove(text: String) {
        // Send a message with a text
        var messageMove = MessageMove(message: Message(messageType: MessageType.MessageTypeMove), text: text)

        let data = messageMove.archive()
        self.sendData(data)
    }
}
