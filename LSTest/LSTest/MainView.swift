//
//  MainView.swift
//  LSTest
//
//  Created by Zach Ezzell on 8/14/20.
//

import Foundation
import Cocoa

class MainView: NSView{
    
    var _graphicsView: LSGraphicsView;

    required init?(coder: NSCoder) {
        _graphicsView = LSGraphicsView(frame: NSMakeRect(0.0, 0.0, 1.0, 1.0));
        super.init(coder: coder);
        
        addSubview(_graphicsView);
        
        // only redraw when needed
        _graphicsView.isPaused = true;
        _graphicsView.enableSetNeedsDisplay = true;
        
        // Can't get self.frame until after super.init, there is probably
        // a better way to do this.
        _graphicsView.frame = NSMakeRect(0, 0.0, self.frame.size.width, self.frame.size.height);
    }
    
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize);
        _graphicsView.setFrameSize(newSize);
    }

}
