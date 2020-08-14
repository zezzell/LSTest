
#ifndef ShaderTypes_h
#define ShaderTypes_h

#include <simd/simd.h>

enum AAPLVertexInputIndex{
    AAPLVertexInputIndexVertices = 0
};

typedef struct{
    vector_float3 position;
    vector_float3 color;
}AAPLColoredVertex;

#endif
