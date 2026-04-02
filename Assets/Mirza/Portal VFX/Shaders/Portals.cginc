#ifndef Portal_CGINC
#define Portal_CGINC

struct WaveData
{
    float3 position;
    
    float radius;    
    float scale;
    
    float phase;
    float mask;
};

StructuredBuffer<WaveData> waveDataBuffer;

void Waves(float3 worldPosition, uint count, out float output)
{
    float total = 0.0;
    
    for (uint i = 0; i < count; i++)
    {
        WaveData wave = waveDataBuffer[i];
        
        float3 position = worldPosition - wave.position;
        
        // Divide by radius (vs. subtract) so scan is stretched and I can easily remap across the field.
        
        float sdf = length(position) / wave.radius;
        float mask = 1.0f - saturate(sdf + wave.mask);
       
        sdf *= wave.scale;
        sdf -= wave.phase;
        
        float waveSdf = sin(sdf * 3.14159);
        
        waveSdf = pow(abs(waveSdf), 2.0);
                
        float maskedWaveSdf = waveSdf * mask;
        
        total = max(total, maskedWaveSdf);
        //total += waveSdf;
    }
    
    output = total;
}

#endif