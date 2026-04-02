#ifndef COLOUR_CGINC
#define COLOUR_CGINC

// RGB split sample texture.
// 'Slide' RGB channels in different directions, with quality as iterations (steps towards target offset).

void RGBSplit_float(sampler2D tex, float2 uv, float rgbSplit, uint rgbSplitQuality, out float3 output)
{
    float3 rgbShift = 0.0;
        
    for (uint i = 0; i < rgbSplitQuality; i++)
    {
        float progress = (i + 1.0) / rgbSplitQuality;
        
        float offset = rgbSplit * progress;
        
        float2 offset_r = float2(-offset, -offset);
        float2 offset_g = float2(+0.0, +offset);
        float2 offset_b = float2(+offset, -offset);
                
        rgbShift.r += tex2D(tex, uv - offset_r).r;
        rgbShift.g += tex2D(tex, uv - offset_g).g;
        rgbShift.b += tex2D(tex, uv - offset_b).b;
    }
    
    rgbShift /= rgbSplitQuality;    
    
    output = rgbShift;
}

#endif