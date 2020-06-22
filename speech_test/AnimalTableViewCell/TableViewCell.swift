//
//  TableViewCell.swift
//  speech_test
//
//  Created by user on 22.06.2020.
//  Copyright © 2020 user. All rights reserved.
//

import UIKit

class TableViewCell: UITableViewCell {
    @IBOutlet weak var animalLabel: UILabel!
    @IBOutlet weak var animalButton: UIButton!
    @IBOutlet weak var checkImage: UIImageView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
    
    
}
