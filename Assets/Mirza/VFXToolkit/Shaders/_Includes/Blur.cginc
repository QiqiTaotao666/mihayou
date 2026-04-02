
#ifndef BLUR_CGINC
#define BLUR_CGINC

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

//#include "UnityCG.cginc"

#define PI 3.14159265359f
#define TAU 2.0 * PI

// BoxBlur: The most straightforward blur algorithm (not the best looking for larger blur amounts). Blur X and Y.
// NOTE: texelSize is just 1.0 / texture's width and height. Example: 1.0 / _ScreenParams.xy.

// Thus, using texelSize, blurRadius is in pixels.
// A radius of 32 would be a 32-pixel blur.

// Quality is the number of iterations to average the pixels around the current pixel.

void BoxBlur(texture2D tex, float2 uv, float2 texelSize, int blurQuality, float2 blurRadiusXY, out float4 output)
{
	// Pre-calculations.

    float4 colour = 0.0;
    float kernelWeightSum = 0;

    blurQuality++;
    blurRadiusXY *= texelSize / blurQuality;

	// Iterate through the surrounding pixels based on the blur quality.
	// Allow early abort of that array dimension (X or Y) if the axis multiplier is <= 0.0.

    int2 start, end;

	// +1 on start quality to make sure it's centered (noticeable on lower iteration counts).

    if (blurRadiusXY.x > 0)
    {
        start.x = -blurQuality + 1;
        end.x = blurQuality;
    }
    if (blurRadiusXY.y > 0)
    {
        start.y = -blurQuality + 1;
        end.y = blurQuality;
    }

	// With 'uv' as the center, do a square/grid search around to sum and average the pixels.
	// This effectively blurs the pixels with the ones around it.

    for (int y = start.y; y < end.y; y++)
    {
        for (int x = start.x; x < end.x; x++)
        {
            float2 offset = float2(x, y) * blurRadiusXY;
            colour += SAMPLE_TEXTURE2D(tex, sampler_LinearClamp, uv + offset);

            kernelWeightSum++;
        }
    }

	// Normalize accumulated blur color by iterations.
	// Return the final blurred color.

    output = colour / kernelWeightSum;
}

// BoxBlurWithCircleMask: Generates a box blur with a circle mask. 
// Texture sampling is so expensive this shader is actually faster than box blur from the reduced number of tex2D calls.

void BoxBlurWithCircleMask(texture2D tex, float2 uv, float2 texelSize, int blurQuality, float2 blurRadiusXY, out float4 output)
{
    float4 colour = 0.0;
    float kernelWeightSum = 0;

    blurQuality++;
    blurRadiusXY *= texelSize / blurQuality;

    int2 start, end;

    if (blurRadiusXY.x > 0)
    {
        start.x = -blurQuality + 1;
        end.x = blurQuality;
    }
    if (blurRadiusXY.y > 0)
    {
        start.y = -blurQuality + 1;
        end.y = blurQuality;
    }

    for (int y = start.y; y < end.y; y++)
    {
        for (int x = start.x; x < end.x; x++)
        {
            float2 offset = float2(x, y);

			// If current pixel ([x, y] in a square area around uv as the center) is within radius.

            if (length(offset) < blurQuality)
            {
                offset *= blurRadiusXY;
                colour += SAMPLE_TEXTURE2D(tex, sampler_LinearClamp, uv + offset);

                kernelWeightSum++;
            }
        }
    }

    output = colour / kernelWeightSum;
}

// GaussianBlur.
// Blur radius directly controls quality and blur amount.

// When using Amplify Shader Editor + _CameraOpaqueTexture,
// enable 'Use Sampling Macros' on the shader to force ASE to declare as texture2D, vs. sampler2D.

#define MAX_GAUSSIAN_BLUR_QUALITY 32

void GaussianBlur_float(texture2D tex, float2 uv, float2 texelSize, SamplerState samplerState, int blurQuality, float2 blurRadiusXY, out float4 output)
{
    float4 colour = 0.0;
    float kernelWeightSum = 0.0;

    blurRadiusXY *= texelSize / blurQuality;

	// Pre-compute Gaussian kernel.

    const int kernelSize = (MAX_GAUSSIAN_BLUR_QUALITY * 2) + 1;

    float kernel[kernelSize];

    float sigma = blurQuality / 2.0;
    float sigmaSqr = sigma * sigma;

    float oneOverTauSigmaSqr = 1.0 / (TAU * sigmaSqr);

    for (int i = 0; i <= blurQuality * 2; i++)
    {
        float x = i - blurQuality;
        kernel[i] = oneOverTauSigmaSqr * exp(-x * x / (2.0 * sigmaSqr));
    }

	// Blur (average) the pixels around current pixel based on Gaussian kernel.

    for (int y = -blurQuality; y <= blurQuality; y++)
    {
        for (int x = -blurQuality; x <= blurQuality; x++)
        {
            float2 offset = float2(x, y) * blurRadiusXY;

            float weight = kernel[blurQuality + x] * kernel[blurQuality + y];
            colour += SAMPLE_TEXTURE2D(tex, samplerState, uv + offset) * weight;

            kernelWeightSum += weight;
        }
    }

	// Normalize accumulated blur color by iterations and return.

    output = colour / kernelWeightSum;
}

// RadialBlur.

void RadialBlur_float(texture2D tex, SamplerState samplerState, float2 uv, float2 texelSize, int blurQuality, float2 blurRadiusXY, float2 blurCenter, out float4 output)
{
	// Pre-calculations.

    float4 colour = 0.0;
    float kernelWeightSum = 0;

    float blurQualityOneMinus = float(blurQuality - 1.0);

	// Iterate through the surrounding pixels based on the blur quality.

    for (int i = 0; i < blurQuality; i++)
    {
		// Calculate the offset in the radial direction based on the iteration and blur amount.

        float offset = i / blurQualityOneMinus;
        float2 offsetUV = blurCenter + (uv - blurCenter) * (1.0 - offset * blurRadiusXY);
		
        colour += SAMPLE_TEXTURE2D(tex, sampler_LinearClamp, offsetUV);
		
        kernelWeightSum++;
    }

	// Normalize accumulated blur color by iterations.
	// Return the final blurred color.

    output = colour / kernelWeightSum;
}

#endif