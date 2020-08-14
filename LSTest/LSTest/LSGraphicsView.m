//
//  GraphicsView.m
//  LSTest
//
//  Created by Zach Ezzell on 8/14/20.
//

#import <Foundation/Foundation.h>

#import "LSGraphicsView.h"

@implementation LSGraphicsView{
    id<MTLCommandQueue> _commandQueue;
}

-(id) initWithFrame:(NSRect)frameRect{
    
    self  = [super initWithFrame:frameRect];
    
    //self.wantsLayer = true;
    //self.layer.backgroundColor = [[NSColor colorWithRed:0.0 green:1.0 blue:0.0 alpha:1.0] CGColor];
    
    self.device = MTLCreateSystemDefaultDevice();
    self.delegate = self;
    
    _commandQueue = [self.device newCommandQueue];
    
    return self;
}



- (void)drawInMTKView:(nonnull MTKView *)view {
    
    id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
    commandBuffer.label = @"LS Command Buffer";
    
    MTLRenderPassDescriptor* renderPass = self.currentRenderPassDescriptor;
    
    id<MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPass];
    renderEncoder.label = @"LS Render Encoder";
    if(renderPass != nil){
        renderPass.colorAttachments[0].texture =  self.currentDrawable.texture;;
        //renderPass.colorAttachments[0].clearColor = MTLClearColorMake(0.f, 0.f, 0.f, 1.0);
        //renderPass.colorAttachments[0].storeAction = MTLStoreActionStore;
        //renderPass.colorAttachments[0].loadAction = MTLLoadActionClear;
    }
    
    // set pipeline state...
    
    // do draw calls...
    
    [renderEncoder endEncoding];
    [commandBuffer presentDrawable:self.currentDrawable];
    [commandBuffer commit];
}

- (void)mtkView:(nonnull MTKView *)view drawableSizeWillChange:(CGSize)size {
    // if we ever need a depth texture, we would recreate it here
}

@end
