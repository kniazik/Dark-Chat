//
//  ChannelListViewController.swift
//  Dark Chat
//
//  Created by elusive on 8/27/17.
//  Copyright © 2017 Knyazik. All rights reserved.
//

import UIKit
import Firebase

enum Section: Int {
    case createNewChannelSection = 0
    case currentChannelsSection = 1
}

class ChannelListViewController: UITableViewController {
    
    var senderDisplayName: String?
    var newChannelTextField: UITextField?
    private var channels: [Channel] = []
    
    private lazy var channelRef: DatabaseReference = Database.database()
                                                        .reference()
                                                        .child("channels")
    private var channelRefHandle: DatabaseHandle?
    
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "Dark Chat"
        observeChannels()
    }
    
    deinit {
        if let refHandle = channelRefHandle {
            channelRef.removeObserver(withHandle: refHandle)
        }
    }
    
    // MARK: - <UITableViewDataSource>
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    override func tableView(_ tableView: UITableView,
                            numberOfRowsInSection section: Int) -> Int {
        
        if let currentSection = Section(rawValue: section) {
            switch currentSection {
            case .createNewChannelSection:
                return 1
            case .currentChannelsSection:
                return channels.count
            }
        } else {
            return 0
        }
    }
    
    override func tableView(_ tableView: UITableView,
                            cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let reuseIdentifier = (indexPath.section == Section.createNewChannelSection.rawValue)
                                ? "NewChannel"
                                : "ExistingChannel"
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier,
                                                 for: indexPath)
        
        if indexPath.section == Section.createNewChannelSection.rawValue {
            if let createNewChannelCell = cell as? CreateChannelCell {
                newChannelTextField = createNewChannelCell.newChannelNameField
            }
        } else if indexPath.section == Section.currentChannelsSection.rawValue {
            cell.textLabel?.text = channels[indexPath.row].name
        }
        
        return cell
    }
    
    // MARK: UITableViewDelegate
    
    override func tableView(_ tableView: UITableView,
                            didSelectRowAt indexPath: IndexPath) {
        
        if indexPath.section == Section.currentChannelsSection.rawValue {
            let channel = channels[indexPath.row]
            performSegue(withIdentifier: "ShowChannel", sender: channel)
        }
    }
    
    // MARK: - Firebase Database
    
    private func observeChannels() {
        channelRefHandle = channelRef.observe(.childAdded, with: { [weak self] (snapshot) -> Void in
            guard
                let channelData = snapshot.value as? Dictionary<String, AnyObject>
            else {
                print("Error! Unknown format of channel data")
                return
            }
            
            let id = snapshot.key
            if let name = channelData["name"] as? String, name.characters.count > 0 {
                self?.channels.append(Channel(id: id, name: name))
                self?.tableView.reloadData()
            } else {
                print("Error! Could not decode channel data")
            }
        })
    }
    
    // MARK: - Actions
    
    @IBAction func createChannel(_ sender: AnyObject) {
        if let name = newChannelTextField?.text, !name.isEmpty {
            let newChannelRef = channelRef.childByAutoId()
            let channelItem = [
                "name": name
            ]
            newChannelRef.setValue(channelItem)
        } else {
            UIUtils.showAlert("Error", message: "Please enter channel name")
        }
    }
    
    // MARK: - Segue
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        
        guard
            let channel = sender as? Channel,
            let chatVC = segue.destination as? ChatViewController
        else {
            return
        }
        
        chatVC.senderDisplayName = senderDisplayName
        chatVC.channel = channel
        chatVC.channelRef = channelRef.child(channel.id)
    }
    
}
