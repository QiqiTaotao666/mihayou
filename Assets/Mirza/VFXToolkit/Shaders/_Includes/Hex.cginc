#ifndef HEX_CGINC
#define HEX_CGINC

// Mirza: Example of hexagonal sampling and animation.
// I made this largely for my own learning, but hopefully it can help others.

// https://twitter.com/TheMirzaBeig/status/1731324791557140490

#define tsnTriangleRatio float2(sqrt(3.0), 1.0)

void Hex_float(float2 p, float output)
{
    p = abs(p);
    output = max(dot(p, tsnTriangleRatio * 0.5), p.y);
}

// xy = 2D distance in each cell. Use with Hex() to get hexagon shape.
// zw = hexagonal-quantized UV coordinates (cell ID).

void HexLattice(float2 uv, float4 output)
{
    float4 hexCenter = round(float4(uv, uv - float2(1.0, 0.5)) / tsnTriangleRatio.xyxy);
    float4 offset = float4(uv - hexCenter.xy * tsnTriangleRatio, uv - (hexCenter.zw + 0.5) * tsnTriangleRatio);
     
    output =
     
    dot(offset.xy, offset.xy) < dot(offset.zw, offset.zw) ?
    float4(offset.xy, hexCenter.xy) : float4(offset.zw, hexCenter.zw + 0.5);
}

#endif