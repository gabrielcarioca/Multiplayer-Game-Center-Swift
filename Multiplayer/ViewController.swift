//
//  ViewController.swift
//  Multiplayer
//
//  Created by Gabriel Carioca on 8/3/15.
//  Copyright (c) 2015 Canopus. All rights reserved.
//

import UIKit
import GameKit

class ViewController: UIViewController, UITextFieldDelegate, GameKitHelperDelegate, GKLocalPlayerListener{
    
    enum GameState: UInt32 {
        case GameStateWaitingForMatch = 0
        case GameStateWaitingForRandomNumber
        case GameStateWaitingForStart
        case GameStateActive
        case GameStateDone
    }
    
    enum MessageType: UInt32 {
        case MessageTypeRandomNumber = 0
        case MessageTypeGameBegin
        case MessageTypeMove
        case MessageTypeGameOver
    }
    
    struct Message {
        var messageType: MessageType
    }

    @IBOutlet weak var valueLabel2: UILabel!
    @IBOutlet weak var valueTextField: UITextField!
    @IBOutlet weak var sendButton: UIButton!
    
    var kbHeight: CGFloat!
    
    // Multiplayer
    var match: GKMatch!
    var playersDict = NSMutableDictionary()
    var invitedMatch : GKInvite? = nil
    var networkEngine: MultiplayerNetworking!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        valueTextField.delegate = self
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        
        // Handle notifications
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "showAuthenticationDialogueWhenReasonable", name: Constants.PresentAuthenticationViewController, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "playerAuthenticated", name: Constants.LocalPlayerIsAuthenticated, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "receivedText", name: Constants.ReceivedText, object: nil)

        GameKitHelper.sharedGameKitHelper.authenticateLocalPlayer()
    }
    
    func initNetworkEngine() {
        if (networkEngine == nil) {
            // Creating the object responsible for handling all the network in the game
            networkEngine = MultiplayerNetworking()
        }
    }
    
    func receivedText() {
        valueLabel2.text = Constants.receivedText
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    override func touchesBegan(touches: Set<NSObject>, withEvent event: UIEvent) {
        view.endEditing(true)
    }
    
    func keyboardWillShow(notification: NSNotification) {
        if let userInfo = notification.userInfo {
            if let keyboardSize = (userInfo[UIKeyboardFrameBeginUserInfoKey] as? NSValue)?.CGRectValue() {
                kbHeight = keyboardSize.height
                self.animateTextView(true)
            }
        }
    }
    
    func keyboardWillHide(notification: NSNotification) {
        self.animateTextView(false)
    }
    
    func animateTextView(up: Bool) {
        var movement = (up ? -kbHeight : kbHeight)
        
        UIView.animateWithDuration(0.3, animations: { () -> Void in
            self.view.frame = CGRectOffset(self.view.frame, 0, movement)
        })
    }
    
    func textFieldShouldReturn(textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    //Game Center methods
    
    // Show Authentication Dialogue
    func showAuthenticationDialogueWhenReasonable () {
        let gameKitHelper = GameKitHelper.sharedGameKitHelper
        println(__FUNCTION__)
        
        dispatch_async(dispatch_get_main_queue(), {
            UIApplication.sharedApplication().keyWindow!.rootViewController!.presentViewController(gameKitHelper.authenticationViewController, animated: true, completion: nil)
        })
    }
    
    func playerAuthenticated() {
        initNetworkEngine()
        GameKitHelper.sharedGameKitHelper.findMatchWithMinPlayers(2, maxPlayers: 2, viewController: self, delegate: networkEngine)
    }
    
    
    // GAMEKITHELPER DELEGATE
    func matchStarted() {
        println("Match errada")
    }
    
    func matchEnded() {
        println("Match errada")
    }
    
    func match(match: GKMatch, didReceiveData data: NSData, fromRemotePlayer player: GKPlayer) {
        println("Received errada")
        networkEngine.match(match, didReceiveData: data, fromRemotePlayer: player)
    }

    @IBAction func sendButtonTapped(sender: AnyObject) {
        networkEngine.sendMove(valueTextField.text)
    }
}
