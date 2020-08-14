
#ifndef ShaderTypes_h
#define ShaderTypes_h

#include <simd/simd.h>

typedef struct{
    matrix_float4x4 viewMatrix;
} Uniforms;

enum AAPLVertexInputIndex{
    AAPLVertexInputIndexVertices = 0,
    AAPLVertexInputIndexUniform
};

typedef struct{
    vector_float3 position;
    vector_float2 uv;
}AAPLColoredVertex;

#endif
