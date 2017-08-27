//
//  CreateChannelCell.swift
//  Dark Chat
//
//  Created by elusive on 8/27/17.
//  Copyright © 2017 Knyazik. All rights reserved.
//

import UIKit

class CreateChannelCell: UITableViewCell {
    
    @IBOutlet weak var newChannelNameField: UITextField!
    @IBOutlet weak var createChannelButton: UIButton!
    
    
    // MARK: - Lifecycle
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        guard
            let text = newChannelNameField.text
        else {
            createChannelButton.isEnabled = false
            return
        }
        
        createChannelButton.isEnabled = !text.isEmpty
    }
    
    // MARK: - <UITextFieldDelegate>
    
    @IBAction private func textFieldEditingChanged(_ textField: UITextField) {
        guard
            let text = textField.text
        else {
            return
        }
        
        if textField.isEqual(newChannelNameField) {
            createChannelButton.isEnabled = !text.isEmpty
        }
    }
    
}
