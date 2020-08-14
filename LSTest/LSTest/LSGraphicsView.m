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
    id<MTLRenderPipelineState> _pipelineStateArtBoard;
    
    Renderable sceneRenderable;
    Renderable artBoardRenderable;
    
    float _viewAspect;
    
    id<MTLTexture> _sceneTexture;
    id<MTLTexture> _maskTexture;
    id<MTLTexture> _shadingTexture;
    id<MTLTexture> _artTexture;
}

-(id) initWithFrame:(NSRect)frameRect{
    
    self  = [super initWithFrame:frameRect];
  
    self.device = MTLCreateSystemDefaultDevice();
    self.delegate = self;
    
    _commandQueue = [self.device newCommandQueue];
    
    id<MTLLibrary> defaultLibrary = [self.device newDefaultLibrary];
    {
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

        // is all this really needed to enable blending?
        {
            pipelineStateDescriptor.colorAttachments[0].rgbBlendOperation = MTLBlendOperationAdd;
            pipelineStateDescriptor.colorAttachments[0].alphaBlendOperation = MTLBlendOperationAdd;
            pipelineStateDescriptor.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactorSourceAlpha;
            pipelineStateDescriptor.colorAttachments[0].sourceAlphaBlendFactor = MTLBlendFactorSourceAlpha;
            pipelineStateDescriptor.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
            pipelineStateDescriptor.colorAttachments[0].destinationAlphaBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
        }
        
        NSError *error = nil;
        _pipelineState = [self.device newRenderPipelineStateWithDescriptor:pipelineStateDescriptor error:&error];
        
        if(error != nil){
            //handle error... pop up window?
        }
    }
    
    {
        id<MTLFunction> vertexFunction = [defaultLibrary newFunctionWithName:@"vertexShaderBasic"];
        id<MTLFunction> fragmentFunction = [defaultLibrary newFunctionWithName:@"fragmentShaderArtBoard"];
        MTLRenderPipelineDescriptor* pipelineStateDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
        pipelineStateDescriptor.label = @"ArtBoard Pipeline State";
        pipelineStateDescriptor.vertexFunction = vertexFunction;
        pipelineStateDescriptor.fragmentFunction = fragmentFunction;
        pipelineStateDescriptor.colorAttachments[0].pixelFormat = self.colorPixelFormat;
        pipelineStateDescriptor.colorAttachments[0].blendingEnabled = NO;
        pipelineStateDescriptor.depthAttachmentPixelFormat = self.depthStencilPixelFormat;
        pipelineStateDescriptor.stencilAttachmentPixelFormat = self.depthStencilPixelFormat;

        NSError *error = nil;
        _pipelineStateArtBoard = [self.device newRenderPipelineStateWithDescriptor:pipelineStateDescriptor error:&error];
        
        if(error != nil){
            //handle error... pop up window?
        }
    }
    
    MTKTextureLoader *loader = [[MTKTextureLoader alloc] initWithDevice: self.device];
    
    //scene texture
    {
        // MTLPixelFormatBGRA8Unorm_sRGB
        NSURL* url = [[NSBundle mainBundle] URLForResource:[NSString stringWithUTF8String:"scene"] withExtension:@"tif"];
        _sceneTexture = [loader newTextureWithContentsOfURL:url options:@{ MTKTextureLoaderOptionAllocateMipmaps : @true, MTKTextureLoaderOptionGenerateMipmaps : @true} error:nil];
    }
    
    // mask texture
    {
        // MTLPixelFormatR8Unorm
        NSURL* url = [[NSBundle mainBundle] URLForResource:[NSString stringWithUTF8String:"mask"] withExtension:@"png"];
        _maskTexture = [loader newTextureWithContentsOfURL:url options:@{  MTKTextureLoaderOptionAllocateMipmaps : @true, MTKTextureLoaderOptionGenerateMipmaps : @true} error:nil];
    }
    
    // shading texture
    {
        // MTLPixelFormatR8Unorm
        NSURL* url = [[NSBundle mainBundle] URLForResource:[NSString stringWithUTF8String:"shading"] withExtension:@"png"];
        _shadingTexture = [loader newTextureWithContentsOfURL:url options:@{  MTKTextureLoaderOptionAllocateMipmaps : @true, MTKTextureLoaderOptionGenerateMipmaps : @true} error:nil];
    }
    
    // art texture
    {
        // MTLPixelFormatBGRA8Unorm_sRGB
        NSURL* url = [[NSBundle mainBundle] URLForResource:[NSString stringWithUTF8String:"poster"] withExtension:@"png"];
        _artTexture = [loader newTextureWithContentsOfURL:url options:@{  MTKTextureLoaderOptionAllocateMipmaps : @true, MTKTextureLoaderOptionGenerateMipmaps : @true} error:nil];
    }
    
    // scene renderable
    {
        int vCount = 6;
        float h = 1.0f;
        float w = (float)_sceneTexture.width / (float)_sceneTexture.height;
        
        AAPLColoredVertex v[] = {{{-w,-h,0.0f}, {0.0f,1.0f}},
            {{-w,h,0.0f}, {0.0f,0.0f}},
            {{w, h,0.0f}, {1.0f,0.0f}},
            {{w,-h,0.0f}, {1.0f,1.0f}},
            {{w,h,0.0f}, {1.0f,0.0f}},
            {{-w, -h,0.0f}, {0.0f,1.0f}}};
        sceneRenderable.vBuffer = [self.device newBufferWithLength:sizeof(AAPLColoredVertex) * vCount options:MTLResourceStorageModeShared];
        memcpy(sceneRenderable.vBuffer.contents, v, vCount* sizeof(AAPLColoredVertex));
        sceneRenderable.vCount = vCount;
    }
    
    // artboard renderable
    {
        int vCount = 6;
        float artBoardVerts [] = {0.180f, 0.815f,
            0.181f, 0.393f,
            0.610f, 0.372f,
            0.6145,0.844f
        };
        
        float aspect =  (float)_sceneTexture.width / (float)_sceneTexture.height;
     
        for(int i=0;i<=8;i+=2){
            artBoardVerts[i] = (artBoardVerts[i] - 0.5f) * 2.0f *  (float)_sceneTexture.width / (float)_sceneTexture.height;
            artBoardVerts[i+1] = ((1.0 - artBoardVerts[i+1]) - 0.5f) * 2.0f;
            
       //     artBoardVerts[i] = ((artBoardVerts[i] - 0.5f) * 2.0f);
         //     artBoardVerts[i+1] = ((1.0 - artBoardVerts[i+1]) - 0.5f) * 2.0f;
        }
                
        AAPLColoredVertex v[] = {{{artBoardVerts[0],artBoardVerts[1],0.0f}, {0.0f,1.0f}},
            {{artBoardVerts[2],artBoardVerts[3], 0.0f}, {0.0f,0.0f}},
            {{artBoardVerts[4],artBoardVerts[5],0.0f}, {1.0f,0.0f}},
            
            {{artBoardVerts[6],artBoardVerts[7], 0.0f}, {1.0f,1.0f}},
            {{artBoardVerts[4],artBoardVerts[5], 0.0f}, {1.0f,0.0f}},
            {{artBoardVerts[0],artBoardVerts[1], 0.0f}, {0.0f,1.0f}}};
        artBoardRenderable.vBuffer = [self.device newBufferWithLength:sizeof(AAPLColoredVertex) * vCount options:MTLResourceStorageModeShared];
        memcpy(artBoardRenderable.vBuffer.contents, v, vCount* sizeof(AAPLColoredVertex));
        artBoardRenderable.vCount = vCount;
    }
    
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

    Uniforms uniforms;
    uniforms.viewMatrix = [self computeViewMatrix];
   

    
    [renderEncoder setRenderPipelineState:_pipelineStateArtBoard];
    [renderEncoder setVertexBytes:&uniforms length:sizeof(uniforms) atIndex:AAPLVertexInputIndexUniform];
    [renderEncoder setFragmentTexture:_artTexture atIndex:0];
    
    [renderEncoder setVertexBuffer:artBoardRenderable.vBuffer offset:0 atIndex:AAPLVertexInputIndexVertices];
    [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:artBoardRenderable.vCount];
    
  
    [renderEncoder setRenderPipelineState:_pipelineState];
    [renderEncoder setVertexBytes:&uniforms length:sizeof(uniforms) atIndex:AAPLVertexInputIndexUniform];
    [renderEncoder setFragmentTexture:_sceneTexture atIndex:0];
    [renderEncoder setFragmentTexture:_maskTexture atIndex:1];
    [renderEncoder setFragmentTexture:_shadingTexture atIndex:2];
    [renderEncoder setVertexBuffer:sceneRenderable.vBuffer offset:0 atIndex:AAPLVertexInputIndexVertices];
    [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:sceneRenderable.vCount];
   
    
    [renderEncoder endEncoding];
    [commandBuffer presentDrawable:self.currentDrawable];
    [commandBuffer commit];
}


- (void)mtkView:(nonnull MTKView *)view drawableSizeWillChange:(CGSize)size {
    
    _viewAspect = size.width / size.height;
    // if we ever need a depth texture, we would recreate it here
}

@end
