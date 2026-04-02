
#ifndef SDF_CGINC
#define SDF_CGINC

// https://iquilezles.org/articles/distfunctions/
// https://iquilezles.org/articles/distfunctions2d/

float opOnion(float sdf, float thickness)
{
    return abs(sdf) - thickness;
}

float sdCircle(float2 p, float r)
{
    return length(p) - r;
}

float sdRect(float2 p, float2 b)
{
    float2 d = abs(p) - b;
    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

float sdSphere(float3 p, in float r)
{
    return length(p) - r;
}

void sdHollowSphere_float(float3 p, float r, float thickness, out float output)
{
    output = opOnion(sdSphere(p, r), thickness);
}

void sdHollowSphereLight_float(float3 position, float radius, float thickness, float falloff, out float output)
{
    float sdf = opOnion(sdSphere(position, radius), thickness);
    output = 1.0 / (pow(sdf, falloff) + 1.0);
}

#endif