Shader "Custom/MyFresnelInstanced" {
	Properties {
		_BaseMap("BaseMap", 2D) = "white"{} // r for texture base, g for unknown, b for mask
		_FresnelPower("Fresnel Power", Range(0,10)) = 5
		[HDR]_OuterColor("Fresnel Outer Color",Color) = (1,1,1,1)
		[HDR]_InnerColor("Fresnel Inner Color",Color) = (1,1,1,1)
//		//blend Mode
//        [Enum(UnityEngine.Rendering.BlendMode)]_SrcBlend ("Src Blend", float) = 1
//        [Enum(UnityEngine.Rendering.BlendMode)]_DstBlend ("Dst Blend", float) = 1
//        //Z write
//        [Enum(Off, 0, On, 1)] _ZWrite ("Z Write", Float) = 1
//        [Enum(Off, 0, On, 1)] _CullMode ("Cull Mode", Float) = 1
	}
	SubShader {
		Tags { "RenderType"="Opaque" "RenderPipeline"="UniversalPipeline" }
 
		HLSLINCLUDE
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareOpaqueTexture.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
			
			CBUFFER_START(UnityPerMaterial)
			float4 _BaseMap_ST;
			float _FresnelPower;
			float4 _OuterColor;
			float4 _InnerColor;
			CBUFFER_END

			//#include_with_pragmas "Packages/com.unity.render-pipelines.universal/Shaders/Particles/ParticlesUnlitInput.hlsl"
            //#include_with_pragmas "Packages/com.unity.render-pipelines.universal/Shaders/Particles/ParticlesUnlitForwardPass.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/ParticlesInstancing.hlsl"
		ENDHLSL
 
		Pass {
			Tags { "LightMode"="UniversalForward" "Queue" = "Geometry" }
			
			//Blend SrcAlpha OneMinusSrcAlpha
			ZWrite On
			Cull Off
			
			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_instancing
			#pragma instancing_options procedural:ParticleInstancingSetup
			#define UNITY_INSTANCING_ENABLED
			UNITY_INSTANCING_BUFFER_START(Props)
                UNITY_DEFINE_INSTANCED_PROP(half4,_Color)
            UNITY_INSTANCING_BUFFER_END(Props)
 
			struct Attributes {
				float4 positionOS	: POSITION;
				float2 uv		: TEXCOORD0;
				float3 normalOS   : NORMAL;
				float4 color : COLOR;
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};
 
			struct Varyings {
				float4 positionCS 	: SV_POSITION;
				float2 uv		: TEXCOORD0;
				float4 positionScr : TEXCOORD1;
				float3 normalWS : TEXCOORD2;
				float3 positionWS : TEXCOORD3;
				float4 color: COLOR;
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};
			TEXTURE2D(_BaseMap);
			SAMPLER(sampler_BaseMap);

			// Get Particle color from custom vertex streams
			half4 GetParticleColor(half4 color)
			{
			#if defined(UNITY_PARTICLE_INSTANCING_ENABLED)
			#if !defined(UNITY_PARTICLE_INSTANCE_DATA_NO_COLOR)
			    UNITY_PARTICLE_INSTANCE_DATA data = unity_ParticleInstanceData[unity_InstanceID];
			    color = lerp(half4(1.0, 1.0, 1.0, 1.0), color, unity_ParticleUseMeshColors);
			    color *= half4(UnpackFromR8G8B8A8(data.color));
			#endif
			#endif
			    return color;
			}
 
			Varyings vert(Attributes IN) {
				Varyings OUT;
				UNITY_SETUP_INSTANCE_ID(IN);
				half4 color = GetParticleColor(IN.color);
				UNITY_TRANSFER_INSTANCE_ID(IN, OUT);
				
				OUT.positionCS = TransformObjectToHClip(IN.positionOS.xyz);
				OUT.positionWS = TransformObjectToWorld(IN.positionOS.xyz);

				OUT.normalWS = normalize(TransformObjectToWorldNormal(IN.normalOS));
				OUT.uv = TRANSFORM_TEX(IN.uv, _BaseMap);
				OUT.color = color;
				
				return OUT;
			}

			float FresnelTerm(float3 viewDir, float3 normal, float power) {
				return pow(1.0 - saturate(dot(viewDir, normal)), power);
			}
 
			half4 frag(Varyings IN) : SV_Target {
				UNITY_SETUP_INSTANCE_ID(IN);
				
				half4 baseMap = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, IN.uv);

				float3 viewDir = normalize(_WorldSpaceCameraPos - IN.positionWS);
				float fresnel = FresnelTerm(viewDir, IN.normalWS, _FresnelPower);
				
				float4 finalColor = baseMap * lerp(_InnerColor, _OuterColor, fresnel) * IN.color; // Fresnel color * Vertex color * texture
				
				//return float4(linearDepth2.xxx,1);
				return finalColor;
			}
			ENDHLSL
		}

		// ShadowCaster, for casting shadows
//		Pass {
//			Name "ShadowCaster"
//			Tags { "LightMode"="ShadowCaster" }
//
//			ZWrite On
//			ZTest LEqual
//			Cull Off
//			
////			Stencil
////			{
////			    Ref 1
////			    Comp Always
////			    Pass Replace
////			}
//
//			HLSLPROGRAM
//			#pragma vertex ShadowPassVertex
//			#pragma fragment ShadowPassFragment
//			
//			// Material Keywords
//			#pragma shader_feature_local_fragment _ALPHATEST_ON
//			#pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
//
//			// GPU Instancing
//			#pragma multi_compile_instancing
//			//#pragma multi_compile _ DOTS_INSTANCING_ON
//
//			// Universal Pipeline Keywords
//			// (v11+) This is used during shadow map generation to differentiate between directional and punctual (point/spot) light shadows, as they use different formulas to apply Normal Bias
//			#pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW
//
//			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
//			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"
//			#include "Packages/com.unity.render-pipelines.universal/Shaders/ShadowCasterPass.hlsl"
//
//			// Note if we do any vertex displacement, we'll need to change the vertex function. e.g. :
//			/*
//			#pragma vertex DisplacedShadowPassVertex (instead of ShadowPassVertex above)
//			
//			Varyings DisplacedShadowPassVertex(Attributes input) {
//				Varyings output = (Varyings)0;
//				UNITY_SETUP_INSTANCE_ID(input);
//				
//				// Example Displacement
//				input.positionOS += float4(0, _SinTime.y, 0, 0);
//				
//				output.uv = TRANSFORM_TEX(input.texcoord, _BaseMap);
//				output.positionCS = GetShadowPositionHClip(input);
//				return output;
//			}
//			*/
//			ENDHLSL
//		}
//
//		// DepthOnly, used for Camera Depth Texture (if cannot copy depth buffer instead, and the DepthNormals below isn't used)
//		Pass {
//			Name "DepthOnly"
//			Tags { "LightMode"="DepthOnly" }
//
//			ColorMask 0
//			ZWrite On
//			ZTest LEqual
//			Cull Off
//
//			HLSLPROGRAM
//			#pragma vertex DepthOnlyVertex
//			#pragma fragment DepthOnlyFragment
//
//			// Material Keywords
//			#pragma shader_feature_local_fragment _ALPHATEST_ON
//			#pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
//
//			// GPU Instancing
//			#pragma multi_compile_instancing
//			//#pragma multi_compile _ DOTS_INSTANCING_ON
//
//			TEXTURE2D(_WindNoise);
//			SAMPLER(sampler_WindNoise);
//
//			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
//			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"
//			#include "Packages/com.unity.render-pipelines.universal/Shaders/DepthOnlyPass.hlsl"
//
//			// Note if we do any vertex displacement, we'll need to change the vertex function. e.g. :
//			
//			// Varyings DisplacedDepthOnlyVertex(Attributes input) {
//			// 	Varyings output = (Varyings)0;
//			// 	UNITY_SETUP_INSTANCE_ID(input);
//			// 	UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);
//			// 	
//			// 	// Example Displacement
//			// 	input.positionOS += float4(0, _SinTime.y, 0, 0);
//			// 	
//			// 	output.uv = TRANSFORM_TEX(input.texcoord, _BaseMap);
//			// 	output.positionCS = TransformObjectToHClip(input.position.xyz);
//			// 	return output;
//			// }
//			
//			ENDHLSL
//		}
//
//		// DepthNormals, used for SSAO & other custom renderer features that request it
//		Pass {
//			Name "DepthNormals"
//			Tags { "LightMode"="DepthNormals" }
//
//			ZWrite On
//			Cull Off
//			ZTest LEqual
//
//			HLSLPROGRAM
//			#pragma vertex DepthNormalsVertex
//			#pragma fragment DepthNormalsFragment
//
//			// Material Keywords
//			#pragma shader_feature_local _NORMALMAP
//			#pragma shader_feature_local_fragment _ALPHATEST_ON
//			#pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
//
//			// GPU Instancing
//			#pragma multi_compile_instancing
//			//#pragma multi_compile _ DOTS_INSTANCING_ON
//
//			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
//			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"
//			#include "Packages/com.unity.render-pipelines.universal/Shaders/DepthNormalsPass.hlsl"
//
//			// Note if we do any vertex displacement, we'll need to change the vertex function. e.g. :
//			/*
//			#pragma vertex DisplacedDepthNormalsVertex (instead of DepthNormalsVertex above)
//
//			Varyings DisplacedDepthNormalsVertex(Attributes input) {
//				Varyings output = (Varyings)0;
//				UNITY_SETUP_INSTANCE_ID(input);
//				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);
//				
//				// Example Displacement
//				input.positionOS += float4(0, _SinTime.y, 0, 0);
//				
//				output.uv = TRANSFORM_TEX(input.texcoord, _BaseMap);
//				output.positionCS = TransformObjectToHClip(input.position.xyz);
//				VertexNormalInputs normalInput = GetVertexNormalInputs(input.normal, input.tangentOS);
//				output.normalWS = NormalizeNormalPerVertex(normalInput.normalWS);
//				return output;
//			}
//			*/
//			
//			ENDHLSL
//		}
	}
}