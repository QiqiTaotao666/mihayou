using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEditor.Rendering;
using UnityEditor.Rendering.Universal.ShaderGUI;

namespace UnityEditor
{
    public class CustomLitShaderGUI : BaseShaderGUI
    {
        private enum CustomExpandable
        {
            DetailInputs = 1 << 4,
            Stencil = 1 << 5,
        }

        // Lit properties
        private LitGUI.LitProperties litProperties;


        // Detail properties (inline since LitDetailGUI is internal)
        private MaterialProperty detailMask;
        private MaterialProperty detailAlbedoMapScale;
        private MaterialProperty detailAlbedoMap;
        private MaterialProperty detailNormalMapScale;
        private MaterialProperty detailNormalMap;

        // Stencil properties
        private MaterialProperty _stencilRef;
        private MaterialProperty _stencilComp;
        private MaterialProperty _stencilPass;
        private MaterialProperty _stencilFail;
        private MaterialProperty _stencilZFail;
        private MaterialProperty _stencilReadMask;
        private MaterialProperty _stencilWriteMask;

        // Opacity
        private MaterialProperty _opacity;

        // CubeMap Reflection
        private MaterialProperty _envCubeMap;
        private MaterialProperty _envCubeMapIntensity;

        // Shadow
        private MaterialProperty _castShadows;
        private MaterialProperty _useAdditionalShadow;

        // Depth
        private MaterialProperty _zTest;

        // Render Queue
        private MaterialProperty _queueOffset;

        // Foldout states (using EditorPrefs since SavedBool is internal)
        private string _foldoutKeyPrefix;
        private bool m_DetailInputsFoldout;
        private bool m_StencilFoldout;

        // Detail styles
        private static readonly GUIContent detailInputsText = new GUIContent("Detail Inputs",
            "These settings let you add details to the surface.");
        private static readonly GUIContent detailMaskText = new GUIContent("Mask",
            "Select a mask for the Detail maps.");
        private static readonly GUIContent detailAlbedoMapText = new GUIContent("Base Map",
            "Select the texture containing the surface details.");
        private static readonly GUIContent detailNormalMapText = new GUIContent("Normal Map",
            "Select the texture containing the normal vector data.");
        private static readonly GUIContent detailAlbedoMapScaleInfo = new GUIContent(
            "Setting the scaling factor to a value other than 1 results in a less performant shader variant.");

        public override void OnOpenGUI(Material material, MaterialEditor materialEditor)
        {
            base.OnOpenGUI(material, materialEditor);
            _foldoutKeyPrefix = "CustomLitGUI:" + material.shader.name;
            m_DetailInputsFoldout = EditorPrefs.GetBool(_foldoutKeyPrefix + ".Detail", true);
            m_StencilFoldout = EditorPrefs.GetBool(_foldoutKeyPrefix + ".Stencil", true);
        }

        public override void FindProperties(MaterialProperty[] properties)
        {
            base.FindProperties(properties);
            litProperties = new LitGUI.LitProperties(properties);

            // Detail
            detailMask = FindProperty("_DetailMask", properties, false);
            detailAlbedoMapScale = FindProperty("_DetailAlbedoMapScale", properties, false);
            detailAlbedoMap = FindProperty("_DetailAlbedoMap", properties, false);
            detailNormalMapScale = FindProperty("_DetailNormalMapScale", properties, false);
            detailNormalMap = FindProperty("_DetailNormalMap", properties, false);

            // Stencil
            _stencilRef = FindProperty("_StencilRef", properties, false);
            _stencilComp = FindProperty("_StencilComp", properties, false);
            _stencilPass = FindProperty("_StencilPass", properties, false);
            _stencilFail = FindProperty("_StencilFail", properties, false);
            _stencilZFail = FindProperty("_StencilZFail", properties, false);
            _stencilReadMask = FindProperty("_StencilReadMask", properties, false);
            _stencilWriteMask = FindProperty("_StencilWriteMask", properties, false);

            // Opacity & Shadow & Depth & Queue
            _opacity = FindProperty("_Opacity", properties, false);
            _castShadows = FindProperty("_CastShadows", properties, false);
            _useAdditionalShadow = FindProperty("_USEAdditionalShadow", properties, false);
            _zTest = FindProperty("_ZTest", properties, false);
            _queueOffset = FindProperty("_QueueOffset", properties, false);

            // CubeMap Reflection
            _envCubeMap = FindProperty("_EnvCubeMap", properties, false);
            _envCubeMapIntensity = FindProperty("_EnvCubeMapIntensity", properties, false);
        }

        public override void ValidateMaterial(Material material)
        {
            if (material == null)
                throw new ArgumentNullException("material");

            SetMaterialKeywords(material, LitGUI.SetMaterialKeywords, SetDetailMaterialKeywords);

            // 恢复用户手动设置的 Render Queue（_QueueOffset 存储完整值）
            if (material.HasProperty("_QueueOffset"))
            {
                int customQueue = (int)material.GetFloat("_QueueOffset");
                if (customQueue > 0)
                    material.renderQueue = customQueue;
            }

            // 同步 Cast Shadows 状态
            if (material.HasProperty("_CastShadows"))
            {
                bool cast = material.GetFloat("_CastShadows") >= 0.5f;
                material.SetShaderPassEnabled("ShadowCaster", cast);
            }
        }

        public override void DrawSurfaceOptions(Material material)
        {
            if (material == null)
                throw new ArgumentNullException("material");

            EditorGUIUtility.labelWidth = 0f;

            EditorGUI.BeginChangeCheck();
            if (litProperties.workflowMode != null)
            {
                DoPopup(LitGUI.Styles.workflowModeText, litProperties.workflowMode, Enum.GetNames(typeof(LitGUI.WorkflowMode)));
            }
            if (EditorGUI.EndChangeCheck())
            {
                foreach (var obj in blendModeProp.targets)
                    ValidateMaterial((Material)obj);
            }
            base.DrawSurfaceOptions(material);

            // Opacity slider
            if (_opacity != null)
            {
                materialEditor.ShaderProperty(_opacity, new GUIContent("Opacity", "Controls the overall transparency of the surface."));
            }

            // Cast Shadows toggle
            if (_castShadows != null)
            {
                EditorGUI.BeginChangeCheck();
                materialEditor.ShaderProperty(_castShadows, new GUIContent("Cast Shadows", "Enable or disable shadow casting for this material."));
                if (EditorGUI.EndChangeCheck())
                {
                    bool cast = _castShadows.floatValue >= 0.5f;
                    foreach (var obj in materialEditor.targets)
                    {
                        Material mat = (Material)obj;
                        mat.SetShaderPassEnabled("ShadowCaster", cast);
                        mat.SetShaderPassEnabled("AdditionalDirDepthOnly", cast);
                    }
                }
            }

            // USE Additional Shadow toggle
            if (_useAdditionalShadow != null)
            {
                materialEditor.ShaderProperty(_useAdditionalShadow, new GUIContent("USE Additional Shadow", "Enable additional directional light shadow."));
            }

            // Render Queue - 直接输入数值
            EditorGUI.BeginChangeCheck();
            var newQueue = EditorGUILayout.IntField(
                new GUIContent("Render Queue", "Render Queue value. e.g. Geometry=2000, AlphaTest=2450, Transparent=3000"),
                material.renderQueue);
            if (EditorGUI.EndChangeCheck())
            {
                materialEditor.RegisterPropertyChangeUndo("Render Queue");
                material.renderQueue = newQueue;
                // 存储到 _QueueOffset 用于持久化
                if (_queueOffset != null)
                    _queueOffset.floatValue = newQueue;
            }
        }

        public override void DrawSurfaceInputs(Material material)
        {
            base.DrawSurfaceInputs(material);
            LitGUI.Inputs(litProperties, materialEditor, material);
            DrawEmissionProperties(material, true);
            DrawTileOffset(materialEditor, baseMapProp);

            // CubeMap Reflection
            if (_envCubeMap != null)
            {
                EditorGUILayout.Space();
                materialEditor.TexturePropertySingleLine(
                    new GUIContent("Environment CubeMap", "Cubemap used for custom reflections, sampled by smoothness mip level."),
                    _envCubeMap);
                if (_envCubeMapIntensity != null)
                    materialEditor.ShaderProperty(_envCubeMapIntensity, new GUIContent("CubeMap Intensity", "Strength of the cubemap reflection overlay."));
            }
        }

        public override void DrawAdvancedOptions(Material material)
        {
            if (litProperties.reflections != null && litProperties.highlights != null)
            {
                EditorGUI.BeginChangeCheck();
                materialEditor.ShaderProperty(litProperties.highlights, LitGUI.Styles.highlightsText);
                materialEditor.ShaderProperty(litProperties.reflections, LitGUI.Styles.reflectionsText);
                if (EditorGUI.EndChangeCheck())
                {
                    ValidateMaterial(material);
                }
            }

            base.DrawAdvancedOptions(material);
        }

        public override void FillAdditionalFoldouts(MaterialHeaderScopeList materialScopesList)
        {
            if (detailAlbedoMap != null)
                materialScopesList.RegisterHeaderScope(detailInputsText, CustomExpandable.DetailInputs, DrawDetailArea);

            if (_stencilRef != null)
                materialScopesList.RegisterHeaderScope(new GUIContent("Stencil"), CustomExpandable.Stencil, DrawStencilArea);
        }

        private void DrawDetailArea(Material material)
        {
            if (detailAlbedoMap == null) return;

            materialEditor.TexturePropertySingleLine(detailMaskText, detailMask);
            materialEditor.TexturePropertySingleLine(detailAlbedoMapText, detailAlbedoMap,
                detailAlbedoMap.textureValue != null ? detailAlbedoMapScale : null);
            if (detailAlbedoMapScale.floatValue != 1.0f)
            {
                EditorGUILayout.HelpBox(detailAlbedoMapScaleInfo.text, MessageType.Info, true);
            }
            materialEditor.TexturePropertySingleLine(detailNormalMapText, detailNormalMap,
                detailNormalMap.textureValue != null ? detailNormalMapScale : null);
            materialEditor.TextureScaleOffsetProperty(detailAlbedoMap);
        }

        private void DrawStencilArea(Material material)
        {
            if (_stencilRef == null) return;

            materialEditor.ShaderProperty(_stencilRef, "Stencil Ref");
            materialEditor.ShaderProperty(_stencilComp, "Stencil Comp");
            materialEditor.ShaderProperty(_stencilPass, "Stencil Pass");
            materialEditor.ShaderProperty(_stencilFail, "Stencil Fail");
            materialEditor.ShaderProperty(_stencilZFail, "Stencil ZFail");
            materialEditor.ShaderProperty(_stencilReadMask, "Read Mask");
            materialEditor.ShaderProperty(_stencilWriteMask, "Write Mask");
            if (_zTest != null)
                materialEditor.ShaderProperty(_zTest, new GUIContent("ZTest", "Depth test mode. Set to Always to ignore depth (useful for stencil-masked objects behind other geometry)."));
        }


        // Inline replacement for LitDetailGUI.SetMaterialKeywords
        private static void SetDetailMaterialKeywords(Material material)
        {
            if (material.HasProperty("_DetailAlbedoMap") && material.HasProperty("_DetailNormalMap") && material.HasProperty("_DetailAlbedoMapScale"))
            {
                bool isScaled = material.GetFloat("_DetailAlbedoMapScale") != 1.0f;
                bool hasDetailMap = material.GetTexture("_DetailAlbedoMap") || material.GetTexture("_DetailNormalMap");
                CoreUtils.SetKeyword(material, "_DETAIL_MULX2", !isScaled && hasDetailMap);
                CoreUtils.SetKeyword(material, "_DETAIL_SCALED", isScaled && hasDetailMap);
            }
        }

        public override void AssignNewShaderToMaterial(Material material, Shader oldShader, Shader newShader)
        {
            if (material == null)
                throw new ArgumentNullException("material");

            if (material.HasProperty("_Emission"))
            {
                material.SetColor("_EmissionColor", material.GetColor("_Emission"));
            }

            base.AssignNewShaderToMaterial(material, oldShader, newShader);

            if (oldShader == null || !oldShader.name.Contains("Legacy Shaders/"))
            {
                SetupMaterialBlendMode(material);
                return;
            }

            SurfaceType surfaceType = SurfaceType.Opaque;
            BlendMode blendMode = BlendMode.Alpha;
            if (oldShader.name.Contains("/Transparent/Cutout/"))
            {
                surfaceType = SurfaceType.Opaque;
                material.SetFloat("_AlphaClip", 1);
            }
            else if (oldShader.name.Contains("/Transparent/"))
            {
                surfaceType = SurfaceType.Transparent;
                blendMode = BlendMode.Alpha;
            }
            material.SetFloat("_Surface", (float)surfaceType);
            material.SetFloat("_Blend", (float)blendMode);

            if (oldShader.name.Equals("Standard (Specular setup)"))
            {
                material.SetFloat("_WorkflowMode", (float)LitGUI.WorkflowMode.Specular);
                Texture texture = material.GetTexture("_SpecGlossMap");
                if (texture != null)
                    material.SetTexture("_MetallicSpecGlossMap", texture);
            }
            else
            {
                material.SetFloat("_WorkflowMode", (float)LitGUI.WorkflowMode.Metallic);
                Texture texture = material.GetTexture("_MetallicGlossMap");
                if (texture != null)
                    material.SetTexture("_MetallicSpecGlossMap", texture);
            }

            ValidateMaterial(material);
        }
    }
}
