using UnityEngine;
#if UNITY_EDITOR
using UnityEditor;
using System.IO;

public class GradientBakerWindow : EditorWindow
{
    private Gradient gradient = new Gradient();
    private Material targetMaterial;
    private string propertyName = "_CloudGradient";
    private int resolution = 128;
    private Texture2D previewTex;

    [MenuItem("Tools/Gradient Baker")]
    public static void ShowWindow()
    {
        var win = GetWindow<GradientBakerWindow>("Gradient Baker");
        win.minSize = new Vector2(300, 260);
    }

    private void OnGUI()
    {
        EditorGUILayout.Space(6);
        EditorGUILayout.LabelField("Gradient Baker", EditorStyles.boldLabel);
        EditorGUILayout.Space(4);

        // Gradient 编辑
        gradient = EditorGUILayout.GradientField("Gradient", gradient);

        // 目标材质
        targetMaterial = (Material)EditorGUILayout.ObjectField("Target Material", targetMaterial, typeof(Material), false);

        // 属性名
        propertyName = EditorGUILayout.TextField("Property Name", propertyName);

        // 分辨率
        resolution = EditorGUILayout.IntSlider("Resolution", resolution, 32, 512);

        EditorGUILayout.Space(8);

        // ── 预览 ──
        EditorGUILayout.LabelField("Preview:");
        UpdatePreview();
        if (previewTex != null)
        {
            Rect rect = GUILayoutUtility.GetRect(0, 24, GUILayout.ExpandWidth(true));
            EditorGUI.DrawPreviewTexture(rect, previewTex);
        }

        EditorGUILayout.Space(10);

        // ── 烘焙并保存 PNG ──
        if (GUILayout.Button("Bake & Save PNG", GUILayout.Height(32)))
        {
            BakeAndSave();
        }

        // ── 仅赋给材质 ──
        GUI.enabled = targetMaterial != null;
        if (GUILayout.Button("Apply to Material (Runtime Only)", GUILayout.Height(28)))
        {
            var tex = BakeToTexture();
            targetMaterial.SetTexture(propertyName, tex);
            Debug.Log($"[GradientBaker] Runtime texture applied to {targetMaterial.name}.{propertyName}");
        }
        GUI.enabled = true;
    }

    private void UpdatePreview()
    {
        if (previewTex == null || previewTex.width != resolution)
        {
            if (previewTex != null) DestroyImmediate(previewTex);
            previewTex = new Texture2D(resolution, 1, TextureFormat.RGBA32, false)
            {
                wrapMode = TextureWrapMode.Clamp,
                filterMode = FilterMode.Bilinear
            };
        }

        for (int i = 0; i < resolution; i++)
        {
            Color c = gradient.Evaluate((float)i / (resolution - 1));
            previewTex.SetPixel(i, 0, c);
        }
        previewTex.Apply();
    }

    private Texture2D BakeToTexture()
    {
        var tex = new Texture2D(resolution, 1, TextureFormat.RGBA32, false)
        {
            wrapMode = TextureWrapMode.Clamp,
            filterMode = FilterMode.Bilinear
        };

        for (int i = 0; i < resolution; i++)
        {
            Color c = gradient.Evaluate((float)i / (resolution - 1));
            tex.SetPixel(i, 0, c);
        }
        tex.Apply();
        return tex;
    }

    private void BakeAndSave()
    {
        string savePath = EditorUtility.SaveFilePanel(
            "保存 Gradient 纹理",
            "Assets",
            "GradientBaked",
            "png");

        if (string.IsNullOrEmpty(savePath)) return;

        Texture2D tex = BakeToTexture();
        byte[] png = tex.EncodeToPNG();
        DestroyImmediate(tex);

        File.WriteAllBytes(savePath, png);

        // 如果保存在项目内，自动导入并赋给材质
        if (savePath.StartsWith(Application.dataPath))
        {
            string relativePath = "Assets" + savePath.Substring(Application.dataPath.Length);
            AssetDatabase.Refresh();

            // 设置纹理导入格式
            TextureImporter importer = AssetImporter.GetAtPath(relativePath) as TextureImporter;
            if (importer != null)
            {
                importer.textureType = TextureImporterType.Default;
                importer.wrapMode = TextureWrapMode.Clamp;
                importer.filterMode = FilterMode.Bilinear;
                importer.mipmapEnabled = false;
                importer.sRGBTexture = true;
                importer.SaveAndReimport();
            }

            Texture2D saved = AssetDatabase.LoadAssetAtPath<Texture2D>(relativePath);
            if (saved != null && targetMaterial != null)
            {
                targetMaterial.SetTexture(propertyName, saved);
                EditorUtility.SetDirty(targetMaterial);
                Debug.Log($"[GradientBaker] Saved {relativePath} → {targetMaterial.name}.{propertyName}");
            }
            else
            {
                Debug.Log($"[GradientBaker] Saved {relativePath}");
            }
        }
        else
        {
            Debug.Log($"[GradientBaker] Saved to external path: {savePath}");
        }
    }

    private void OnDestroy()
    {
        if (previewTex != null) DestroyImmediate(previewTex);
    }
}
#endif
