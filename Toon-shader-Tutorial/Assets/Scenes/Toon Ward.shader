Shader "Custom/ToonWard"
{
    Properties
    {
        _Color ("Color", Color) = (1,1,1,1)
		_ps ("ps", float) = 0.0
		_pd ("pd", float) = 0.0
		_roughness("Roughness", float) = 0.0

		[HDR]
		_AmbientColor("Ambient Color", Color) = (0.4,0.4,0.4,1)	
		
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
					
				float4 _RimColor;																		//variables for the rimlight
				float _RimAmount;
				float _RimThreshold;																	//for controlling the size of the rim edge

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
					float4 rim = 0.0;
					float specularIntensitySmooth;
					if (dotLN < 0.0) // light source on the wrong side?
					{
						float diffuse = _pd / 3.1415;
						specularReflection = float3(0.0, 0.0, 0.0); // no specular reflection
						specularIntensitySmooth = specularReflection;
					}
					else // light source on the right side
					{
						float phi_i = dotLN;
						float phi_o = dot(viewDirection, normal);
						float phi_h = acos(dot(halfVector, normal));

						float diffuse = _pd / 3.1415;

						if(_roughness == 0){
							_roughness = 0.0001;
						}

						//Original specular reflection, using the Ward Model. This code provide us the specular reflection in a given pixel, however we need to 
						//play with these values to make it toonish. We need to make the transition to the glossy part 'sharper' to make it look toonish, however, we
						//also want to be able to modify such 'sharpness' in order to study it in our perception study. We explain the steps to reach there further below.
						float specular = _ps / (4 * 3.1415 * pow(_roughness, 2) * sqrt(cos(phi_i) * cos(phi_o)));
						float originalReflection = diffuse + specular * exp(-(pow(tan(phi_h),2.0) / pow(_roughness ,2.0)));

						//Toon SPECULAR REFLECTION

						//The rougher the material, the more light it will diffuse. The less rougher, the more glossier it is. 

						//Number of bands (this simulates a sharper or not as sharper transition to the glossy part). If there are more bands, then the transition is less sharp
						//There should be more bands if the material is rougher, since it is less glossy, and therefore, should have a less sharper transition
						//float bandNumber = floor( _roughness  * 10) / 10;

						float bandNumber = floor( _roughness  * 10);

						//The glossiest part of the material is achieved when the dot product of the halfVector and the surface normal is 1 (they are perpendicular).
						//We simulate this values here, in order to know how much light we will recieve from this part. And we'll later use it as the maximum threshold.
						//Therefore, we set tan(0) instead of tan(phi_h), since phi_h (which is the acos of the dot product between the halfVector and the normal (1.0f) --> and therefore is value will be 0.0f).
						float totalReflection = diffuse + specular * exp(-(pow(tan(0),2.0) / pow(_roughness ,2.0)));

						//We perform the same, but now for the less glossiest part. It will serve us as the minimum threshold. In here we set tan(1) instead, as phi_h value will be 0 in the less glossiest part of the material
						float noReflection = diffuse + specular * exp(-(pow(tan(1),2.0) / pow(_roughness ,2.0)));

						//Now we get the difference between the thresholds, and divide it by the number of bands. Our goal is to make it look toonish, therefore the transition
						//Between bands needs to be sharp, but such sharpness is dependant on the _roughness of the material
						float diff = (totalReflection - noReflection) / bandNumber;


						//We now group our pixel in one of our bands, depending on whose value is closer to
						if(bandNumber == 0){
							specularReflection = noReflection;
						}else{
							for(int i=0; i < bandNumber; i++){
								float aboveThreshold = noReflection + diff * (i + 1);
								float belowThreshold = noReflection + diff * i;
								
								if (originalReflection >= belowThreshold && (originalReflection < aboveThreshold)){
									float diffBelow = abs(originalReflection - belowThreshold);
									float diffAbove = abs(originalReflection - aboveThreshold);
									if( diffBelow <= diffAbove){
										specularReflection = belowThreshold;
									}else{
										specularReflection = aboveThreshold;
									}
								}
						}

							/*
							if( (originalReflection > noReflection + diff * i) && (originalReflection < noReflection + diff * (i+1))){
								specularReflection = noReflection + diff * i;
							}*/
						}


						/* ORIGINAL WARD MODEL SPECULAR REFLECTION
						float specular = _ps / (4 * 3.1415 * pow(_roughness, 2) * sqrt(cos(phi_i) * cos(phi_o)));
						float totalReflection = diffuse + specular * exp(-(pow(tan(phi_h),2.0) / pow(_roughness ,2.0))); 	//tan(0) was originally tan(phi_h)
						specularReflection = totalReflection ;
						*/
						float4 rimDot = 1 - dot(viewDirection, normal);											//variable for rimlight size
						float rimIntensity = rimDot * pow(dotLN, _RimThreshold);								//initialises rim size to be on the illuminated side of the object pow(decides length of the edge)
						rimIntensity = smoothstep(_RimAmount - 0.01, _RimAmount + 0.01, rimIntensity);			//for harsher rim edge for the toon effect
						rim = rimIntensity * _RimColor;		
					}

					return float4(_Color * (specularReflection + _AmbientColor + light + rim), 1.0);
				}
			ENDCG
		}
    }
    FallBack "Diffuse"
}
