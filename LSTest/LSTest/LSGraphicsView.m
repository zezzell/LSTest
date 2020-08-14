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
    
    float _viewAspect;
    
    id<MTLTexture> _sceneTexture;
    id<MTLTexture> _maskTexture;
    id<MTLTexture> _shadingTexture;
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
    pipelineStateDescriptor.colorAttachments[0].blendingEnabled = YES;
    pipelineStateDescriptor.depthAttachmentPixelFormat = self.depthStencilPixelFormat;
    pipelineStateDescriptor.stencilAttachmentPixelFormat = self.depthStencilPixelFormat;

    pipelineStateDescriptor.colorAttachments[0].rgbBlendOperation = MTLBlendOperationAdd;
    pipelineStateDescriptor.colorAttachments[0].alphaBlendOperation = MTLBlendOperationAdd;
    pipelineStateDescriptor.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactorSourceAlpha;
    pipelineStateDescriptor.colorAttachments[0].sourceAlphaBlendFactor = MTLBlendFactorSourceAlpha;
    pipelineStateDescriptor.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
    pipelineStateDescriptor.colorAttachments[0].destinationAlphaBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
    
    NSError *error = nil;
    _pipelineState = [self.device newRenderPipelineStateWithDescriptor:pipelineStateDescriptor error:&error];
    
    if(error != nil){
        //handle error... pop up window?
    }
    
    MTKTextureLoader *loader = [[MTKTextureLoader alloc] initWithDevice: self.device];
    
    //scene texture
    {
        NSURL* url = [[NSBundle mainBundle] URLForResource:[NSString stringWithUTF8String:"scene"] withExtension:@"tif"];
        _sceneTexture = [loader newTextureWithContentsOfURL:url options:@{ MTKTextureLoaderOptionAllocateMipmaps : @true, MTKTextureLoaderOptionGenerateMipmaps : @true} error:nil];
    }
    
    // mask texture
    {

        NSURL* url = [[NSBundle mainBundle] URLForResource:[NSString stringWithUTF8String:"mask"] withExtension:@"png"];
        _maskTexture = [loader newTextureWithContentsOfURL:url options:@{  MTKTextureLoaderOptionAllocateMipmaps : @true, MTKTextureLoaderOptionGenerateMipmaps : @true} error:nil];
    }
    
    // shading texture
    {

        NSURL* url = [[NSBundle mainBundle] URLForResource:[NSString stringWithUTF8String:"shading"] withExtension:@"png"];
        _shadingTexture = [loader newTextureWithContentsOfURL:url options:@{  MTKTextureLoaderOptionAllocateMipmaps : @true, MTKTextureLoaderOptionGenerateMipmaps : @true} error:nil];
    }
    
    
    int vCount = 6;
    
    float h = 1.0f;
    float w = (float)_sceneTexture.width / (float)_sceneTexture.height;
    
    AAPLColoredVertex v[] = {{{-w,-h,0.0f}, {0.0f,1.0f}},
        {{-w,h,0.0f}, {0.0f,0.0f}},
        {{w, h,0.0f}, {1.0f,0.0f}},
        {{w,-h,0.0f}, {1.0f,1.0f}},
        {{w,h,0.0f}, {1.0f,0.0f}},
        {{-w, -h,0.0f}, {0.0f,1.0f}}};
    testRenderable.vBuffer = [self.device newBufferWithLength:sizeof(AAPLColoredVertex) * vCount options:MTLResourceStorageModeShared];
    memcpy(testRenderable.vBuffer.contents, v, vCount* sizeof(AAPLColoredVertex));
    testRenderable.vCount = vCount;
    
    return self;
}

-(matrix_float4x4) computeViewMatrix{
    
    // A little scale to padd the image vertically
    float scale = 0.9f;
    
    // scale x to adjust for the aspect ratio of the view
    float xScale = scale * (1.0/_viewAspect);
    
    return  (matrix_float4x4){{
        {xScale,0.0f,0.0f,0.0f},
        {0.0f,scale,0.0f,0.0f},
        {0.0f,0.0f,scale,0.0f},
        {0.0f,0.0f,0.0f,1.0f}
    }};
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
    
    Uniforms uniforms;
    uniforms.viewMatrix = [self computeViewMatrix];
    [renderEncoder setVertexBytes:&uniforms length:sizeof(uniforms) atIndex:AAPLVertexInputIndexUniform];
    
    [renderEncoder setFragmentTexture:_sceneTexture atIndex:0];
    [renderEncoder setFragmentTexture:_maskTexture atIndex:1];
    [renderEncoder setFragmentTexture:_shadingTexture atIndex:2];
    [renderEncoder setVertexBuffer:testRenderable.vBuffer offset:0 atIndex:AAPLVertexInputIndexVertices];
    [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:testRenderable.vCount];
    
    [renderEncoder endEncoding];
    [commandBuffer presentDrawable:self.currentDrawable];
    [commandBuffer commit];
}


- (void)mtkView:(nonnull MTKView *)view drawableSizeWillChange:(CGSize)size {
    
    _viewAspect = size.width / size.height;
    // if we ever need a depth texture, we would recreate it here
}

@end
