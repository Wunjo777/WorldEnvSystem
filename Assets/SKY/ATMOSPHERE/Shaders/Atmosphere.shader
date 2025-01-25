Shader "Shaders/Atmosphere"
{
    Properties {}
    SubShader
    {
        Tags
        {
            "Queue" = "Background"
            "RenderType" = "Background"
            "RenderPipeline" = "UniversalPipeline"
            "PreviewType" = "Skybox"
        } Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #define MAX_MARCH_STEP 32

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
            #include "Assets/SKY/ATMOSPHERE/Shaders/Utils/AtmosMath.hlsl"
            #include "Assets/SKY/ATMOSPHERE/Shaders/Utils/Common.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
            };

            Texture2D _TransmittanceLut;
            SamplerState sampler_TransmittanceLut;
            Texture2D _MultiscatteringLut;
            SamplerState sampler_MultiscatteringLut;

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                float2 UV = IN.positionHCS.xy / _ScaledScreenParams.xy;
                #if UNITY_REVERSED_Z
                real depth = SampleSceneDepth(UV);
                #else
                real depth = lerp(UNITY_NEAR_CLIP_VALUE, 1, SampleSceneDepth(UV));
                #endif
                float3 worldPos = ComputeWorldSpacePosition(UV, depth, UNITY_MATRIX_I_VP);
                float3 worldViewDir = normalize(worldPos.xyz - _WorldSpaceCameraPos.xyz);

                /*********************/
                // 视线和大气交点
                float rayLength = RaySphereIntersection(_WorldSpaceCameraPos.xyz, worldViewDir, PlanetCenter,
                                                      _AtmosphereRadius).y;

                // float rayLength = atmosIntersection.y;
                float groundIntersec = RaySphereIntersection(_WorldSpaceCameraPos.xyz, worldViewDir, PlanetCenter,
         _PlanetRadius).x;
                if (groundIntersec > 0)
                    rayLength = min(rayLength, groundIntersec);
                // return 0.01;
                /*********************/
                float3 totalResult = float3(0, 0, 0);
                float step = rayLength / MAX_MARCH_STEP;
                float3 p = _WorldSpaceCameraPos.xyz + worldViewDir * step * 0.5;
                float3 dpa = 0;
                float3 MainLightDirection = normalize(_MainLightPosition.xyz);
                for (int i = 0; i < MAX_MARCH_STEP; i++)
                {
                    #ifdef SINGLESCATTERING
                    // calculate t1
                    #ifdef TEMPORALCALCULATION
                    //////////////This is the original method of calculating dcp:
                    // float dis = RaySphereIntersection(p, MainLightDirection, PlanetCenter, _AtmosphereRadius).y;
                    // float3 c = p + MainLightDirection * (dis + 0.000000001); // 增加微小偏移，防止噪点
                    // float2 dcp = calOpticalDepth(HR_HM, _PlanetRadius, p, c);

                    //////////////This is the brand new method of calculating dcp:
                    float r = length(p - PlanetCenter);
                    float3 upVector = normalize(p - PlanetCenter);
                    float mu = dot(upVector, MainLightDirection);
                    float3 t1 = calOpticalDepthLut(r, mu);
                    #endif
                    #ifdef SAMPLELUT
                    float r = length(p - PlanetCenter);
                    float3 upVector = normalize(p - PlanetCenter);
                    float mu = dot(upVector, MainLightDirection);
                    float2 transLutUv = GetTransmittanceLutUv(_PlanetRadius, _AtmosphereRadius, r, mu);
                    float3 t1 = _TransmittanceLut.SampleLevel(sampler_TransmittanceLut, transLutUv, 0).xyz;
                    #endif
                    // calculate t2
                    float h = abs(length(p - PlanetCenter) - _PlanetRadius);
                    float2 dens = calDensity(p);
                    dpa += (dens.x * RayleighCoefficient + dens.y * (MieCoefficient + MieAbsorptionCoefficient) +
                        OzoneAbsorption(h)) * step;
                    float3 t2 = exp(-dpa);

                    // calculate scattering
                    float2 locDens = calDensity(p);
                    float cos = dot(MainLightDirection, worldViewDir);
                    float3 scatteringR = locDens.x * RayleighCoefficient * RayleiPhase(cos);
                    float3 scatteringM = locDens.y * MieCoefficient * MiePhase(cos);
                    float3 s = scatteringR + scatteringM;
                    float3 tmpResult = t1 * s * t2 * step;
                    totalResult += tmpResult;
                    #endif
                    #ifdef MULTISCATTERING
                    #ifdef TEMPORALCALCULATION
                    float3 G_All = calMultiscatteringLut(p, MainLightDirection, _TransmittanceLut, sampler_TransmittanceLut);
                    float3 sigma_s = locDens.x * RayleighCoefficient + locDens.y * MieCoefficient;

                    totalResult += G_All * sigma_s * t2 * step;
                    #endif
                    #ifdef SAMPLELUT
                    float cosSunZenithAngle = dot(normalize(p - PlanetCenter), MainLightDirection);
                    float2 MulScaUv = float2(cosSunZenithAngle * 0.5 + 0.5, h / (_AtmosphereRadius - _PlanetRadius));
                    float3 G_All = _MultiscatteringLut.SampleLevel(sampler_MultiscatteringLut, MulScaUv, 0).rgb;

                    float3 sigma_s = locDens.x * RayleighCoefficient + locDens.y * MieCoefficient;
                    totalResult += G_All * sigma_s * t2 * step;
                    #endif
                    #endif
                    p += worldViewDir * step;
                }
                totalResult *= _MainLightColor.rgb * ScatterEffectIntensity;
                return float4(totalResult.rgb, 1);
            }
            ENDHLSL
        }
    }
}