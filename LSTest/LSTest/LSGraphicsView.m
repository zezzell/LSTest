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
    id<MTLTexture> _normalMapTexture;
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
    
    
    // mip mapping the textures for performance and hopefully to mitigate some of the jaggies on down sampling
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
        NSURL* url = [[NSBundle mainBundle] URLForResource:[NSString stringWithUTF8String:"poster_2"] withExtension:@"png"];
        _artTexture = [loader newTextureWithContentsOfURL:url options:@{  MTKTextureLoaderOptionAllocateMipmaps : @true, MTKTextureLoaderOptionGenerateMipmaps : @true} error:nil];
    }
    
    // normal map for art texture
    {
        // MTLPixelFormatBGRA8Unorm_sRGB
        NSURL* url = [[NSBundle mainBundle] URLForResource:[NSString stringWithUTF8String:"poster_2_normal"] withExtension:@"png"];
        _normalMapTexture = [loader newTextureWithContentsOfURL:url options:@{  MTKTextureLoaderOptionAllocateMipmaps : @true, MTKTextureLoaderOptionGenerateMipmaps : @true} error:nil];
    }
    
    // scene renderable
    {
        int vCount = 6;
        float h = 1.0f;
        float w = (float)_sceneTexture.width / (float)_sceneTexture.height;
        
        AAPLTexturedVertex v[] = {{{-w,-h,0.0f}, {0.0f,1.0f}},
            {{-w,h,0.0f}, {0.0f,0.0f}},
            {{w, h,0.0f}, {1.0f,0.0f}},
            {{w,-h,0.0f}, {1.0f,1.0f}},
            {{w,h,0.0f}, {1.0f,0.0f}},
            {{-w, -h,0.0f}, {0.0f,1.0f}}};
        sceneRenderable.vBuffer = [self.device newBufferWithLength:sizeof(AAPLTexturedVertex) * vCount options:MTLResourceStorageModeShared];
        memcpy(sceneRenderable.vBuffer.contents, v, vCount* sizeof(AAPLTexturedVertex));
        sceneRenderable.vCount = vCount;
    }
    
    // artboard renderable
    {
        // Hard coded values for the art board
        int faceCount =  128;
        float verts[] = {-3.229819,-4.795494,0.000016,1.139567,-5.220438,0.000016,-3.204065,1.608474,0.000017,1.100936,1.917524,0.000017 ,-3.216942,-1.593510,0.000017 ,-1.045126,-5.007966,0.000016,1.120251,-1.651457,0.000017 ,-1.051565,1.762999,0.000017,-1.048345,-1.622483,0.000017,-3.223381,-3.194502,0.000016, 0.047220,-5.114202,0.000016, 1.110594,0.133034,0.000017,-2.127815,1.685736,0.000017,-3.210504,0.007482,0.000017, -2.137473,-4.901730,0.000016,1.129909,-3.435947,0.000016,0.024686,1.840261,0.000017, -1.049955,0.070258,0.000017, -1.046736,-3.315225,0.000016,-2.132644,-1.607997,0.000017,0.035953,-1.636970,0.000017, 0.041587,-3.375586,0.000016, -2.135058,-3.254863,0.000016,-2.130229,0.038870,0.000017, 0.030319,0.101646,0.000017, -3.226600,-3.994998,0.000016,  0.593394,-5.167320,0.000016, 1.105765,1.025279,0.000017,-2.665940,1.647105,0.000017,-3.213723,-0.793014,0.000017,-1.591300,-4.954848,0.000016,1.125080,-2.543702,0.000017,-0.513439,1.801630,0.000017,-1.050760,0.916628,0.000017,-1.047541,-2.468854,0.000017,-2.674793,-1.600753,0.000017,-0.506196,-1.629727,0.000017,-3.220161,-2.394006,0.000017,-0.498953,-5.061084,0.000016,1.115422,-0.759212,0.000017,-1.589690,1.724368,0.000017,-3.207284,0.807978,0.000017,-2.683646,-4.848612,0.000016,1.134738,-4.328193,0.000016,0.562811,1.878893,0.000017,-1.049150,-0.776113,0.000017,-1.045931,-4.161595,0.000016,-1.590495,-1.615240,0.000017,0.578102,-1.644213,0.000017,0.038770,-2.506278,0.000017,0.044404,-4.244894,0.000016,-0.502575,-3.345405,0.000016,0.585748,-3.405767,0.000016,-2.133851,-2.431430,0.000017,-2.136266,-4.078296,0.000016,-2.679219,-3.224682,0.000016,-1.590897,-3.285044,0.000016,-2.129022,0.862303,0.000017,-2.131437,-0.784563,0.000017,-2.670367,0.023176,0.000017,-1.590092,0.054564,0.000017,0.027502,0.970953,0.000017,0.033136,-0.767662,0.000017,-0.509818,0.085952,0.000017,0.570456,0.117340,0.000017,0.574279,-0.763437,0.000017,-0.508007,-0.771888,0.000017,-0.511629,0.943791,0.000017,-1.590293,-0.780338,0.000017,-2.672580,-0.788789,0.000017,-2.668153,0.835140,0.000017,-1.591098,-4.119946,0.000016,-2.681433,-4.036647,0.000016,-2.677006,-2.412718,0.000017,0.589571,-4.286543,0.000016,-0.500764,-4.203245,0.000016,-0.504385,-2.487566,0.000017,0.581925,-2.524990,0.000017,-1.590696,-2.450142,0.000017,-1.589891,0.889466,0.000017,0.566634,0.998116,0.000017};
        float uvs[] = {1.0000,0.8750,0.8750,1.0000,0.8750,0.8750,0.5000,0.8750,0.3750,1.0000,0.3750,0.8750,0.3750,0.3750,0.5000,0.5000,0.3750,0.5000,0.8750,0.3750,1.0000,0.5000,0.8750,0.5000,0.6250,0.3750,0.7500,0.5000,0.6250,0.5000,0.6250,0.1250,0.7500,0.2500,0.6250,0.2500,0.8750,0.1250,1.0000,0.2500,0.8750,0.2500,0.1250,0.3750,0.2500,0.5000,0.1250,0.5000,0.1250,0.1250,0.2500,0.2500,0.1250,0.2500,0.3750,0.1250,0.5000,0.2500,0.3750,0.2500,0.2500,0.8750,0.1250,1.0000,0.1250,0.8750,0.2500,0.6250,0.1250,0.7500,0.1250,0.6250,0.5000,0.6250,0.3750,0.7500,0.3750,0.6250,0.7500,0.8750,0.6250,1.0000,0.6250,0.8750,0.7500,0.6250,0.6250,0.7500,0.6250,0.6250,1.0000,0.6250,0.8750,0.7500,0.8750,0.6250,0.7500,0.7500,0.5000,0.7500,0.5000,1.0000,0.2500,0.7500,0.0000,0.7500,0.0000,0.6250,0.0000,0.5000,0.0000,1.0000,0.0000,0.8750,0.2500,0.1250,0.2500,0.0000,0.3750,0.0000,0.5000,0.1250,0.0000,0.1250,0.0000,0.2500,0.0000,0.0000,0.1250,0.0000,0.0000,0.3750,0.2500,0.3750,0.7500,0.1250,0.7500,0.0000,0.8750,0.0000,1.0000,0.1250,0.5000,0.0000,0.6250,0.0000,0.5000,0.3750,0.7500,0.3750,1.0000,0.3750,0.2500,1.0000,0.7500,1.0000,1.0000,0.7500,1.0000,1.0000,1.0000,0.0000};
        // indices are vert, uv, vert, uv, ...
        int indices[] = {28,1,45,2,81,3,34,4,41,5,80,6,79,7,9,8,48,9,78,10,7,11,49,12,77,13,21,14,37,15,76,16,22,17,52,18,75,19,16,20,53,21,74,22,20,23,36,24,73,25,23,26,56,27,72,28,19,29,57,30,58,31,29,32,71,33,59,34,60,35,70,36,46,37,61,38,69,39,62,40,33,41,68,42,63,43,64,44,67,45,40,46,65,47,66,48,66,48,25,49,63,43,21,14,66,48,63,43,49,12,40,46,66,48,67,45,18,50,46,37,9,8,67,45,46,37,37,15,63,43,67,45,68,42,8,51,34,4,64,44,34,4,18,50,25,49,68,42,64,44,69,39,24,52,59,34,20,23,69,39,59,34,48,9,46,37,69,39,70,36,14,53,30,54,36,24,30,54,5,55,36,24,59,34,70,36,71,33,3,56,42,57,60,35,42,57,14,53,24,52,71,33,60,35,55,58,57,30,23,26,15,59,72,28,55,58,31,60,47,61,72,28,26,62,56,27,10,63,1,64,73,25,26,62,43,65,55,58,73,25,38,66,36,24,5,55,10,63,74,22,38,66,56,27,54,67,74,22,51,68,53,21,22,17,11,69,75,19,51,68,27,70,44,71,75,19,47,61,52,18,19,29,6,72,76,16,47,61,39,73,51,68,76,16,35,74,37,15,9,8,19,29,77,13,35,74,52,18,50,75,77,13,50,75,49,12,21,14,22,17,78,10,50,75,53,21,32,76,78,10,54,67,48,9,20,23,23,26,79,7,54,67,57,30,35,74,79,7,80,6,13,77,58,31,61,38,58,31,24,52,18,50,80,6,61,38,81,3,17,78,62,40,65,47,62,40,25,49,12,79,81,3,65,47,28,1,4,80,45,2,34,4,8,51,41,5,79,7,35,74,9,8,78,10,32,76,7,11,77,13,50,75,21,14,76,16,51,68,22,17,75,19,44,71,16,20,74,22,54,67,20,23,73,25,55,58,23,26,72,28,47,61,19,29,58,31,13,77,29,32,59,34,24,52,60,35,46,37,18,50,61,38,62,40,17,78,33,41,63,43,25,49,64,44,40,46,12,79,65,47,66,48,65,47,25,49,21,14,49,12,66,48,49,12,7,11,40,46,67,45,64,44,18,50,9,8,37,15,67,45,37,15,21,14,63,43,68,42,33,41,8,51,64,44,68,42,34,4,25,49,62,40,68,42,69,39,61,38,24,52,20,23,48,9,69,39,48,9,9,8,46,37,70,36,60,35,14,53,36,24,70,36,30,54,36,24,20,23,59,34,71,33,29,32,3,56,60,35,71,33,42,57,24,52,58,31,71,33,55,58,72,28,57,30,15,59,31,60,72,28,31,60,6,72,47,61,26,62,73,25,56,27,1,64,43,65,73,25,43,65,15,59,55,58,38,66,74,22,36,24,10,63,56,27,74,22,56,27,23,26,54,67,51,68,75,19,53,21,11,69,27,70,75,19,27,70,2,81,44,71,47,61,76,16,52,18,6,72,39,73,76,16,39,73,11,69,51,68,35,74,77,13,37,15,19,29,52,18,77,13,52,18,22,17,50,75,50,75,78,10,49,12,22,17,53,21,78,10,53,21,16,20,32,76,54,67,79,7,48,9,23,26,57,30,79,7,57,30,19,29,35,74,80,6,41,5,13,77,61,38,80,6,58,31,18,50,34,4,80,6,81,3,45,2,17,78,65,47,81,3,62,40,12,79,28,1,81,3};

        int vCount = faceCount * 3;
        int iCount = vCount * 2;

        // manual transform factor for the artboard
        float s = 0.13f;
        float dx = -0.005f;
        float dy = -0.005f;
        AAPLTexturedVertex* vData = (AAPLTexturedVertex*) malloc(sizeof(AAPLTexturedVertex) * vCount);
        
        for(int i=0;i<iCount; i+=2){
            
            int vIndex = indices[i]-1;
            int uvIndex = indices[i+1]-1;
            
            float x = verts[vIndex*3] * s + dx;
            float y = verts[vIndex*3+1] * s + dy;
            float z = 0.0f; //verts[vIndex*3+2]; ignore z
            
            float u = uvs[uvIndex*2];
            float v = -uvs[uvIndex*2+1];
            AAPLTexturedVertex t;
           
            t.position.x = x ;
            t.position.y = y;
            t.position.z = z;
            t.uv.x = u;
            t.uv.y = v;
            
            vData[i/2] = t;
        }
      
    
        artBoardRenderable.vBuffer = [self.device newBufferWithLength:sizeof(AAPLTexturedVertex) * vCount options:MTLResourceStorageModeShared];
        memcpy(artBoardRenderable.vBuffer.contents, vData, vCount * sizeof(AAPLTexturedVertex));
        artBoardRenderable.vCount = vCount;
        
        free(vData);

    }
    
    return self;
}

-(matrix_float4x4) computeViewMatrix{
    
    // A little scale to pad the image vertically
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
    [renderEncoder setFragmentTexture:_normalMapTexture atIndex:1];
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
}

@end
