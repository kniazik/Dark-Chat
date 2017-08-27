//
//  ChatViewController.swift
//  Dark Chat
//
//  Created by elusive on 8/27/17.
//  Copyright © 2017 Knyazik. All rights reserved.
//

import UIKit
import Firebase
import JSQMessagesViewController
import Photos

final class ChatViewController: JSQMessagesViewController {
    
    lazy var outgoingBubbleImageView: JSQMessagesBubbleImage? = self.setupOutgoingBubble()
    lazy var incomingBubbleImageView: JSQMessagesBubbleImage? = self.setupIncomingBubble()
    
    private lazy var messageRef: DatabaseReference = self.channelRef!.child("messages")
    private var newMessageRefHandle: DatabaseHandle?
    
    private lazy var userIsTypingRef: DatabaseReference =
        self.channelRef!.child("typingIndicator").child(self.senderId)
    
    private var localTyping = false
    var isTyping: Bool {
        get {
            return localTyping
        }
        set {
            localTyping = newValue
            userIsTypingRef.setValue(newValue)
        }
    }
    
    private lazy var usersTypingQuery: DatabaseQuery = self.channelRef!.child("typingIndicator")
                                                                       .queryOrderedByValue()
                                                                       .queryEqual(toValue: true)
    
    lazy var storageRef: StorageReference = Storage
                                            .storage()
                                            .reference(forURL: "gs://dark-chat-a832a.appspot.com/")
    
    private let imageURLNotSetKey = "NOTSET"
    
    private var updatedMessageRefHandle: DatabaseHandle?
    
    var channelRef: DatabaseReference?
    var channel: Channel? {
        didSet {
            title = channel?.name
        }
    }
    private var messages = [JSQMessage]() {
        didSet {
            if messages.isEmpty {
                setupBackground()
            } else {
                collectionView.backgroundView = nil
            }
        }
    }
    private var photoMessageMap: [String: JSQPhotoMediaItem] = [:]
    
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupBackground()
        
        senderId = Auth.auth().currentUser?.uid
        
        collectionView.collectionViewLayout.incomingAvatarViewSize = .zero
        collectionView.collectionViewLayout.outgoingAvatarViewSize = .zero
        
        observeMessages()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        observeTyping()
    }
    
    deinit {
        removeAllObservers()
    }
    
    // MARK: - <UICollectionViewDataSource>
    
    override func collectionView(_ collectionView: UICollectionView,
                                 numberOfItemsInSection section: Int) -> Int {
        
        return messages.count
    }
    
    override func collectionView(_ collectionView: JSQMessagesCollectionView!,
                                 messageDataForItemAt indexPath: IndexPath!) -> JSQMessageData! {
        
        return messages[indexPath.item]
    }
    
    override func collectionView(
        _ collectionView: JSQMessagesCollectionView!,
        messageBubbleImageDataForItemAt indexPath: IndexPath!) -> JSQMessageBubbleImageDataSource! {
        
        let message = messages[indexPath.item]
        
        return (message.senderId == senderId)
                ? outgoingBubbleImageView
                : incomingBubbleImageView
    }
    
    override func collectionView(
        _ collectionView: JSQMessagesCollectionView!,
        avatarImageDataForItemAt indexPath: IndexPath!) -> JSQMessageAvatarImageDataSource! {
        
        return nil
    }
    
    override func collectionView(_ collectionView: UICollectionView,
                                 cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        guard
            let cell =
                super.collectionView(collectionView,
                                     cellForItemAt: indexPath) as? JSQMessagesCollectionViewCell
        else {
            return UICollectionViewCell()
        }
        
        let message = messages[indexPath.item]
        
        cell.textView?.textColor = (message.senderId == senderId)
                                    ? .white
                                    : .black
        
        return cell
    }
    
    override func didPressSend(_ button: UIButton!,
                               withMessageText text: String!,
                               senderId: String!,
                               senderDisplayName: String!,
                               date: Date!) {
        
        let itemRef = messageRef.childByAutoId()
        let messageItem = [
            "senderId": senderId!,
            "senderName": senderDisplayName!,
            "text": text!,
        ]
        
        itemRef.setValue(messageItem)
        
        JSQSystemSoundPlayer.jsq_playMessageSentSound()
        
        finishSendingMessage()
        
        isTyping = false
    }
    
    override func didPressAccessoryButton(_ sender: UIButton) {
        let alert = UIAlertController(title: nil,
                                      message: nil,
                                      preferredStyle: .actionSheet)
        
        let photoAction = UIAlertAction(title: "PhotoLibrary",
                                        style: .default) {
                                            [weak self] (alert: UIAlertAction!) -> Void in
                                            
                                            self?.photoFromLibrary()
        }
        
        let cameraAction = UIAlertAction(title: "Camera",
                                         style: .default) {
                                            [weak self] (alert: UIAlertAction!) -> Void in
                                            
                                            self?.takePhoto()
        }
        
        let cancelAction = UIAlertAction(title: "Cancel",
                                         style: .destructive,
                                         handler: nil)
        
        alert.addAction(photoAction)
        alert.addAction(cameraAction)
        alert.addAction(cancelAction)
        
        if UIDevice.current.userInterfaceIdiom == .pad {
            alert.popoverPresentationController?.sourceView = self.view
            let sourceRect = CGRect(x: sender.frame.maxX,
                                    y: sender.frame.minY - 100,
                                    width: 1.0, height: 1.0)
            alert.popoverPresentationController?.sourceRect = sourceRect
            alert.popoverPresentationController?.permittedArrowDirections = .down
        }
        
        present(alert, animated: true, completion:nil)
    }
    
    // MARK: - UI and Interaction
    
    private func setupOutgoingBubble() -> JSQMessagesBubbleImage {
        let bubbleImageFactory = JSQMessagesBubbleImageFactory()
        return bubbleImageFactory!
                .outgoingMessagesBubbleImage(with: .black)
    }
    
    private func setupIncomingBubble() -> JSQMessagesBubbleImage {
        let bubbleImageFactory = JSQMessagesBubbleImageFactory()
        return bubbleImageFactory!
                .incomingMessagesBubbleImage(with: .lightGray)
    }
    
    // MARK: - <UITextViewDelegate>
    
    override func textViewDidChange(_ textView: UITextView) {
        super.textViewDidChange(textView)
        
        isTyping = !textView.text.isEmpty
    }
    
    // MARK: - Private
    
    private func removeAllObservers() {
        if let refHandle = newMessageRefHandle {
            messageRef.removeObserver(withHandle: refHandle)
        }
        
        if let refHandle = updatedMessageRefHandle {
            messageRef.removeObserver(withHandle: refHandle)
        }
    }
    
    private func setupBackground() {
        let imageView = UIImageView(image: UIImage(named: "logo-light-theme.png"))
        imageView.contentMode = .center
        
        collectionView.backgroundView = imageView
    }
    
    private func addMessage(withId id: String, name: String, text: String) {
        if let message = JSQMessage(senderId: id,
                                    displayName: name,
                                    text: text) {
            
            messages.append(message)
        }
    }
    
    private func addPhotoMessage(withId id: String, key: String, mediaItem: JSQPhotoMediaItem) {
        if let message = JSQMessage(senderId: id,
                                    displayName: "",
                                    media: mediaItem) {
            messages.append(message)
            
            if (mediaItem.image == nil) {
                photoMessageMap[key] = mediaItem
            }
            
            collectionView.reloadData()
        }
    }
    
    private func observeMessages() {
        messageRef = channelRef!.child("messages")
        
        let messageQuery = messageRef.queryLimited(toLast:25)
        
        newMessageRefHandle =
            messageQuery.observe(.childAdded,
                                 with: { [weak self] (snapshot) -> Void in
            
                                    if let messageData = snapshot.value as?
                                        Dictionary<String, String> {
                                        
                                        if let id = messageData["senderId"] as String?,
                                            let name = messageData["senderName"] as String?,
                                            let text = messageData["text"] as String?,
                                            text.characters.count > 0 {
                                        
                                            self?.addMessage(withId: id,
                                                             name: name,
                                                             text: text)
                                        
                                            self?.finishReceivingMessage()
                                        }
                                        else if let id = messageData["senderId"] as String?,
                                            let photoURL = messageData["photoURL"] as String? {
                                            
                                            if let mediaItem = JSQPhotoMediaItem(
                                                maskAsOutgoing: id == self?.senderId) {
                                                
                                                self?.addPhotoMessage(withId: id,
                                                                      key: snapshot.key,
                                                                      mediaItem: mediaItem)
                                                
                                                if photoURL.hasPrefix("gs://") {
                                                    self?.fetchImageDataAtURL(
                                                        photoURL,
                                                        forMediaItem: mediaItem,
                                                        clearsPhotoMessageMapOnSuccessForKey: nil
                                                    )
                                                }
                                            }
                                        }
                                    } else {
                                        print("Error! Could not decode message data")
                                    }
            }
        )
        
        updatedMessageRefHandle =
            messageRef.observe(.childChanged, with: { [weak self] (snapshot) in
                guard
                    let messageData = snapshot.value as? Dictionary<String, String>
                else {
                    return
                }
                
                let key = snapshot.key
                
                if let photoURL = messageData["photoURL"] as String? {
                    if let mediaItem = self?.photoMessageMap[key] {
                        self?.fetchImageDataAtURL(photoURL,
                                                  forMediaItem: mediaItem,
                                                  clearsPhotoMessageMapOnSuccessForKey: key)
                    }
                }
            }
        )
    }
    
    private func observeTyping() {
        let typingIndicatorRef = channelRef!.child("typingIndicator")
        userIsTypingRef = typingIndicatorRef.child(senderId)
        userIsTypingRef.onDisconnectRemoveValue()
        
        usersTypingQuery.observe(.value) { [weak self] (data: DataSnapshot) in
            guard let safeSelf = self else { return }
            
            if data.childrenCount == 1 && safeSelf.isTyping {
                return
            }
            
            safeSelf.showTypingIndicator = data.childrenCount > 0
            safeSelf.scrollToBottom(animated: true)
        }
    }
    
    fileprivate func sendPhotoMessage() -> String? {
        let itemRef = messageRef.childByAutoId()
        
        let messageItem = [
            "photoURL": imageURLNotSetKey,
            "senderId": senderId!,
        ]
        
        itemRef.setValue(messageItem)
        
        JSQSystemSoundPlayer.jsq_playMessageSentSound()
        
        finishSendingMessage()
        
        return itemRef.key
    }
    
    fileprivate func setImageURL(_ url: String,
                             forPhotoMessageWithKey key: String) {
        
        let itemRef = messageRef.child(key)
        itemRef.updateChildValues(["photoURL": url])
    }
    
    private func fetchImageDataAtURL(_ photoURL: String,
                                     forMediaItem mediaItem: JSQPhotoMediaItem,
                                     clearsPhotoMessageMapOnSuccessForKey key: String?) {
        
        let storageRef = Storage.storage().reference(forURL: photoURL)
        
        storageRef.getData(maxSize: INT64_MAX){ (data, error) in
            if let error = error {
                print("Error downloading image data: \(error)")
                return
            }
            
            storageRef.getMetadata(completion: { (metadata, metadataErr) in
                if let error = metadataErr {
                    print("Error downloading metadata: \(error)")
                    return
                }
                
                if (metadata?.contentType == "image/gif") {
                    mediaItem.image = UIImage.gifWithData(data!)
                } else {
                    mediaItem.image = UIImage.init(data: data!)
                }
                self.collectionView.reloadData()
                
                guard
                    let key = key
                else {
                    return
                }
                
                self.photoMessageMap.removeValue(forKey: key)
            })
        }
    }
    
    private func photoFromLibrary() {
        let picker = UIImagePickerController()
        picker.delegate = self
        
        picker.sourceType = .photoLibrary
        
        present(picker, animated: true, completion:nil)
    }
    
    private func takePhoto() {
        let picker = UIImagePickerController()
        picker.delegate = self
        
        picker.sourceType = (UIImagePickerController
            .isSourceTypeAvailable(UIImagePickerControllerSourceType.camera))
            ? UIImagePickerControllerSourceType.camera
            : UIImagePickerControllerSourceType.photoLibrary
        
        present(picker, animated: true, completion:nil)
    }
    
}

// MARK: - <UIImagePickerControllerDelegate>

extension ChatViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController,
                               didFinishPickingMediaWithInfo info: [String : Any]) {
        
        picker.dismiss(animated: true, completion:nil)
        
        if let photoReferenceUrl = info[UIImagePickerControllerReferenceURL] as? URL {
            let assets = PHAsset.fetchAssets(withALAssetURLs: [photoReferenceUrl], options: nil)
            let asset = assets.firstObject
            
            guard
                let key = sendPhotoMessage()
            else {
                return
            }
            
            asset?
                .requestContentEditingInput(
                    with: nil,
                    completionHandler: { (contentEditingInput, info) in
                        
                        let imageFileURL = contentEditingInput?.fullSizeImageURL
                        
                        let path = "\(String(describing: Auth.auth().currentUser?.uid))/" +
                                    "\(Int(Date.timeIntervalSinceReferenceDate * 1000))/" +
                                    "\(photoReferenceUrl.lastPathComponent)"
                        
                        self.storageRef
                            .child(path)
                            .putFile(from: imageFileURL!,
                                     metadata: nil) { (metadata, error) in
                                        
                                        if let error = error {
                                            print("Error uploading photo: " +
                                                    "\(error.localizedDescription)")
                                            return
                                        }
                                        self.setImageURL(
                                                self.storageRef
                                                    .child((metadata?.path)!)
                                                    .description,
                                                forPhotoMessageWithKey: key
                                        )
                        }
                }
            )
        } else {
            guard
                let image = info[UIImagePickerControllerOriginalImage] as? UIImage,
                let key = sendPhotoMessage()
            else {
                return
            }
            
            let imageData = UIImageJPEGRepresentation(image, 1.0)
            
            let imagePath = Auth.auth().currentUser!.uid +
                            "/\(Int(Date.timeIntervalSinceReferenceDate * 1000)).jpg"
            
            let metadata = StorageMetadata()
            metadata.contentType = "image/jpeg"
            
            storageRef
                .child(imagePath)
                .putData(imageData!,
                     metadata: metadata) { (metadata, error) in
                        
                        if let error = error {
                            print("Error uploading photo: \(error)")
                            return
                        }
                        
                        self.setImageURL(
                            self.storageRef
                                .child((metadata?.path)!)
                                .description,
                            forPhotoMessageWithKey: key
                        )
            }
        }
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion:nil)
    }
}
