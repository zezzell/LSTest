//
//  MainView.swift
//  LSTest
//
//  Created by Zach Ezzell on 8/14/20.
//

import Foundation
import Cocoa

class MainView: NSView{

    required init?(coder: NSCoder) {
        super.init(coder: coder);
        
        self.wantsLayer = true;
        self.layer?.backgroundColor  = CGColor(red:1.0,green:0.0,blue:0.0,alpha:1.0);
    }

}
