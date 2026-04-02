
#ifndef LIGHTING_CGINC
#define LIGHTING_CGINC

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"

// Add these lines to either ASE or Shader Graph:

// #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
// #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
// #pragma multi_compile _ EVALUATE_SH_MIXED EVALUATE_SH_VERTEX
// #pragma multi_compile_fragment _ _ADDITIONAL_LIGHTS_SHADOWS
// #pragma multi_compile _ _FORWARD_PLUS
// #pragma multi_compile _ SHADOWS_SHADOWMASK
// #pragma multi_compile _ LIGHTMAP_ON
// #pragma multi_compile _ DYNAMICLIGHTMAP_ON

//void MainLight_float(float3 positionWS, float3 normalWS, float3 viewDirectionWS, float smoothness, out float3 output)
//{
//    output = 0.0;
    
//    float3 lightColour = _MainLightColor;
    
//    smoothness = exp2((10.0 * smoothness) + 1.0);
    
//    normalWS = normalize(normalWS);
//    viewDirectionWS = SafeNormalize(viewDirectionWS);
    
//    float4 shadowCoord = TransformWorldToShadowCoord(positionWS);
//    Light light = GetMainLight(shadowCoord);
    
//    // Phong lighting = lambert + specular.
//    // Blinn-Phong lighting = lambert + (halfway) specular.
        
//    // Lambert = max(dot(normal, lightDir), 0.0);
        
//    // Specular = pow(max(dot(reflect(-lightDir, normal), viewDir), 0.0), smoothness);
//    // Halfway Specular = pow(max(dot(normalize(lightDir + viewDir), normal), 0.0), smoothness);
    
//    //float3 diffuse = LightingLambert(lightColour, light.direction, normalWS);
//    //float3 specular = LightingSpecular(lightColour, light.direction, normalWS, viewDirectionWS, float4(1.0, 1.0, 1.0, 0.0), smoothness);
    
//    float diffuse = saturate(dot(normalWS, light.direction));
//    float specular = pow(saturate(dot(reflect(-light.direction, normalWS), viewDirectionWS)), smoothness);
    
//    output = (diffuse + specular) * lightColour;
//}

void MainLight_float(float3 positionWS, float3 shadowPositionWS, float3 normalWS, float3 viewDirectionWS, float smoothness, float specularStrength, float lightMaskResolution, out float3 output)
{
    output = 0.0;
    
    float3 lightColour = _MainLightColor;
    
    smoothness = exp2((10.0 * smoothness) + 1.0);
    
    normalWS = normalize(normalWS);
    viewDirectionWS = SafeNormalize(viewDirectionWS);
    
    Light light = GetMainLight(TransformWorldToShadowCoord(positionWS));
    Light shadowLight = GetMainLight(TransformWorldToShadowCoord(shadowPositionWS));
    
    // Phong lighting = lambert + specular.
    // Blinn-Phong lighting = lambert + (halfway) specular.
        
    // Lambert = max(dot(normal, lightDir), 0.0);
        
    // Specular = pow(max(dot(reflect(-lightDir, normal), viewDir), 0.0), smoothness);
    // Halfway Specular = pow(max(dot(normalize(lightDir + viewDir), normal), 0.0), smoothness);
    
    //float3 diffuse = LightingLambert(lightColour, light.direction, normalWS);
    //float3 specular = LightingSpecular(lightColour, light.direction, normalWS, viewDirectionWS, float4(1.0, 1.0, 1.0, 0.0), smoothness);
    
    float diffuse = saturate(dot(normalWS, light.direction));
    float specular = pow(saturate(dot(reflect(-light.direction, normalWS), viewDirectionWS)), smoothness);
    
    diffuse = round(diffuse * lightMaskResolution) / lightMaskResolution;
    specular = round(specular * lightMaskResolution) / lightMaskResolution;
    
    specular *= specularStrength;
    
    lightColour *= shadowLight.shadowAttenuation * light.distanceAttenuation;
    
    output = (diffuse + specular) * lightColour;
}

void MainLightRealtimeShadow_float(float3 positionWS, out float output)
{
    float4 shadowCoord = TransformWorldToShadowCoord(positionWS);
    
    //output = MainLightRealtimeShadow(shadowCoord);
    //output = MainLightShadow(shadowCoord, positionWS, half4(1.0, 1.0, 1.0, 1.0), _MainLightOcclusionProbes);
    
    // Unlike above, this takes into account disabled lights.
    
    Light light = GetMainLight(shadowCoord);
    output = light.shadowAttenuation * light.distanceAttenuation;
}
void AdditionalLightRealtimeShadow_float(int lightIndex, float3 positionWS, out float output)
{
    output = AdditionalLightRealtimeShadow(lightIndex, positionWS);
}

void AdditionalLightsRealtimeShadows_float(float3 positionWS, out float output)
{
    output = 1.0;
    
    uint additionalLightsCount = GetAdditionalLightsCount();
    
    for (uint i = 0; i < additionalLightsCount; i++)
    {
        const float4 shadowMask = 1.0;
        
        const half3 lightDirection = half3(1.0, 0.0, 0.0);
        output *= AdditionalLightRealtimeShadow(i, positionWS, lightDirection);
    }
}

float Lambert(float3 lightDirection, float3 normal)
{
    return saturate(dot(normal, lightDirection));
}
float Specular(float3 lightDirection, float3 normal, float3 viewDirection, float smoothness)
{
    return pow(saturate(dot(reflect(-lightDirection, normal), viewDirection)), smoothness);
}
float HalfwaySpecular(float3 lightDirection, float3 normal, float3 viewDirection, float smoothness)
{
    return pow(saturate(dot(normalize(lightDirection + viewDirection), normal)), smoothness);
}

float Phong(float3 lightDirection, float3 normal, float3 viewDirection, float smoothness)
{
    return Lambert(lightDirection, normal) + Specular(lightDirection, normal, viewDirection, smoothness);
}
void Phong(float3 lightDirection, float3 normal, float3 viewDirection, float smoothness, out float diffuse, out float specular)
{
    diffuse = Lambert(lightDirection, normal);
    specular = Specular(lightDirection, normal, viewDirection, smoothness);
}

float BlinnPhong(float3 lightDirection, float3 normal, float3 viewDirection, float smoothness)
{
    return Lambert(lightDirection, normal) + HalfwaySpecular(lightDirection, normal, viewDirection, smoothness);
}
void BlinnPhong(float3 lightDirection, float3 normal, float3 viewDirection, float smoothness, out float diffuse, out float specular)
{
    diffuse = Lambert(lightDirection, normal);
    specular = HalfwaySpecular(lightDirection, normal, viewDirection, smoothness);
}

//void AdditionalLights_float(float3 positionWS, float3 normalWS, float3 viewDirectionWS, float smoothness, out float3 output)
//{
//    output = 0.0;
    
//    uint count = GetAdditionalLightsCount();
    
//    float3 diffuse = 0.0;
//    float3 specular = 0.0;
    
//    smoothness = exp2((10.0 * smoothness) + 1.0);
    
//    normalWS = normalize(normalWS);
//    viewDirectionWS = SafeNormalize(viewDirectionWS);
    
//    for (uint i = 0; i < count; i++)
//    {
//        const float4 shadowMask = 1.0;
//        Light light = GetAdditionalLight(i, positionWS, shadowMask);
        
//        float3 lightColour = light.color * (light.distanceAttenuation * light.shadowAttenuation);
        
//        //diffuse += LightingLambert(lightColour, light.direction, normalWS);
//        //specular += LightingSpecular(lightColour, light.direction, normalWS, viewDirectionWS, float4(1.0, 1.0, 1.0, 0.0), smoothness);
                
//        float diffuseMask;
//        float specularMask;
        
//        BlinnPhong(light.direction, normalWS, viewDirectionWS, smoothness, lightColour, diffuseMask, specularMask);
                
//        diffuse += diffuseMask * lightColour;
//        specular += specularMask * lightColour;
//    }
    
//    output = diffuse + specular;
//}

void AdditionalLights_float(float3 positionWS, float3 normalWS, float3 viewDirectionWS, float smoothness, float specularStrength, float lightMaskResolution, out float3 output)
{
    output = 0.0;
    
    uint count = GetAdditionalLightsCount();
    
    float3 diffuse = 0.0;
    float3 specular = 0.0;
    
    smoothness = exp2((10.0 * smoothness) + 1.0);
    
    normalWS = normalize(normalWS);
    viewDirectionWS = SafeNormalize(viewDirectionWS);
    
    for (uint i = 0; i < count; i++)
    {
        const float4 shadowMask = 1.0;
        Light light = GetAdditionalLight(i, positionWS, shadowMask);
        
        float3 lightColour = light.color * (light.distanceAttenuation * light.shadowAttenuation);
        
        float diffuseMask;
        float specularMask;
        
        BlinnPhong(light.direction, normalWS, viewDirectionWS, smoothness, diffuseMask, specularMask);
                
        diffuseMask = round(diffuseMask * lightMaskResolution) / lightMaskResolution;
        specularMask = round(specularMask * lightMaskResolution) / lightMaskResolution;
        
        diffuse += diffuseMask * lightColour;
        specular += specularMask * lightColour;
    }
    
    specular *= specularStrength;
    
    output = diffuse + specular;
}

#endif