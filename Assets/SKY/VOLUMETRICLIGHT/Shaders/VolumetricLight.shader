Shader "Shaders/VolumetricLight"
{
    Properties
    {
        _MainTex("_MainTex", 2D) = "white" {}
        _BlueNoise("_BlueNoise", 2D) = "white" {}
        _FinalTex("_FinalTex", 2D) = "white" {}
    }
    SubShader
    {
        Tags{"RenderPipeline" = "UniversalPipeline"
                                "LightMode" = "UniversalForward"} Cull Off Zwrite Off ZTest Always
            HLSLINCLUDE

#define MAX_MARCH_STEP 16

#define MAIN_LIGHT_CALCULATE_SHADOWS // 定义阴影采样
#define _MAIN_LIGHT_SHADOWS_CASCADE  // 启用级联阴影

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl" //阴影计算库
#include "Packages/com.unity.render-pipelines.universal/Shaders/PostProcessing/Common.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

            struct ATtributes
        {
            float4 positionOS : POSITION;
            float2 texcoord : TEXCOORD0;
        };

        struct Varings
        {
            float4 positionHCS : SV_POSITION;
            float2 uv : TEXCOORD0;
        };

        CBUFFER_START(UnityPerMaterial)
        Texture2D _MainTex;
        float4 _MainTex_TexelSize;
        SamplerState sampler_MainTex;

        Texture2D _BlueNoise;
        SamplerState sampler_BlueNoise;

        Texture2D _FinalTex;
        SamplerState sampler_FinalTex;

        float LightIntensity;
        CBUFFER_END

        Varings vert(ATtributes IN)
        {
            Varings OUT;
            OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
            OUT.uv = IN.texcoord;
            return OUT;
        }

        float Remap(float value, float inputMin, float inputMax, float outputMin, float outputMax)
        {
            return lerp(outputMin, outputMax, (value - inputMin) / (inputMax - inputMin));
        }

        float GetLightAttenuation(float3 position)
        {
            float4 shadowPos = TransformWorldToShadowCoord(position); // 把采样点的世界坐标转到阴影空间
            float intensity = MainLightRealtimeShadow(shadowPos);     // 进行shadow map采样
            return intensity;                                         // 返回阴影值
        }

        ENDHLSL

        Pass{
            Tags{"LightMode" = "UniversalForward"}

            HLSLPROGRAM

#pragma vertex vert
#pragma fragment lightFrag

                float4
                    lightFrag(Varings IN) : SV_Target{
                        float2 UV = IN.positionHCS.xy / _ScaledScreenParams.xy;
#if UNITY_REVERSED_Z
        real depth = SampleSceneDepth(UV);
#else
        real depth = lerp(UNITY_NEAR_CLIP_VALUE, 1, SampleSceneDepth(UV));
#endif
        // float4 col = _MainTex.SampleLevel(sampler_MainTex, IN.uv, 0); // 渲染结果原图

        float3 worldPos = ComputeWorldSpacePosition(UV, depth, UNITY_MATRIX_I_VP);
        float3 worldViewDir = normalize(worldPos.xyz - _WorldSpaceCameraPos.xyz);

        float jitter = _BlueNoise.SampleLevel(sampler_BlueNoise, IN.uv * 100, 0).r;

        float rayLength = length(worldPos.xyz - _WorldSpaceCameraPos.xyz);
        float step = rayLength / MAX_MARCH_STEP;
        float3 p = _WorldSpaceCameraPos.xyz + Remap(jitter, 0, 0.5, -0.15, 0.15);
        float intensity = 0;
        for (int i = 0; i < MAX_MARCH_STEP; i++)
        {
            float light = GetLightAttenuation(p); // 阴影采样
            intensity += light;
            p += worldViewDir * step;
        }
        intensity /= MAX_MARCH_STEP;

        return float4(intensity.rrr * LightIntensity * _MainLightColor.rgb, 1);
    }
    ENDHLSL
}
Pass{
    HLSLPROGRAM
#pragma vertex vert
#pragma fragment blurFrag

        float4 blurFrag(Varings IN) : SV_Target{
            // Kawase Blur:
            float _BlurRange = _MainTex_TexelSize.xy * 4;
float4 tex = _MainTex.SampleLevel(sampler_MainTex, IN.uv, 0); // 中心像素
tex += _MainTex.SampleLevel(sampler_MainTex, IN.uv + float2(-1, -1) * _BlurRange, 0);
tex += _MainTex.SampleLevel(sampler_MainTex, IN.uv + float2(1, -1) * _BlurRange, 0);
tex += _MainTex.SampleLevel(sampler_MainTex, IN.uv + float2(-1, 1) * _BlurRange, 0);
tex += _MainTex.SampleLevel(sampler_MainTex, IN.uv + float2(1, 1) * _BlurRange, 0);
return tex / 5.0;

////////////////////////////////////////////////////////////////////////////
// Gaussian Blur:
// float4 col = float4(0, 0, 0, 0);
// float blurrange = 0.005;
// col += _MainTex.SampleLevel(sampler_MainTex, IN.uv + float2(0.0, 0.0), 0) * 0.147716f;
// col += _MainTex.SampleLevel(sampler_MainTex, IN.uv + float2(blurrange, 0.0), 0) * 0.118318f;
// col += _MainTex.SampleLevel(sampler_MainTex, IN.uv + float2(0.0, -blurrange), 0) * 0.118318f;
// col += _MainTex.SampleLevel(sampler_MainTex, IN.uv + float2(0.0, blurrange), 0) * 0.118318f;
// col += _MainTex.SampleLevel(sampler_MainTex, IN.uv + float2(-blurrange, 0.0), 0) * 0.118318f;
// col += _MainTex.SampleLevel(sampler_MainTex, IN.uv + float2(blurrange, blurrange), 0) * 0.0947416f;
// col += _MainTex.SampleLevel(sampler_MainTex, IN.uv + float2(-blurrange, -blurrange), 0) * 0.0947416f;
// col += _MainTex.SampleLevel(sampler_MainTex, IN.uv + float2(blurrange, -blurrange), 0) * 0.0947416f;
// col += _MainTex.SampleLevel(sampler_MainTex, IN.uv + float2(-blurrange, blurrange), 0) * 0.0947416f;
// return col;
}

ENDHLSL
}
Pass
{
    HLSLPROGRAM
#pragma vertex vert
#pragma fragment mixFrag

    float4 mixFrag(Varings IN) : SV_Target
    {

        float3 oCol = _MainTex.SampleLevel(sampler_MainTex, IN.uv, 0).rgb;
        float3 lCol = _FinalTex.SampleLevel(sampler_FinalTex, IN.uv, 0).rgb;

        float3 dCol = lCol + oCol; // 原图和计算后的图叠加

        return float4(dCol, 1);
    }
    ENDHLSL
}
}
}