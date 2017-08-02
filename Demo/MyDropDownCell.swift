//
//  MyDropDownCell.swift
//  DropDown
//
//  Created by huangjianwu on 2017/8/2.
//  Copyright © 2017年 Kevin Hirsch. All rights reserved.
//

import UIKit
import DropDown

typealias LongTapClosure = (_ cell:MyDropDownCell) ->Void

class MyDropDownCell: DropDownCell {
    var longTap:LongTapClosure?
    /*
    // Only override draw() if you perform custom drawing.
    // An empty implementation adversely affects performance during animation.
    override func draw(_ rect: CGRect) {
        // Drawing code
    }
    */
    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.contentView.backgroundColor = UIColor.green
        
        let tap = UILongPressGestureRecognizer.init(target: self, action: #selector(longGesTap(_:)))
        self.contentView.isUserInteractionEnabled = true
        self.contentView.addGestureRecognizer(tap)
    }
    
    func longGesTap(_ tap:UILongPressGestureRecognizer)  {
        if((self.longTap) != nil)
        {
            if(tap.state == .ended)
            {
                self.longTap!(self)
            }
        }
    }

    required init?(coder aDecoder: NSCoder) {
        //fatalError("init(coder:) has not been implemented")
        super.init(coder: aDecoder)
        
        let tap = UILongPressGestureRecognizer.init(target: self, action: #selector(longGesTap))
        //self.isUserInteractionEnabled = true
        self.addGestureRecognizer(tap)
    }

}
