

#include <metal_stdlib>
#include <simd/simd.h>

#import "ShaderTypes.h"

typedef struct{
    float4 position [[position]];
    float3 color;
    float pointsize[[point_size]];
} VertexOut;

vertex VertexOut
vertexShaderBasic(uint vertexID [[vertex_id]],
              constant AAPLColoredVertex *vertices [[buffer(AAPLVertexInputIndexVertices)]]){
    VertexOut out;
    out.pointsize = 20;
    out.position = float4(vertices[vertexID].position,1.0);
    out.color = vertices[vertexID].color;
    
    return out;
}

fragment float4 fragmentShaderBasic(VertexOut in [[stage_in]]){
    return float4(in.color, 1.0f);
}
