//
//  CopyableLabel.swift
//  QRCodeReader
//
//  Created by Takaki Yoneyama on 2018/09/01.
//  Copyright © 2018年 Takaki Yoneyama. All rights reserved.
//

import UIKit

class CopyableLabel: UILabel {

    override var canBecomeFirstResponder: Bool {
        return true
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.commonInit()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.commonInit()
    }

    private func commonInit() {
        self.isUserInteractionEnabled = true
        self.addGestureRecognizer(UILongPressGestureRecognizer(target: self, action: #selector(showContextMenu(sender:))))
    }

    @objc private func showContextMenu(sender: AnyObject?) {
        self.becomeFirstResponder()
        guard !UIMenuController.shared.isMenuVisible else { return }
        UIMenuController.shared.setTargetRect(self.bounds, in: self)
        UIMenuController.shared.setMenuVisible(true, animated: true)
    }

    override func copy(_ sender: Any?) {
        UIPasteboard.general.string = text
        UIMenuController.shared.setMenuVisible(false, animated: true)
    }

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        guard action == #selector(UIResponderStandardEditActions.copy(_:)) else { return false }
        return true
    }

}
