//
//  UIUtils.swift
//  Dark Chat
//
//  Created by elusive on 8/27/17.
//  Copyright © 2017 Knyazik. All rights reserved.
//

import UIKit

class UIUtils {
    
    class func showAlert(_ message: String) {
        UIUtils.showAlert(NSLocalizedString("Error", comment: ""), message: message)
    }
    
    class func showAlert(_ title: String?, message: String?) {
        let alertController = UIAlertController(title: title,
                                                message: message,
                                                preferredStyle: .alert)
        
        let actionOK = UIAlertAction(title: "OK",
                                     style: .default,
                                     handler: nil)
        
        alertController.addAction(actionOK)
        
        UIApplication.shared.keyWindow?.rootViewController?.present(alertController,
                                                                    animated: true,
                                                                    completion: nil)
    }
    
}
