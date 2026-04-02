#ifndef QUANTIZE_HLSL
#define QUANTIZE_HLSL

void Quantize_Floor_float(float value, float step, out float output)
{
    output = round(value * step) / step;
}
void Quantize_Floor_float(float2 value, float step, out float2 output)
{
    output = floor(value * step) / step;
}
void Quantize_Floor_float(float3 value, float step, out float3 output)
{
    output = floor(value * step) / step;
}
void Quantize_Floor_float(float4 value, float step, out float4 output)
{
    output = floor(value * step) / step;
}

void Quantize_Round_float(float value, float step, out float output)
{
    output = round(value * step) / step;
}
void Quantize_Round_float(float2 value, float step, out float2 output)
{
    output = round(value * step) / step;
}
void Quantize_Round_float(float3 value, float step, out float3 output)
{
    output = round(value * step) / step;
}
void Quantize_Round_float(float4 value, float step, out float4 output)
{
    output = round(value * step) / step;
}

#endif