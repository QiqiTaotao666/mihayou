using System;
using UnityEngine;
using UnityEditor.Rendering;
using UnityEditor.Rendering.Universal.ShaderGUI;

namespace UnityEditor
{
    public class ThrilLayerPBRShaderGUI : BaseShaderGUI
    {
        private enum Foldout
        {
            SecondLayer = 1 << 4,
            TopLayer = 1 << 5,
            Stencil = 1 << 6,
        }

        private static readonly GUIContent secondLayerHeader = new GUIContent("Second Layer", "第二层三平面材质混合参数。");
        private static readonly GUIContent topLayerHeader = new GUIContent("Top Layer", "顶部覆盖层参数，受顶点色 R、高度和朝上权重共同控制。");
        private static readonly GUIContent secondMapText = new GUIContent("Albedo", "第二层颜色贴图。纹理 Offset 生效，三平面缩放请使用 Tiling。 ");
        private static readonly GUIContent secondMetallicText = new GUIContent("Metallic/AO/Smoothness", "第二层金属度(R) / AO(G) / Smoothness(A) 贴图。");
        private static readonly GUIContent secondNormalText = new GUIContent("Normal Map", "第二层法线贴图。右侧数值控制法线强度。");
        private static readonly GUIContent secondTilingText = new GUIContent("Tiling", "第二层三平面采样密度。");
        private static readonly GUIContent secondSharpnessText = new GUIContent("Sharpness", "第二层三平面投射权重锐度。");
        private static readonly GUIContent topMapText = new GUIContent("Albedo", "顶部层颜色贴图。纹理 Offset 生效，三平面缩放请使用 Tiling。");
        private static readonly GUIContent topMetallicText = new GUIContent("Metallic/AO/Smoothness", "顶部层金属度(R) / AO(G) / Smoothness(A) 贴图。");
        private static readonly GUIContent topNormalText = new GUIContent("Normal Map", "顶部层法线贴图。右侧数值控制法线强度。");
        private static readonly GUIContent topTilingText = new GUIContent("Tiling", "顶部层三平面采样密度。");
        private static readonly GUIContent topSharpnessText = new GUIContent("Sharpness", "顶部层三平面投射权重锐度。");
        private static readonly GUIContent topHeightMinText = new GUIContent("Height Min", "顶部层开始生效的世界高度。");
        private static readonly GUIContent topHeightMaxText = new GUIContent("Height Max", "顶部层完全生效的世界高度。");
        private static readonly GUIContent topUpMinText = new GUIContent("Up Min", "法线朝上权重的起始阈值。");
        private static readonly GUIContent topUpMaxText = new GUIContent("Up Max", "法线朝上权重的结束阈值。");
        private static readonly GUIContent opacityText = new GUIContent("Opacity", "整体透明度。");
        private static readonly GUIContent additionalShadowText = new GUIContent("USE Additional Shadow", "启用额外方向光阴影。");
        private static readonly GUIContent renderQueueText = new GUIContent("Render Queue", "渲染队列值，例如 Geometry=2000、AlphaTest=2450、Transparent=3000。");

        private LitGUI.LitProperties litProperties;

        private MaterialProperty opacity;
        private MaterialProperty castShadows;
        private MaterialProperty useAdditionalShadow;
        private MaterialProperty zTest;
        private MaterialProperty queueOffset;

        private MaterialProperty secondMap;
        private MaterialProperty secondMetallicGlossMap;
        private MaterialProperty secondNormalMap;
        private MaterialProperty secondMapScale;
        private MaterialProperty secondTilling;
        private MaterialProperty secondSharpness;

        private MaterialProperty topMap;
        private MaterialProperty topMetallicGlossMap;
        private MaterialProperty topNormalMap;
        private MaterialProperty topMapScale;
        private MaterialProperty topTilling;
        private MaterialProperty topSharpness;
        private MaterialProperty topHeightMin;
        private MaterialProperty topHeightMax;
        private MaterialProperty topUpMin;
        private MaterialProperty topUpMax;

        private MaterialProperty stencilRef;
        private MaterialProperty stencilComp;
        private MaterialProperty stencilPass;
        private MaterialProperty stencilFail;
        private MaterialProperty stencilZFail;
        private MaterialProperty stencilReadMask;
        private MaterialProperty stencilWriteMask;

        public override void FindProperties(MaterialProperty[] properties)
        {
            base.FindProperties(properties);
            litProperties = new LitGUI.LitProperties(properties);

            opacity = FindProperty("_Opacity", properties, false);
            castShadows = FindProperty("_CastShadows", properties, false);
            useAdditionalShadow = FindProperty("_USEAdditionalShadow", properties, false);
            zTest = FindProperty("_ZTest", properties, false);
            queueOffset = FindProperty("_QueueOffset", properties, false);

            secondMap = FindProperty("_SecondMap", properties, false);
            secondMetallicGlossMap = FindProperty("_SecondMetallicGlossMap", properties, false);
            secondNormalMap = FindProperty("_SecondNoamalMap", properties, false);
            secondMapScale = FindProperty("_SecondMapScale", properties, false);
            secondTilling = FindProperty("_SecondTilling", properties, false);
            secondSharpness = FindProperty("_Secondsharpness", properties, false);

            topMap = FindProperty("_TopMap", properties, false);
            topMetallicGlossMap = FindProperty("_TopMetallicGlossMap", properties, false);
            topNormalMap = FindProperty("_TopNormalMap", properties, false);
            topMapScale = FindProperty("_TopMapScale", properties, false);
            topTilling = FindProperty("_TopTilling", properties, false);
            topSharpness = FindProperty("_Topsharpness", properties, false);
            topHeightMin = FindProperty("_TopHeightMin", properties, false);
            topHeightMax = FindProperty("_TopHeightMax", properties, false);
            topUpMin = FindProperty("_TopUpMin", properties, false);
            topUpMax = FindProperty("_TopUpMax", properties, false);

            stencilRef = FindProperty("_StencilRef", properties, false);
            stencilComp = FindProperty("_StencilComp", properties, false);
            stencilPass = FindProperty("_StencilPass", properties, false);
            stencilFail = FindProperty("_StencilFail", properties, false);
            stencilZFail = FindProperty("_StencilZFail", properties, false);
            stencilReadMask = FindProperty("_StencilReadMask", properties, false);
            stencilWriteMask = FindProperty("_StencilWriteMask", properties, false);
        }

        public override void ValidateMaterial(Material material)
        {
            if (material == null)
                throw new ArgumentNullException(nameof(material));

            SetMaterialKeywords(material, LitGUI.SetMaterialKeywords);

            if (material.HasProperty("_QueueOffset"))
            {
                int customQueue = (int)material.GetFloat("_QueueOffset");
                if (customQueue > 0)
                    material.renderQueue = customQueue;
            }

            if (material.HasProperty("_CastShadows"))
            {
                bool cast = material.GetFloat("_CastShadows") >= 0.5f;
                material.SetShaderPassEnabled("ShadowCaster", cast);
                material.SetShaderPassEnabled("AdditionalDirDepthOnly", cast);
            }
        }

        public override void DrawSurfaceOptions(Material material)
        {
            if (material == null)
                throw new ArgumentNullException(nameof(material));

            EditorGUIUtility.labelWidth = 0f;

            EditorGUI.BeginChangeCheck();
            if (litProperties.workflowMode != null)
                DoPopup(LitGUI.Styles.workflowModeText, litProperties.workflowMode, Enum.GetNames(typeof(LitGUI.WorkflowMode)));
            if (EditorGUI.EndChangeCheck())
            {
                foreach (var obj in materialEditor.targets)
                    ValidateMaterial((Material)obj);
            }

            base.DrawSurfaceOptions(material);

            if (opacity != null)
                materialEditor.ShaderProperty(opacity, opacityText);

            if (castShadows != null)
            {
                EditorGUI.BeginChangeCheck();
                materialEditor.ShaderProperty(castShadows, Styles.castShadowText);
                if (EditorGUI.EndChangeCheck())
                {
                    bool cast = castShadows.floatValue >= 0.5f;
                    foreach (var obj in materialEditor.targets)
                    {
                        Material mat = (Material)obj;
                        mat.SetShaderPassEnabled("ShadowCaster", cast);
                        mat.SetShaderPassEnabled("AdditionalDirDepthOnly", cast);
                    }
                }
            }

            if (useAdditionalShadow != null)
                materialEditor.ShaderProperty(useAdditionalShadow, additionalShadowText);

            EditorGUI.BeginChangeCheck();
            int newQueue = EditorGUILayout.IntField(renderQueueText, material.renderQueue);
            if (EditorGUI.EndChangeCheck())
            {
                materialEditor.RegisterPropertyChangeUndo("Render Queue");
                material.renderQueue = newQueue;
                if (queueOffset != null)
                    queueOffset.floatValue = newQueue;
            }
        }

        public override void DrawSurfaceInputs(Material material)
        {
            base.DrawSurfaceInputs(material);
            LitGUI.Inputs(litProperties, materialEditor, material);
            DrawEmissionProperties(material, true);
            DrawTileOffset(materialEditor, baseMapProp);
        }

        public override void DrawAdvancedOptions(Material material)
        {
            if (litProperties.reflections != null && litProperties.highlights != null)
            {
                EditorGUI.BeginChangeCheck();
                materialEditor.ShaderProperty(litProperties.highlights, LitGUI.Styles.highlightsText);
                materialEditor.ShaderProperty(litProperties.reflections, LitGUI.Styles.reflectionsText);
                if (EditorGUI.EndChangeCheck())
                    ValidateMaterial(material);
            }

            base.DrawAdvancedOptions(material);
        }

        public override void FillAdditionalFoldouts(MaterialHeaderScopeList materialScopesList)
        {
            if (secondMap != null || secondMetallicGlossMap != null || secondNormalMap != null)
                materialScopesList.RegisterHeaderScope(secondLayerHeader, (uint)Foldout.SecondLayer, DrawSecondLayerArea);

            if (topMap != null || topMetallicGlossMap != null || topNormalMap != null)
                materialScopesList.RegisterHeaderScope(topLayerHeader, (uint)Foldout.TopLayer, DrawTopLayerArea);

            if (stencilRef != null)
                materialScopesList.RegisterHeaderScope(new GUIContent("Stencil"), (uint)Foldout.Stencil, DrawStencilArea);
        }

        private void DrawSecondLayerArea(Material material)
        {
            EditorGUILayout.HelpBox("Second Layer 使用三平面投射混合到底材上；Texture 的 Offset 会生效，采样密度请优先通过 Tiling 调整。", MessageType.Info);

            if (secondMap != null)
            {
                materialEditor.TexturePropertySingleLine(secondMapText, secondMap);
                materialEditor.TextureScaleOffsetProperty(secondMap);
            }

            if (secondMetallicGlossMap != null)
            {
                materialEditor.TexturePropertySingleLine(secondMetallicText, secondMetallicGlossMap);
                materialEditor.TextureScaleOffsetProperty(secondMetallicGlossMap);
            }

            if (secondNormalMap != null)
            {
                materialEditor.TexturePropertySingleLine(secondNormalText, secondNormalMap,
                    secondNormalMap.textureValue != null ? secondMapScale : null);
                materialEditor.TextureScaleOffsetProperty(secondNormalMap);
            }

            if (secondTilling != null)
                materialEditor.ShaderProperty(secondTilling, secondTilingText);
            if (secondSharpness != null)
                materialEditor.ShaderProperty(secondSharpness, secondSharpnessText);
        }

        private void DrawTopLayerArea(Material material)
        {
            EditorGUILayout.HelpBox("Top Layer 的覆盖权重 = 顶点色 R × 高度权重 × 朝上权重。Texture 的 Offset 会生效，采样密度请优先通过 Tiling 调整。", MessageType.Info);

            if (topMap != null)
            {
                materialEditor.TexturePropertySingleLine(topMapText, topMap);
                materialEditor.TextureScaleOffsetProperty(topMap);
            }

            if (topMetallicGlossMap != null)
            {
                materialEditor.TexturePropertySingleLine(topMetallicText, topMetallicGlossMap);
                materialEditor.TextureScaleOffsetProperty(topMetallicGlossMap);
            }

            if (topNormalMap != null)
            {
                materialEditor.TexturePropertySingleLine(topNormalText, topNormalMap,
                    topNormalMap.textureValue != null ? topMapScale : null);
                materialEditor.TextureScaleOffsetProperty(topNormalMap);
            }

            if (topTilling != null)
                materialEditor.ShaderProperty(topTilling, topTilingText);
            if (topSharpness != null)
                materialEditor.ShaderProperty(topSharpness, topSharpnessText);

            EditorGUILayout.Space();
            EditorGUILayout.LabelField("Top Blend Limits", EditorStyles.boldLabel);
            if (topHeightMin != null)
                materialEditor.ShaderProperty(topHeightMin, topHeightMinText);
            if (topHeightMax != null)
                materialEditor.ShaderProperty(topHeightMax, topHeightMaxText);
            if (topUpMin != null)
                materialEditor.ShaderProperty(topUpMin, topUpMinText);
            if (topUpMax != null)
                materialEditor.ShaderProperty(topUpMax, topUpMaxText);
        }

        private void DrawStencilArea(Material material)
        {
            if (stencilRef == null)
                return;

            materialEditor.ShaderProperty(stencilRef, "Stencil Ref");
            materialEditor.ShaderProperty(stencilComp, "Stencil Comp");
            materialEditor.ShaderProperty(stencilPass, "Stencil Pass");
            materialEditor.ShaderProperty(stencilFail, "Stencil Fail");
            materialEditor.ShaderProperty(stencilZFail, "Stencil ZFail");
            materialEditor.ShaderProperty(stencilReadMask, "Read Mask");
            materialEditor.ShaderProperty(stencilWriteMask, "Write Mask");
            if (zTest != null)
                materialEditor.ShaderProperty(zTest, new GUIContent("ZTest", "深度测试模式。"));
        }

        public override void AssignNewShaderToMaterial(Material material, Shader oldShader, Shader newShader)
        {
            if (material == null)
                throw new ArgumentNullException(nameof(material));

            if (material.HasProperty("_Emission"))
                material.SetColor("_EmissionColor", material.GetColor("_Emission"));

            base.AssignNewShaderToMaterial(material, oldShader, newShader);

            if (oldShader == null || !oldShader.name.Contains("Legacy Shaders/"))
            {
                SetupMaterialBlendMode(material);
                ValidateMaterial(material);
                return;
            }

            SurfaceType surfaceType = SurfaceType.Opaque;
            BlendMode blendMode = BlendMode.Alpha;

            if (oldShader.name.Contains("/Transparent/Cutout/"))
            {
                surfaceType = SurfaceType.Opaque;
                if (material.HasProperty("_AlphaClip"))
                    material.SetFloat("_AlphaClip", 1.0f);
            }
            else if (oldShader.name.Contains("/Transparent/"))
            {
                surfaceType = SurfaceType.Transparent;
                blendMode = BlendMode.Alpha;
            }

            if (material.HasProperty("_Surface"))
                material.SetFloat("_Surface", (float)surfaceType);
            if (material.HasProperty("_Blend"))
                material.SetFloat("_Blend", (float)blendMode);
            if (material.HasProperty("_WorkflowMode"))
                material.SetFloat("_WorkflowMode", (float)LitGUI.WorkflowMode.Metallic);

            ValidateMaterial(material);
        }
    }
}

