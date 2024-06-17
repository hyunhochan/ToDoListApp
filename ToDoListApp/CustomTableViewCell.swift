//
//  CustomTableViewCell.swift
//  ToDoListApp
//
//  Created by hyunho on 6/16/24.
//

import UIKit

class CustomTableViewCell: UITableViewCell {
    @IBOutlet weak var customImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var dateLabel: UILabel!

    var imageTapAction: (() -> Void)?

    override func awakeFromNib() {
        super.awakeFromNib()
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(imageTapped))
        customImageView.addGestureRecognizer(tapGesture)
        customImageView.isUserInteractionEnabled = true
    }

    @objc func imageTapped() {
        imageTapAction?()
    }
}
