Shader "Custom/Ward"
{
    Properties
    {
        _Color ("Color", Color) = (1,1,1,1)
		_ps ("ps", float) = 0.0
		_pd ("pd", float) = 0.0
		_roughness("Roughness", float) = 0.0
        _MainTex ("Albedo (RGB)", 2D) = "white" {}
		[HDR]
		_AmbientColor("Ambient Color", Color) = (0.4,0.4,0.4,1)	
    }

    SubShader
    {

		Pass
		{
																									// Setup for the pass to use Forward rendering, and only take data from main directional light and ambient light.
			Tags
			{
				"LightMode" = "ForwardBase"
				"PassFlags" = "OnlyDirectional"
			}

			CGPROGRAM
				#pragma vertex vert
				#pragma fragment frag

				#include "UnityCG.cginc"
				#include "Lighting.cginc"																//needed for ambient light
				#include "AutoLight.cginc"																//needed to cast shadows on other objects in the scene

				struct appdata
				{
					float4 vertex : POSITION;				
					float4 uv : TEXCOORD0;
					float3 normal : NORMAL;
				};

				struct v2f
				{
					float4 pos : SV_POSITION;
					float3 worldNormal : NORMAL;
					float2 uv : TEXCOORD0;
					float3 viewDir : TEXCOORD1;
					SHADOW_COORDS(2)																	
				};
				
				v2f vert (appdata v)
				{
					v2f o;
					o.pos = UnityObjectToClipPos(v.vertex);
					o.worldNormal = UnityObjectToWorldNormal(v.normal);
					o.viewDir = WorldSpaceViewDir(v.vertex);
					TRANSFER_SHADOW(o)
					return o;
				}

				float4 _Color, _AmbientColor;
				float _ps, _pd, _roughness;

				float4 frag (v2f i) : SV_Target															//fragment shader
				{
					float3 normal = normalize(i.worldNormal);											//Surface Normal
					float3 viewDirection = normalize(i.viewDir);					//View Vector
					float3 lightDirection = normalize(_WorldSpaceLightPos0 );					//Light Vector		
					float3 halfVector = normalize(viewDirection + lightDirection);					//Halfway vector

					float3 specularReflection;

					float dotLN = dot(lightDirection, normal); 

					float shadow = SHADOW_ATTENUATION(i);												//casts shadows
					float lightIntensity = smoothstep(0, 0.01, dotLN * shadow);							//flattens shadows (removes airbrush effect) and incorporates ambient light and shadows casted from other objects
					float4 light = lightIntensity * _LightColor0;
					if (dotLN < 0.0) // light source on the wrong side?
					{
						float diffuse = _pd / 3.1415;
						specularReflection = float3(0.0, 0.0, 0.0); // no specular reflection
					}
					else // light source on the right side
					{
						float phi_i = dotLN;
						float phi_o = dot(viewDirection, normal);
						float phi_h = acos(dot(halfVector, normal));

						float diffuse = _pd / 3.1415;
						float specular = _ps / (4 * 3.1415 * pow(_roughness, 2) * sqrt(cos(phi_i) * cos(phi_o)));
						specularReflection = diffuse + specular * exp(-(pow(tan(phi_h),2.0) / pow(_roughness,2.0)));
					}

					return float4(_Color * (specularReflection + _AmbientColor + light), 1.0);
				}
			ENDCG
		}
    }
    FallBack "Diffuse"
}