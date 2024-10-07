Shader "Shaders/CloudShadow"
{
    Properties{
        _MainTex("Texture", 2D) = "white" {} _CloudColor("Cloud Color", Color) = (1, 1, 1, 1)
            _SpeedX("Cloud SpeedX", Float) = 0.05 _SpeedY("Cloud SpeedY", Float) = 0.05} SubShader
    {
        Tags{
            "Queue" = "Transparent"
                      "IgnoreProjector" = "True"
                                          "ForceNoShadowCasting" = "True"}

        Pass
        {
            ZWrite Off
                ZTest Always
                    Blend Zero OneMinusSrcColor

                        CGPROGRAM
#pragma vertex vert
#pragma fragment frag

#include "UnityCG.cginc"

                struct v2f
            {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 ray : TEXCOORD1;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            half4 _CloudColor;
            half _SpeedX;
            half _SpeedY;
            half4 _WorldSpaceCameraRay;

            sampler2D _CameraDepthTexture;

            v2f vert(appdata_base v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = v.texcoord.xy;

                float3 pos_world = mul(unity_ObjectToWorld, v.vertex);
                o.ray = pos_world - _WorldSpaceCameraPos;
                return o;
            }

            fixed4 frag(v2f i) : SV_Target
            {

                float depth = Linear01Depth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, i.uv));
                float3 world = i.ray * depth + _WorldSpaceCameraPos;

                float2 world_uv = world.xz;
                float2 cloud_uv = world_uv * 0.005f;
                cloud_uv = (cloud_uv + _Time.y * float2(_SpeedX, _SpeedY)) * _MainTex_ST.xy;

                float cloud = tex2D(_MainTex, cloud_uv).r * (1 - depth);

                float4 col = float4((1 - _CloudColor.rgb) * cloud, 1.0);

                return col;
            }
            ENDCG
        }
    }
}