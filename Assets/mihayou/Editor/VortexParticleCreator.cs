using UnityEngine;
using UnityEditor;

/// <summary>
/// 编辑器工具 —— 一键创建旋涡粒子效果
/// 菜单: GameObject > Effects > Vortex Particle
/// </summary>
public class VortexParticleCreator
{
    [MenuItem("GameObject/Effects/Vortex Particle", false, 10)]
    static void CreateVortexParticle()
    {
        // 创建父物体
        GameObject vortexObj = new GameObject("VortexParticle");

        // 在场景视图焦点位置创建
        if (SceneView.lastActiveSceneView != null)
        {
            vortexObj.transform.position = SceneView.lastActiveSceneView.pivot;
        }

        // 添加ParticleSystem（Unity自动添加）和控制脚本
        var ps = vortexObj.AddComponent<ParticleSystem>();
        var vortex = vortexObj.AddComponent<VortexParticleEffect>();

        // 尝试创建/查找材质
        string shaderName = "My/VortexParticle";
        Shader shader = Shader.Find(shaderName);
        if (shader != null)
        {
            Material mat = new Material(shader);
            mat.name = "MI_VortexParticle";
            mat.SetColor("_TintColor", new Color(0.3f, 0.8f, 1f, 1f));
            mat.SetFloat("_Intensity", 2f);

            var renderer = ps.GetComponent<ParticleSystemRenderer>();
            renderer.material = mat;

            // 保存材质资产
            string matPath = "Assets/mihayou/FX/MI_VortexParticle.mat";
            if (!AssetDatabase.LoadAssetAtPath<Material>(matPath))
            {
                AssetDatabase.CreateAsset(mat, matPath);
                AssetDatabase.SaveAssets();
            }
        }

        // 选中新创建的物体
        Selection.activeGameObject = vortexObj;
        Undo.RegisterCreatedObjectUndo(vortexObj, "Create Vortex Particle");

        Debug.Log("旋涡粒子效果已创建！可在Inspector中调整参数。");
    }
}
