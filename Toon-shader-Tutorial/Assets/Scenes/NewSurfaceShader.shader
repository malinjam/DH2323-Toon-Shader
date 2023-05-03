Shader "Custom/NewSurfaceShader"
{
	
	Properties
	{
		_Color("Color", Color) = (1,1,1,1)
		_MainTex("Main Texture", 2D) = "white" {}

	[HDR]
		_AmbientColor("Ambient Color", Color) = (0.4,0.4,0.4,1)										//for ambient light on everything
	

	[HDR]																							//for specular highlights
		_SpecularColor("Specular Color", Color) = (0.9,0.9,0.9,1)
		_Glossiness("Glossiness", Float) = 32
	

	[HDR]
	_RimColor("Rim Color", Color) = (1,1,1,1)														//for rim light to define edges of the object
	_RimAmount("Rim Amount", Range(0, 1)) = 0.716
	_RimThreshold("Rim Threshold", Range(0, 1)) = 0.1
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
																									// to complie multiple versions of the shader depending on the lighting
			#pragma multi_compile_fwdbase
			
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
				SHADOW_COORDS(2)																	//shadow coordinates
			};

			sampler2D _MainTex;
			float4 _MainTex_ST;

																									//vertex shader
			v2f vert (appdata v)
			{
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				o.worldNormal = UnityObjectToWorldNormal(v.normal);
				o.uv = TRANSFORM_TEX(v.uv, _MainTex);
				o.viewDir = WorldSpaceViewDir(v.vertex);
				TRANSFER_SHADOW(o)
				return o;
			}

			float4 _Color;

			float4 _AmbientColor;																	//variable for ambiance

			float _Glossiness;																		//variables for gloss
			float4 _SpecularColor;

			float4 _RimColor;																		//variables for the rimlight
			float _RimAmount;
			float _RimThreshold;																	//for controlling the size of the rim edge

			float4 frag (v2f i) : SV_Target															//fragment shader
			{
				
				float3 normal = normalize(i.worldNormal);
				float NdotL = dot(_WorldSpaceLightPos0, normal);
				float shadow = SHADOW_ATTENUATION(i);												//casts shadows
				float lightIntensity = smoothstep(0, 0.01, NdotL * shadow);							//flattens shadows (removes airbrush effect) and incorporates ambient light and shadows casted from other objects
				float4 light = lightIntensity * _LightColor0;										//smooth step interpolates between two given numbers (0 and 1) this smothes out any jagged edges
																									//light calculation includes _LightCOlor0 to allow changes in the directional light color
				float3 viewDir = normalize(i.viewDir);
				float3 halfVector = normalize(_WorldSpaceLightPos0 + viewDir);						//the vector between the viewing direction and the light source

				float NdotH = dot(normal, halfVector);

				float specularIntensity = pow(NdotH * lightIntensity, _Glossiness * _Glossiness);	//calculated the size of the glossy spec
				float specularIntensitySmooth = smoothstep(0.005, 0.01, specularIntensity);			//interpolates for specular intensity
				float4 specular = specularIntensitySmooth * _SpecularColor;							//creates a sharper edge for the toon style

				float4 rimDot = 1 - dot(viewDir, normal);											//variable for rimlight size
				float rimIntensity = rimDot * pow(NdotL, _RimThreshold);;							//initialises rim size to be on the illuminated side of the object pow(decides length of the edge)
				rimIntensity = smoothstep(_RimAmount - 0.01, _RimAmount + 0.01, rimIntensity);		//for harsher rim edge for the toon effect
				float4 rim = rimIntensity * _RimColor;												//to incorporate rim color

				float4 sample = tex2D(_MainTex, i.uv);

				return _Color * sample * (_AmbientColor + light + specular + rim);				//final colour returned based on sample, and taking into consideration, ambience, light intensity adn specular gloss
			}
			ENDCG
		}
		//to cast shadows onto other objects in the scene we are adding the Pass from the shading step in unity's rendering process
		UsePass "Legacy Shaders/VertexLit/SHADOWCASTER"
	}
}