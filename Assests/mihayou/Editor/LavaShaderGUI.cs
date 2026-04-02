using UnityEngine;
using UnityEngine.Rendering;
using UnityEditor;

public class LavaShaderGUI : ShaderGUI
{
    // Foldout states
    private bool foldoutMain = true;
    private bool foldoutLayer = true;
    private bool foldoutDistortion = true;
    private bool foldoutPBR = true;
    private bool foldoutEmission = true;
    private bool foldoutRendering = false;
    private bool foldoutStencil = false;

    public override void OnGUI(MaterialEditor materialEditor, MaterialProperty[] properties)
    {
        Material material = materialEditor.target as Material;

        // ===================== Main =====================
        foldoutMain = EditorGUILayout.BeginFoldoutHeaderGroup(foldoutMain, "Main");
        if (foldoutMain)
        {
            EditorGUI.indentLevel++;
            materialEditor.ShaderProperty(FindProperty("_MainColor", properties), "Main Color");
            materialEditor.TexturePropertySingleLine(new GUIContent("Albedo"), FindProperty("_Albedo", properties));
            materialEditor.TexturePropertySingleLine(new GUIContent("Normal Map"), FindProperty("_Normal", properties));
            materialEditor.ShaderProperty(FindProperty("_Tiling", properties), "Tiling");
            materialEditor.ShaderProperty(FindProperty("_Speed", properties), "Speed");
            materialEditor.ShaderProperty(FindProperty("_EdgeDistance", properties), "Edge Distance");
            EditorGUI.indentLevel--;
        }
        EditorGUILayout.EndFoldoutHeaderGroup();

        // ===================== Emission =====================
        foldoutEmission = EditorGUILayout.BeginFoldoutHeaderGroup(foldoutEmission, "Emission");
        if (foldoutEmission)
        {
            EditorGUI.indentLevel++;
            materialEditor.ShaderProperty(FindProperty("_EmissiveColor", properties), "Emissive Color (HDR)");
            materialEditor.TexturePropertySingleLine(new GUIContent("Emissive Map"), FindProperty("_Emissive", properties));
            materialEditor.ShaderProperty(FindProperty("_EmissiveTiling", properties), "Emissive Tiling");
            materialEditor.ShaderProperty(FindProperty("_DepthContrast", properties), "Depth Contrast");
            materialEditor.ShaderProperty(FindProperty("_InvertDepth", properties), "Invert Depth");
            EditorGUI.indentLevel--;
        }
        EditorGUILayout.EndFoldoutHeaderGroup();

        // ===================== Layer Maps =====================
        foldoutLayer = EditorGUILayout.BeginFoldoutHeaderGroup(foldoutLayer, "Layer Maps");
        if (foldoutLayer)
        {
            EditorGUI.indentLevel++;
            materialEditor.TexturePropertySingleLine(new GUIContent("Layer Albedo"), FindProperty("_LayerAlbedo", properties));
            materialEditor.TexturePropertySingleLine(new GUIContent("Layer Normal"), FindProperty("_LayerNormal", properties));
            materialEditor.ShaderProperty(FindProperty("_LayerNormalPower", properties), "Layer Normal Power");
            materialEditor.ShaderProperty(FindProperty("_LayerTiling", properties), "Layer Tiling");
            EditorGUI.indentLevel--;
        }
        EditorGUILayout.EndFoldoutHeaderGroup();

        // ===================== Distortion =====================
        foldoutDistortion = EditorGUILayout.BeginFoldoutHeaderGroup(foldoutDistortion, "Distortion");
        if (foldoutDistortion)
        {
            EditorGUI.indentLevel++;
            materialEditor.ShaderProperty(FindProperty("_DistortionPower", properties), "Distortion Power");
            materialEditor.TexturePropertySingleLine(new GUIContent("Distortion Map"), FindProperty("_Distortion", properties));
            materialEditor.ShaderProperty(FindProperty("_DistorsionScale", properties), "Distortion Scale");
            materialEditor.ShaderProperty(FindProperty("_DistortionSpeed", properties), "Distortion Speed");
            EditorGUI.indentLevel--;
        }
        EditorGUILayout.EndFoldoutHeaderGroup();

        // ===================== PBR & Reflection =====================
        foldoutPBR = EditorGUILayout.BeginFoldoutHeaderGroup(foldoutPBR, "PBR & Reflection");
        if (foldoutPBR)
        {
            EditorGUI.indentLevel++;
            materialEditor.ShaderProperty(FindProperty("_Metallic", properties), "Metallic");
            materialEditor.ShaderProperty(FindProperty("_Smoothness", properties), "Smoothness");
            EditorGUILayout.Space(5);
            materialEditor.TexturePropertySingleLine(new GUIContent("Environment CubeMap"), FindProperty("_EnvCubeMap", properties));
            materialEditor.ShaderProperty(FindProperty("_EnvCubeMapIntensity", properties), "CubeMap Intensity");
            EditorGUI.indentLevel--;
        }
        EditorGUILayout.EndFoldoutHeaderGroup();

        // ===================== Rendering =====================
        foldoutRendering = EditorGUILayout.BeginFoldoutHeaderGroup(foldoutRendering, "Rendering");
        if (foldoutRendering)
        {
            EditorGUI.indentLevel++;
            materialEditor.ShaderProperty(FindProperty("_Opacity", properties), "Opacity");
            materialEditor.ShaderProperty(FindProperty("_CastShadows", properties), "Cast Shadows");
            materialEditor.ShaderProperty(FindProperty("_USEAdditionalShadow", properties), "USE Additional Shadow");
            materialEditor.ShaderProperty(FindProperty("_ReceiveShadows", properties), "Receive Shadows");

            EditorGUILayout.Space(5);
            MaterialProperty zTest = FindProperty("_ZTest", properties);
            materialEditor.ShaderProperty(zTest, "ZTest");

            EditorGUILayout.Space(5);
            EditorGUILayout.LabelField("Render Queue", EditorStyles.boldLabel);
            EditorGUI.BeginChangeCheck();
            int newQueue = EditorGUILayout.IntField("Queue", material.renderQueue);
            if (EditorGUI.EndChangeCheck())
            {
                materialEditor.RegisterPropertyChangeUndo("Render Queue");
                material.renderQueue = newQueue;
                MaterialProperty queueOffset = FindProperty("_QueueOffset", properties, false);
                if (queueOffset != null)
                    queueOffset.floatValue = newQueue;
            }

            // Sync cast shadows pass
            if (material.HasProperty("_CastShadows"))
            {
                bool cast = material.GetFloat("_CastShadows") >= 0.5f;
                material.SetShaderPassEnabled("ShadowCaster", cast);
                material.SetShaderPassEnabled("AdditionalDirDepthOnly", cast);
            }

            EditorGUI.indentLevel--;
        }
        EditorGUILayout.EndFoldoutHeaderGroup();

        // ===================== Stencil =====================
        foldoutStencil = EditorGUILayout.BeginFoldoutHeaderGroup(foldoutStencil, "Stencil");
        if (foldoutStencil)
        {
            EditorGUI.indentLevel++;
            materialEditor.ShaderProperty(FindProperty("_StencilRef", properties), "Stencil Ref");
            materialEditor.ShaderProperty(FindProperty("_StencilComp", properties), "Stencil Comp");
            materialEditor.ShaderProperty(FindProperty("_StencilPass", properties), "Stencil Pass");
            materialEditor.ShaderProperty(FindProperty("_StencilFail", properties), "Stencil Fail");
            materialEditor.ShaderProperty(FindProperty("_StencilZFail", properties), "Stencil ZFail");
            materialEditor.ShaderProperty(FindProperty("_StencilReadMask", properties), "Read Mask");
            materialEditor.ShaderProperty(FindProperty("_StencilWriteMask", properties), "Write Mask");
            EditorGUI.indentLevel--;
        }
        EditorGUILayout.EndFoldoutHeaderGroup();

        EditorGUILayout.Space(10);
        materialEditor.RenderQueueField();
        materialEditor.EnableInstancingField();
        materialEditor.DoubleSidedGIField();
    }
}
