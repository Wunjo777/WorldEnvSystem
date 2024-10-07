Shader "Shaders/LightShaft"
{
    Properties
    {
        _MainTex("_MainTex", 2D) = "white" {}
        _FinalTex("_FinalTex", 2D) = "white" {}
    }
    SubShader
    {
        Tags{"RenderPipeline" = "UniversalPipeline"
                                "LightMode" = "UniversalForward"} Cull Off Zwrite Off ZTest Always
            HLSLINCLUDE
#define RADIAL_SAMPLE_COUNT 30

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
// #include "Packages/com.unity.render-pipelines.universal/Shaders/PostProcessing/Common.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"

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
        SamplerState sampler_MainTex;

        Texture2D _FinalTex;
        SamplerState sampler_FinalTex;

        float4 _MainTex_TexelSize;

        float _ColorThreshold;
        float3 _ViewPortLightPos;
        float _LightRadius;
        float _PowFactor;
        float _offsets;
        float _Intensity;
        CBUFFER_END

        Varings
        vert(ATtributes IN)
        {
            Varings OUT;
            OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
            OUT.uv = IN.texcoord;
#if UNITY_UV_STARTS_AT_TOP
            if (_MainTex_TexelSize.y < 0)
                OUT.uv.y = 1 - OUT.uv.y;
#endif
            return OUT;
        }

        ENDHLSL

        Pass{

            HLSLPROGRAM

#pragma vertex vert
#pragma fragment lightFrag

                float4
                    lightFrag(Varings IN) : SV_Target{

                        float4 col = _MainTex.SampleLevel(sampler_MainTex, IN.uv, 0); // 渲染结果原图
        float distFromLight = length(_ViewPortLightPos.xy - IN.uv);
        float distanceControl = _LightRadius - distFromLight;
        // 仅当color大于设置的阈值的时候才输出
        float3 thresholdColor = saturate(col.xyz - _ColorThreshold) * distanceControl;
        float luminanceColor = Luminance(thresholdColor.rgb); // 颜色转灰阶
        luminanceColor = pow(luminanceColor, _PowFactor);

        return float4(luminanceColor.xxx, 1);
    }
    ENDHLSL
}
Pass{
    HLSLPROGRAM
#pragma vertex vert
#pragma fragment blurFrag

        float4 blurFrag(Varings IN) : SV_Target{
            float2 blurOffset = _offsets * (IN.uv - _ViewPortLightPos.xy);
float4 color = float4(0, 0, 0, 0);
for (int j = 0; j < RADIAL_SAMPLE_COUNT; j++)
{
    color += _MainTex.SampleLevel(sampler_MainTex, IN.uv, 0);
    IN.uv += blurOffset;
    // blurOffset += 0.001;
}
return color / RADIAL_SAMPLE_COUNT;
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
        float2 UV = IN.positionHCS.xy / _ScaledScreenParams.xy;
#if UNITY_REVERSED_Z
        real depth = SampleSceneDepth(UV);
#else
        real depth = lerp(UNITY_NEAR_CLIP_VALUE, 1, SampleSceneDepth(UV));
#endif

        float3 oCol = _MainTex.SampleLevel(sampler_MainTex, IN.uv, 0).rgb;
        float3 lCol = _FinalTex.SampleLevel(sampler_FinalTex, IN.uv, 0).rgb;
        oCol *= depth ? 0 : 1;
        float3 dCol = lCol + oCol * _Intensity * _MainLightColor; // 原图和计算后的图叠加

        return float4(dCol, 1);
    }
    ENDHLSL
}
}
}