

#include <metal_stdlib>
#include <simd/simd.h>

#import "ShaderTypes.h"

typedef struct{
    float4 position [[position]];
    float2 uv;
    float pointsize[[point_size]];
} VertexOut;

vertex VertexOut
vertexShaderBasic(uint vertexID [[vertex_id]],
              constant AAPLColoredVertex *vertices [[buffer(AAPLVertexInputIndexVertices)]],
              constant Uniforms &uniforms [[buffer(AAPLVertexInputIndexUniform)]]){
    
    VertexOut out;
    out.pointsize = 20;
    out.position = uniforms.viewMatrix * float4(vertices[vertexID].position,1.0);
    out.uv = vertices[vertexID].uv;
    
    return out;
}

constexpr metal::sampler s(metal::coord::normalized,
                           metal::address::repeat,
                           metal::filter::linear);


fragment float4 fragmentShaderBasic(VertexOut in [[stage_in]],
                                    metal::texture2d<float> mainTeture [[texture(0)]],
                                    metal::texture2d<float> maskTexture [[texture(1)]],
                                    metal::texture2d<float> shaderTexture [[texture(2)]]){
    
    float4 c1 = mainTeture.sample(s, float2(in.uv[0], in.uv[1]));
    float4 c2 = maskTexture.sample(s, float2(in.uv[0], in.uv[1]));
    float4 c3 = shaderTexture.sample(s, float2(in.uv[0], in.uv[1]));
    

    c1[3] = (1.0 - c2[0]) + c3[0] * 0.25;
  
    return float4(c1);
}


fragment float4 fragmentShaderArtBoard(VertexOut in [[stage_in]],
                                    metal::texture2d<float> mainTeture [[texture(0)]]){
    
    float4 c1 = mainTeture.sample(s, float2(in.uv[0], in.uv[1]));
  
    return float4(c1);
}
