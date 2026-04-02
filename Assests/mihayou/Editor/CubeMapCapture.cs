using UnityEngine;
using UnityEngine.Rendering.Universal;
using UnityEditor;

public class CubeMapCapture : ScriptableWizard
{
    public Transform renderFromPosition;
    public int cubemapSize = 512;
    public float nearClip = 0.01f;
    public float farClip = 1000f;
    public LayerMask cullingMask = ~0; // 默认渲染所有层

    [MenuItem("Tools/Capture CubeMap")]
    static void CreateWizard()
    {
        DisplayWizard<CubeMapCapture>("Capture CubeMap", "Capture");
    }

    void OnWizardCreate()
    {
        string path = EditorUtility.SaveFilePanelInProject(
            "Save CubeMap", "SceneCubeMap", "asset", "Choose where to save the cubemap");

        if (string.IsNullOrEmpty(path))
            return;

        // 使用 RenderTexture Cubemap 代替 Cubemap，兼容 URP
        RenderTexture rtCube = new RenderTexture(cubemapSize, cubemapSize, 24, RenderTextureFormat.DefaultHDR);
        rtCube.dimension = UnityEngine.Rendering.TextureDimension.Cube;
        rtCube.useMipMap = true;
        rtCube.autoGenerateMips = false;
        rtCube.Create();

        // 创建临时相机并复制场景主相机的渲染设置
        GameObject camGO = new GameObject("_CubeMapCaptureCamera");
        Camera cam = camGO.AddComponent<Camera>();
        cam.nearClipPlane = nearClip;
        cam.farClipPlane = farClip;
        cam.cullingMask = cullingMask;
        cam.clearFlags = CameraClearFlags.Skybox;
        cam.allowHDR = true;

        // 添加 URP Camera Data 确保管线正确渲染
        var urpCamData = camGO.AddComponent<UniversalAdditionalCameraData>();
        urpCamData.renderShadows = true;

        if (renderFromPosition != null)
            camGO.transform.position = renderFromPosition.position;
        else
            camGO.transform.position = SceneView.lastActiveSceneView.camera.transform.position;

        // 临时隐藏提供位置的物体
        bool wasActive = false;
        if (renderFromPosition != null)
        {
            wasActive = renderFromPosition.gameObject.activeSelf;
            renderFromPosition.gameObject.SetActive(false);
        }

        cam.RenderToCubemap(rtCube);

        // 恢复物体
        if (renderFromPosition != null)
            renderFromPosition.gameObject.SetActive(wasActive);

        DestroyImmediate(camGO);

        // 将 RenderTexture 转为持久化 Cubemap 资产
        Cubemap cubemap = new Cubemap(cubemapSize, TextureFormat.RGBAHalf, true);
        CubemapFace[] faces = {
            CubemapFace.PositiveX, CubemapFace.NegativeX,
            CubemapFace.PositiveY, CubemapFace.NegativeY,
            CubemapFace.PositiveZ, CubemapFace.NegativeZ
        };

        // 逐面拷贝像素
        Texture2D tempTex = new Texture2D(cubemapSize, cubemapSize, TextureFormat.RGBAHalf, false);
        RenderTexture prevRT = RenderTexture.active;

        for (int i = 0; i < 6; i++)
        {
            Graphics.SetRenderTarget(rtCube, 0, faces[i]);
            tempTex.ReadPixels(new Rect(0, 0, cubemapSize, cubemapSize), 0, 0);
            tempTex.Apply();
            cubemap.SetPixels(tempTex.GetPixels(), faces[i]);
        }

        RenderTexture.active = prevRT;
        cubemap.Apply(true); // 生成 mipmap

        DestroyImmediate(tempTex);
        rtCube.Release();
        DestroyImmediate(rtCube);

        AssetDatabase.CreateAsset(cubemap, path);
        AssetDatabase.SaveAssets();
        AssetDatabase.Refresh();

        Selection.activeObject = AssetDatabase.LoadAssetAtPath<Cubemap>(path);
        Debug.Log($"CubeMap captured and saved to: {path}");
    }

    void OnWizardUpdate()
    {
        helpString = "Set capture position, clip planes, and culling mask. Leave Transform empty to use Scene View camera.";
        isValid = cubemapSize > 0;
    }
}
