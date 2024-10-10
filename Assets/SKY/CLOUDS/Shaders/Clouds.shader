/*
BASED ON URP CUSTOM POST PROCESSING;
REF:https://www.bilibili.com/read/cv17805609/#:~:text=%E6%89%BE%E5%88%B0%E9%A1%B9%E7%9B%AE%E4%B8%AD%E6%AD%A3%E5%9C%A8%E4%BD%BF%E7%94%A8%E7%9A%84PiplineAsset%E6%96%87%E4%BB%B6%EF%BC%88%E5%9C%A8Edit-%3EProjectSetting-%3EQuality-%3ERendering%E4%B8%8B%E5%8F%AF%E4%BB%A5%E6%89%BE%E5%88%B0%E9%A1%B9%E7%9B%AE%E6%AD%A3%E5%9C%A8%E4%BD%BF%E7%94%A8%E7%9A%84%E6%B8%B2%E6%9F%93%E7%AE%A1%E7%BA%BF%E6%96%87%E4%BB%B6%EF%BC%89%EF%BC%8C%E5%A6%82%E6%9E%9C%E6%B2%A1%E6%9C%89%E7%9A%84%E8%AF%9D%EF%BC%8C%E6%96%B0%E5%BB%BA%E4%B8%80%E4%B8%AAPipline%20Asset%EF%BC%88Project%E4%B8%8B%EF%BC%8C%E5%8F%B3%E9%94%AECreate-%3ERendering-%3EURP-%3EPipline%20Asset%EF%BC%89%2C%E5%88%9B%E5%BB%BA%E5%AE%8C%E6%88%90%E5%90%8E%EF%BC%8C%E9%A1%B9%E7%9B%AE%E4%B8%AD%E9%99%A4%E4%BA%86PiplineAsset%E6%96%87%E4%BB%B6%EF%BC%8C%E8%BF%98%E4%BC%9A%E5%A4%9A%E5%87%BA%E4%B8%80%E4%B8%AAForward,Renderer%E6%96%87%E4%BB%B6%EF%BC%8C%E5%9C%A8Forward%20Renderer%E6%96%87%E4%BB%B6%E4%B8%AD%E7%82%B9%E5%87%BBAdd%20Renderer%20Feature%EF%BC%8C%E5%B0%B1%E5%8F%AF%E4%BB%A5%E6%B7%BB%E5%8A%A0%E8%87%AA%E5%AE%9A%E4%B9%89%E7%9A%84%E5%90%8E%E5%A4%84%E7%90%86%E6%95%88%E6%9E%9C%E4%BA%86%E3%80%82
*/
Shader "Shaders/Clouds"
{
    Properties
    {
        _Basic3DTex("_Basic3DTex", 3D) = "white" {}
        _MainTex("_MainTex", 2D) = "white" {} // 存储用于后处理的原始屏幕画面
        _WeatherMap("_WeatherMap", 2D) = "white" {}
        _Detail3DTex("_Detail3DTex", 3D) = "white" {}
        _maskNoise("_maskNoise", 2D) = "white" {}
        _BlueNoise("_BlueNoise", 2D) = "white" {}
        _FinalTex("_BlueNoise", 2D) = "white" {}
    }
    SubShader
    {
        Tags{"RenderPipeline" = "UniversalPipeline"
                                "LightMode" = "UniversalForward"} Cull Off Zwrite Off ZTest Always
            HLSLINCLUDE
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "Assets/SKY/ATMOSPHERE/Shaders/Utils/Common.hlsl"

#define TAU (PI * 2.0)

#define MAX_MARCH_STEP 32
#define MAX_LIGHT_MARCH_STEP 8

            struct Attributes
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
        sampler2D _MainTex;
        float4 _MainTex_TexelSize;
        float4 _MainTex_ST;
        sampler3D _Basic3DTex;
        sampler3D _Detail3DTex;
        float3 _boundsMin;
        float3 _boundsMax;
        sampler2D _WeatherMap;
        float4 _WeatherMap_ST;
        sampler2D _maskNoise;
        float4 _maskNoise_ST;
        sampler2D _BlueNoise;
        float4 _BlueNoise_ST;
        sampler2D _FinalTex;

        float _shapeTune = 0.1;
        float _detailTune = 0.1;
        float _shapeSpeed = 0.05;
        float _detailSpeed = 0.05;
        float _weatherMapSpeed = 0.05;
        float _maskNoiseSpeed = 0.025;
        float _shapeTiling = 0.0002;
        float _heightWeights = 0.5;
        float4 _shapeNoiseWeights = float4(4, 50, -3.18, -20);
        float _densityOffset = -15;
        float _detailWeights = 2;
        float _densityMultiplier = 0.5;
        float _detailNoiseWeight = 0.5;
        float _weatherMapUvScale = 1;
        float _maskNoiseUvScale = 2.6;
        float _shapeNoiseUvScale = 0.5;
        float _detailNoiseUvScale = 3;
        float _cloudAbsorbTune = 4;
        CBUFFER_END

        Varings vert(Attributes IN)
        {
            Varings OUT;
            OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
            OUT.uv = IN.texcoord;
            return OUT;
        }

        //////////////////////////////////BILATERAL BLUR/////////////////
        float GaussianWeight(float d, float sigma)
        {
            return 1.0 / (sigma * sqrt(TAU)) * exp(-(d * d) / (2.0 * sigma * sigma));
        }

        float4 GaussianWeight2(float4 d, float sigma)
        {
            return 1.0 / (sigma * sqrt(TAU)) * exp(-(d * d) / (2.0 * sigma * sigma));
        }

        float4 BilateralWeight(float2 currentUV, float2 centerUV, float4 currentColor, float4 centerColor)
        {
            float _SpatialWeight = 0.003;
            float _TonalWeight = 0.5;

            float spacialDifference = length(centerUV - currentUV);
            float4 tonalDifference = centerColor - currentColor;
            return GaussianWeight2(tonalDifference, _TonalWeight) * GaussianWeight(spacialDifference, _SpatialWeight);
        }
        //////////////////////////////////////

        // 光在云中的折射，糖粉效应
        float BeerPowder(float depth)
        {
            return exp(-depth) * (1 - exp(-2 * depth)) * 2;
        }

        float remap(float original_value, float original_min, float original_max, float new_min, float new_max)
        {
            return new_min + (((original_value - original_min) / (original_max - original_min)) * (new_max - new_min));
        }

        float SampleDensity(float3 p)
        {
            float speedShape = _Time.y * _shapeSpeed;
            float speedDetail = _Time.y * _detailSpeed;
            float speedWeatherMap = _Time.y * _weatherMapSpeed;
            float speedmaskNoise = _Time.y * _maskNoiseSpeed;

            float3 uvwShape = p * _shapeTiling + float3(speedShape, speedShape * 0.2, 0);
            float3 uvwDetail = p * _shapeTiling + float3(speedDetail, speedDetail * 0.2, 0);

            float3 size = _boundsMax - _boundsMin;
            float2 uv = p.xz / float2(size.x, size.z);

            float4 weatherMap = tex2D(_WeatherMap, float4(TRANSFORM_TEX(uv, _WeatherMap) * _weatherMapUvScale + float2(speedWeatherMap, 0), 0, 0));
            float4 maskNoise = tex2D(_maskNoise, float4(TRANSFORM_TEX(uv, _maskNoise) * _maskNoiseUvScale + float2(speedmaskNoise, 0), 0, 0));
            float4 shapeNoise = tex3D(_Basic3DTex, float4(uvwShape * _shapeNoiseUvScale + maskNoise.r * _shapeTune, 0));
            float4 detailNoise = tex3D(_Detail3DTex, float4(uvwDetail * _detailNoiseUvScale + shapeNoise.r * _detailTune, 0));

            // 边缘衰减
            const float containerEdgeFadeDst = 300;
            float dstFromEdgeX = min(containerEdgeFadeDst, min(p.x - _boundsMin.x, _boundsMax.x - p.x));
            float dstFromEdgeZ = min(containerEdgeFadeDst, min(p.z - _boundsMin.z, _boundsMax.z - p.z));
            float edgeWeight = min(dstFromEdgeZ, dstFromEdgeX) / containerEdgeFadeDst;

            float gMin = remap(weatherMap.x, 0, 1, 0.1, 0.6);
            float gMax = remap(weatherMap.x, 0, 1, gMin, 0.9);
            float heightPercent = (p.y - _boundsMin.y) / size.y; // 获取高度占比
            float heightGradient = saturate(remap(heightPercent, 0.0, gMin, 0, 1)) * saturate(remap(heightPercent, 1, gMax, 0, 1));
            float heightGradient2 = saturate(remap(heightPercent, 0.0, weatherMap.r, 1, 0)) * saturate(remap(heightPercent, 0.0, gMin, 0, 1));
            heightGradient = saturate(lerp(heightGradient, heightGradient2, _heightWeights));

            heightGradient *= edgeWeight;

            float4 normalizedShapeWeights = _shapeNoiseWeights / dot(_shapeNoiseWeights, 1);
            float shapeFBM = dot(shapeNoise, normalizedShapeWeights) * heightGradient;
            float baseShapeDensity = shapeFBM + _densityOffset * 0.01;

            if (baseShapeDensity > 0)
            {
                float detailFBM = pow(detailNoise.r, _detailWeights);
                float oneMinusShape = 1 - baseShapeDensity;
                float detailErodeWeight = pow(oneMinusShape, 9);
                float cloudDensity = baseShapeDensity - detailFBM * detailErodeWeight * _detailNoiseWeight;
                return saturate(cloudDensity * _densityMultiplier);
            }

            return 0;
        }

        float2 RayBoxDst(float3 boundsMin, float3 boundsMax, float3 rayOrigin, float3 rayDir)
        // 获取射线原点到CloudsBox的最短距离和射线在CloudsBox内的距离
        // REF:https://jcgt.org/published/0007/03/04/
        {
            float3 invRaydir = 1 / rayDir;
            float3 t0 = (boundsMin - rayOrigin) * invRaydir;
            float3 t1 = (boundsMax - rayOrigin) * invRaydir;
            float3 tmin = min(t0, t1);
            float3 tmax = max(t0, t1);
            float dstA = max(max(tmin.x, tmin.y), tmin.z); // 进入点
            float dstB = min(tmax.x, min(tmax.y, tmax.z)); // 出去点
            float dstToBox = max(0, dstA);
            float dstInsideBox = max(0, dstB - dstToBox);
            return float2(dstToBox, dstInsideBox);
        }

        float LightMarching(float3 pos, float3 dir)
        {
            float dstInsideBox = RayBoxDst(_boundsMin, _boundsMax, pos, dir).y;
            float stepSize = dstInsideBox / MAX_LIGHT_MARCH_STEP;
            float3 light_step = dir * stepSize;
            float totalDensity = 0;
            for (int i = 0; i <= MAX_LIGHT_MARCH_STEP; i++)
            {
                totalDensity += max(0, SampleDensity(pos));
                pos += light_step;
            }
            return exp(-totalDensity * _cloudAbsorbTune);
        }

        float HenyeyGreenstein(float3 inLightVector, float3 inViewVector, float inG)
        {
            float cos_angle = dot(normalize(inLightVector), normalize(inViewVector));
            return ((1.0 - inG * inG) / pow((1.0 + inG * inG - 2.0 * inG * cos_angle), 3.0 / 2.0)) / 4.0 * 3.1415;
        }

        float2 CloudRayMarching(float3 stPoint, float3 dir, float dstLimit, float blueNoise)
        {
            float _MolarAbsorpCoe = 1;

            float totalDens = 1;
            float step = dstLimit / MAX_MARCH_STEP;
            float curStep = blueNoise * 250;
            float totalEnergy = 0;
            float3 curPos = stPoint;

            // Henyey-Greenstein Phase Function for scatter forward(silver lining effect)
            float phaseVal = HenyeyGreenstein(_MainLightPosition, dir, 0.1); // g = 0.1

            // [unroll(MAX_MARCH_STEP)]
            for (int i = 0; i < MAX_MARCH_STEP; i++)
            {
                if (curStep < dstLimit)
                {
                    curPos = stPoint + dir * curStep;

                    float dens = SampleDensity(curPos);
                    if (dens > 0)
                    {
                        totalEnergy += dens * step * LightMarching(curPos, _MainLightPosition) * BeerPowder(totalDens) * phaseVal; // empty 1
                        totalDens *= exp(-dens * step * _MolarAbsorpCoe);
                    }
                    curStep += step;
                }
            }
            return float2(totalDens, totalEnergy);
        }

        float4 frag(Varings IN) : SV_Target
        {
            // 屏幕空间深度采样，REF：https://docs.unity3d.com/Packages/com.unity.render-pipelines.universal@14.0/manual/writing-shaders-urp-reconstruct-world-position.html
            float2 UV = IN.positionHCS.xy / _ScaledScreenParams.xy;
#if UNITY_REVERSED_Z
            real depth = SampleSceneDepth(UV);
#else
            real depth = lerp(UNITY_NEAR_CLIP_VALUE, 1, SampleSceneDepth(UV));
#endif
            float3 worldPos = ComputeWorldSpacePosition(UV, depth, UNITY_MATRIX_I_VP);
            float3 worldViewDir = normalize(worldPos.xyz - _WorldSpaceCameraPos.xyz);

            float blueNoise = tex2D(_BlueNoise, IN.uv * 2);

            // RayMarching
            float2 boxDst = RayBoxDst(_boundsMin, _boundsMax, _WorldSpaceCameraPos, worldViewDir);
            float dstToBox = boxDst.x;
            float dstInsideBox = boxDst.y;
            float dstLimit = max(0, min(length(worldPos.xyz - _WorldSpaceCameraPos.xyz) - dstToBox, dstInsideBox)); // 射线在包围盒内的有效距离

            float2 totalTransmittance = CloudRayMarching((_WorldSpaceCameraPos + worldViewDir * dstToBox), worldViewDir, dstLimit, blueNoise);

            // float4 col = tex2D(_MainTex, IN.uv);
            // col.rgb *= totalTransmittance.x;
            // col.rgb += _MainLightColor * totalTransmittance.y;
            return float4(totalTransmittance.x, totalTransmittance.y * 0.42, 0, 1);
        }

        ENDHLSL

        Pass{
            HLSLPROGRAM
#pragma vertex vert
#pragma fragment frag
                ENDHLSL}
        Pass{
            HLSLPROGRAM
#pragma vertex vert
#pragma fragment blurFrag

                float4 blurFrag(Varings IN) : SV_Target{
                    // Kawase Blur:
                    //             float _BlurRange = _MainTex_TexelSize.xy * 0.7;
                    // float4 tex = tex2D(_MainTex, IN.uv); // 中心像素
                    // tex += tex2D(_MainTex, IN.uv + float2(-1, -1) * _BlurRange);
                    // tex += tex2D(_MainTex, IN.uv + float2(1, -1) * _BlurRange);
                    // tex += tex2D(_MainTex, IN.uv + float2(-1, 1) * _BlurRange);
                    // tex += tex2D(_MainTex, IN.uv + float2(1, 1) * _BlurRange);
                    // return tex / 5.0;

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
                    ///////////////////////////////////////////////////////////////////////////
                    // Bilateral Blur:
                    float _BlurRadius = 2;

        float4 numerator = float4(0, 0, 0, 0);
        float4 denominator = float4(0, 0, 0, 0);

        float4 centerColor = tex2D(_MainTex, IN.uv);

        for (int iii = -1; iii < 2; iii++)
        {
            for (int jjj = -1; jjj < 2; jjj++)
            {
                float2 offset = float2(iii, jjj) * _BlurRadius;

                float2 currentUV = IN.uv + offset * _MainTex_TexelSize.xy;
                float4 currentColor = tex2D(_MainTex, currentUV);

                float4 weight = BilateralWeight(currentUV, IN.uv, currentColor, centerColor);
                numerator += currentColor * weight;
                denominator += weight;
            }
        }

        return numerator / denominator;
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

        float4 oCol = tex2D(_MainTex, IN.uv);
        float4 lCol = tex2D(_FinalTex, IN.uv);

        float3 dCol = lCol.xyz * oCol.x + _MainLightColor.xyz * oCol.y + (1 - oCol.x) * _GlossyEnvironmentColor.xyz; // 原图和计算后的图叠加
        return float4(dCol.rgb, 1);
    }
    ENDHLSL
}
}
}