

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
              constant AAPLTexturedVertex *vertices [[buffer(AAPLVertexInputIndexVertices)]],
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
    
    c1[3] = (1.0 - c2[0]) + c3[0] * 0.2;
  
    return float4(c1);
}


fragment float4 fragmentShaderArtBoard(VertexOut in [[stage_in]],
                                    metal::texture2d<float> mainTeture [[texture(0)]],
                                    metal::texture2d<float> normalMap [[texture(1)]]){
    
    float ambient = 0.6;
    float diffuse = 0.4;
    
    // a manual light dir that match the scene pretty well
    float3 lightDir (0.235,-0.943,0.235);
    
    float4 c1 = mainTeture.sample(s, float2(in.uv[0], in.uv[1]));
    float4 n = normalMap.sample(s, float2(in.uv[0], in.uv[1]));
   
    // Make it gray scale
    //c1.xyz =  0.299 * c1.r + 0.587 * c1.g + 0.114 * c1.b;
    
    c1.xyz = c1.xyz * metal::dot(n.xyz, lightDir) * diffuse + c1.xyz * ambient ;
    return c1;
}
