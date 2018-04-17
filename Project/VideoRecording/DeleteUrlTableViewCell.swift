//
//  DeleteUrlTableViewCell.swift
//  VideoRecording
//
//  Created by Vivek Gupta on 16/04/18.
//  Copyright © 2018 Vivek Gupta. All rights reserved.
//

import UIKit
protocol DeleteUrlDelegate{
    func deleteClicked(keyUrl: String)
}
class DeleteUrlTableViewCell: UITableViewCell {

    @IBOutlet weak var deleteButton: UIButton!
    @IBOutlet weak var urlLabel: UILabel!
    var deleteUrlDelegate: DeleteUrlDelegate?
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }
    @IBAction func deleteButtonClicked(_ sender: UIButton) {
        if let txt = self.urlLabel.text{
            deleteUrlDelegate?.deleteClicked(keyUrl: txt)
        }
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
}
