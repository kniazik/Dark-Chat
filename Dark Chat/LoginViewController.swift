//
//  LoginViewController.swift
//  Dark Chat
//
//  Created by elusive on 8/27/17.
//  Copyright © 2017 Knyazik. All rights reserved.
//

import UIKit
import Firebase

class LoginViewController: UIViewController {
    
    @IBOutlet weak var nameTextField: UITextField!
    @IBOutlet weak var loginButton: UIButton!
    @IBOutlet weak var bottomLayoutGuideConstraint: NSLayoutConstraint!
    
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setup()
        
        hideKeyboard()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(keyboardWillShow(_:)),
                                               name: .UIKeyboardWillShow,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(keyboardWillHide(_:)),
                                               name: .UIKeyboardWillHide,
                                               object: nil)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self,
                                                  name: .UIKeyboardWillShow,
                                                  object: nil)
        NotificationCenter.default.removeObserver(self,
                                                  name: .UIKeyboardWillHide,
                                                  object: nil)
    }
    
    // MARK: - Private
    
    private func setup() {
        loginButton.layer.cornerRadius = 3.0
    }
    
    // MARK: - Actions
    
    @IBAction func loginDidTouch(_ sender: AnyObject) {
        guard
            let name = nameTextField.text
        else {
            UIUtils.showAlert("Error", message: "Please enter your name")
            return
        }
        
        if !name.isEmpty {
            Auth.auth().signInAnonymously(completion: { (user, error) in
                if let error = error {
                    print(error.localizedDescription)
                    return
                }
                
                self.performSegue(withIdentifier: "LoginToChat", sender: nil)
            })
        } else {
            UIUtils.showAlert("Error", message: "Please enter your name")
        }
    }
    
    // MARK: - Notifications
    
    func keyboardWillShow(_ notification: Notification) {
        let keyboardEndFrame = ((notification as NSNotification).userInfo![UIKeyboardFrameEndUserInfoKey] as! NSValue).cgRectValue
        let convertedKeyboardEndFrame = view.convert(keyboardEndFrame, from: view.window)
        
        bottomLayoutGuideConstraint
            .constant = view.bounds.maxY - convertedKeyboardEndFrame.minY + 10
        
        layoutView()
    }
    
    func keyboardWillHide(_ notification: Notification) {
        bottomLayoutGuideConstraint.constant = 48
        
        layoutView()
    }
    
    // MARK: - Segue
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        
        guard
            let navVC = segue.destination as? UINavigationController,
            let channelVC = navVC.viewControllers.first as? ChannelListViewController
        else {
            return
        }
        
        channelVC.senderDisplayName = nameTextField?.text
    }
    
}
