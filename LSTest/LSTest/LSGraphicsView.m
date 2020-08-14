//
//  GraphicsView.m
//  LSTest
//
//  Created by Zach Ezzell on 8/14/20.
//

#import <Foundation/Foundation.h>

#import "LSGraphicsView.h"
#import "ShaderTypes.h"

typedef struct{
    id<MTLBuffer> vBuffer;
    int vCount;
} Renderable;

@implementation LSGraphicsView{
    id<MTLCommandQueue> _commandQueue;
    id<MTLRenderPipelineState> _pipelineState;
    
    Renderable testRenderable;
}

-(id) initWithFrame:(NSRect)frameRect{
    
    self  = [super initWithFrame:frameRect];
  
    self.device = MTLCreateSystemDefaultDevice();
    self.delegate = self;
    
    _commandQueue = [self.device newCommandQueue];
    
    id<MTLLibrary> defaultLibrary = [self.device newDefaultLibrary];
    id<MTLFunction> vertexFunction = [defaultLibrary newFunctionWithName:@"vertexShaderBasic"];
    id<MTLFunction> fragmentFunction = [defaultLibrary newFunctionWithName:@"fragmentShaderBasic"];
    MTLRenderPipelineDescriptor* pipelineStateDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
    pipelineStateDescriptor.label = @"Pipeline State";
    pipelineStateDescriptor.vertexFunction = vertexFunction;
    pipelineStateDescriptor.fragmentFunction = fragmentFunction;
    pipelineStateDescriptor.colorAttachments[0].pixelFormat = self.colorPixelFormat;
    pipelineStateDescriptor.colorAttachments[0].blendingEnabled = NO;
    pipelineStateDescriptor.depthAttachmentPixelFormat = self.depthStencilPixelFormat;
    pipelineStateDescriptor.stencilAttachmentPixelFormat = self.depthStencilPixelFormat;
    
    NSError *error = nil;
    _pipelineState = [self.device newRenderPipelineStateWithDescriptor:pipelineStateDescriptor error:&error];
    
    if(error != nil){
        //handle error... pop up window?
    }
    
    int vCount = 1;
    // Make vertex buffer
    AAPLColoredVertex v[] = {{{0.0,0.0,0.0}, {0.0,1.0,0.0}}};
    testRenderable.vBuffer = [self.device newBufferWithLength:sizeof(AAPLColoredVertex) * vCount options:MTLResourceStorageModeShared];
    memcpy(testRenderable.vBuffer.contents, v, vCount* sizeof(AAPLColoredVertex));
    testRenderable.vCount = 1;
    
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
    }
    
    [renderEncoder setRenderPipelineState:_pipelineState];
    [renderEncoder setVertexBuffer:testRenderable.vBuffer offset:0 atIndex:AAPLVertexInputIndexVertices];
    [renderEncoder drawPrimitives:MTLPrimitiveTypePoint vertexStart:0 vertexCount:testRenderable.vCount];
    
    [renderEncoder endEncoding];
    [commandBuffer presentDrawable:self.currentDrawable];
    [commandBuffer commit];
}

- (void)mtkView:(nonnull MTKView *)view drawableSizeWillChange:(CGSize)size {
    // if we ever need a depth texture, we would recreate it here
}

@end
