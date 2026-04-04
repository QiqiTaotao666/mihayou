using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEditor;

namespace UnityEditor
{
    public class SetupStencilWorldWindow : EditorWindow
    {
        private Vector2 scrollPos;
        private int stencilLayer = -1;

        // Stencil 配置参数
        private int stencilRef = 1;
        private CompareFunction stencilComp = CompareFunction.Always;

        // Render Queue 配置
        private bool useCustomRenderQueue = false;
        private int renderQueue = 3000; // 默认 Transparent

        // 是否包含子物体
        private bool includeChildren = true;

        [MenuItem("Tools/Setup StencilWorld + AdditionalShadow")]
        private static void ShowWindow()
        {
            var win = GetWindow<SetupStencilWorldWindow>("StencilWorld Setup");
            win.minSize = new Vector2(380, 300);
        }

        private void OnEnable()
        {
            stencilLayer = LayerMask.NameToLayer("StencilWorld");
            Selection.selectionChanged += Repaint;
        }

        private void OnDisable()
        {
            Selection.selectionChanged -= Repaint;
        }

        private void OnGUI()
        {
            // ── 标题 ──
            EditorGUILayout.Space(6);
            EditorGUILayout.LabelField("StencilWorld 批量设置工具", EditorStyles.boldLabel);
            EditorGUILayout.Space(4);

            if (stencilLayer < 0)
            {
                EditorGUILayout.HelpBox("找不到 StencilWorld Layer，请先在 TagManager 中创建。", MessageType.Error);
                return;
            }

            GameObject[] selected = Selection.gameObjects;
            if (selected.Length == 0)
            {
                EditorGUILayout.HelpBox("请在 Hierarchy 中选中一个或多个物体。", MessageType.Info);
                return;
            }

            // ── 包含子物体开关 ──
            includeChildren = EditorGUILayout.Toggle("包含所有子物体", includeChildren);

            // 收集所有要处理的 GameObject
            List<GameObject> allObjects = CollectGameObjects(selected, includeChildren);

            // ── 统计 ──
            int countCorrectLayer = 0;
            int countWrongLayer = 0;
            int countShadowOn = 0;
            int countShadowOff = 0;
            int countNoRenderer = 0;
            int countNoProperty = 0;
            int countQueueMatch = 0;
            int countQueueMismatch = 0;

            foreach (var go in allObjects)
            {
                if (go.layer == stencilLayer) countCorrectLayer++;
                else countWrongLayer++;

                Renderer r = go.GetComponent<Renderer>();
                if (r == null) { countNoRenderer++; continue; }

                foreach (Material mat in r.sharedMaterials)
                {
                    if (mat == null) continue;
                    if (!mat.HasProperty("_USEAdditionalShadow")) { countNoProperty++; }
                    else
                    {
                        if (mat.GetFloat("_USEAdditionalShadow") >= 0.5f) countShadowOn++;
                        else countShadowOff++;
                    }
                    // Render Queue 统计
                    if (useCustomRenderQueue)
                    {
                        if (mat.renderQueue == renderQueue) countQueueMatch++;
                        else countQueueMismatch++;
                    }
                }
            }

            // ── 总览 ──
            EditorGUILayout.LabelField("总览", EditorStyles.boldLabel);
            EditorGUILayout.LabelField($"选中物体数：{selected.Length}  |  处理总数(含子物体)：{allObjects.Count}");

            using (new EditorGUILayout.HorizontalScope())
            {
                StatusLabel($"Layer 正确：{countCorrectLayer}", countCorrectLayer > 0, true);
                StatusLabel($"Layer 待改：{countWrongLayer}", countWrongLayer > 0, false);
            }
            using (new EditorGUILayout.HorizontalScope())
            {
                StatusLabel($"Shadow 已开：{countShadowOn}", countShadowOn > 0, true);
                StatusLabel($"Shadow 未开：{countShadowOff}", countShadowOff > 0, false);
            }
            if (useCustomRenderQueue)
            {
                using (new EditorGUILayout.HorizontalScope())
                {
                    StatusLabel($"Queue 匹配：{countQueueMatch}", countQueueMatch > 0, true);
                    StatusLabel($"Queue 待改：{countQueueMismatch}", countQueueMismatch > 0, false);
                }
            }
            if (countNoRenderer > 0)
                EditorGUILayout.LabelField($"  无 Renderer：{countNoRenderer}", EditorStyles.miniLabel);
            if (countNoProperty > 0)
                EditorGUILayout.LabelField($"  材质无 _USEAdditionalShadow 属性：{countNoProperty}", EditorStyles.miniLabel);

            EditorGUILayout.Space(6);

            // ── Stencil 配置 ──
            EditorGUILayout.LabelField("Stencil 配置", EditorStyles.boldLabel);
            using (new EditorGUILayout.HorizontalScope())
            {
                stencilRef = EditorGUILayout.IntSlider("Stencil Ref", stencilRef, 0, 255);
            }
            stencilComp = (CompareFunction)EditorGUILayout.EnumPopup("Stencil Comp", stencilComp);

            EditorGUILayout.Space(6);

            // ── Render Queue 配置 ──
            EditorGUILayout.LabelField("Render Queue 配置", EditorStyles.boldLabel);
            useCustomRenderQueue = EditorGUILayout.Toggle("启用自定义 Queue", useCustomRenderQueue);
            if (useCustomRenderQueue)
            {
                renderQueue = EditorGUILayout.IntField("Render Queue", renderQueue);
                EditorGUILayout.HelpBox("常用值: Background=1000, Geometry=2000, AlphaTest=2450, Transparent=3000, Overlay=4000", MessageType.None);
            }

            EditorGUILayout.Space(6);

            // ── 物体列表 ──
            EditorGUILayout.LabelField("物体详情", EditorStyles.boldLabel);
            scrollPos = EditorGUILayout.BeginScrollView(scrollPos, GUILayout.ExpandHeight(true));

            foreach (var go in allObjects)
            {
                bool layerOk = go.layer == stencilLayer;
                Renderer r = go.GetComponent<Renderer>();

                EditorGUILayout.BeginVertical("box");

                // 物体名（可点击定位）
                using (new EditorGUILayout.HorizontalScope())
                {
                    if (GUILayout.Button(go.name, EditorStyles.linkLabel))
                        EditorGUIUtility.PingObject(go);

                    GUILayout.FlexibleSpace();
                    DrawTag(layerOk ? "Layer OK" : $"Layer: {LayerMask.LayerToName(go.layer)}", layerOk);
                }

                if (r != null)
                {
                    foreach (Material mat in r.sharedMaterials)
                    {
                        if (mat == null) continue;
                        using (new EditorGUILayout.HorizontalScope())
                        {
                            EditorGUILayout.LabelField($"  Mat: {mat.name}", GUILayout.Width(180));
                            if (mat.HasProperty("_USEAdditionalShadow"))
                            {
                                bool on = mat.GetFloat("_USEAdditionalShadow") >= 0.5f;
                                DrawTag(on ? "Shadow ON" : "Shadow OFF", on);
                            }
                            else
                            {
                                EditorGUILayout.LabelField("(无属性)", EditorStyles.miniLabel);
                            }
                            if (mat.HasProperty("_StencilRef"))
                            {
                                int refVal = (int)mat.GetFloat("_StencilRef");
                                string compName = mat.HasProperty("_StencilComp")
                                    ? ((CompareFunction)(int)mat.GetFloat("_StencilComp")).ToString()
                                    : "?";
                                DrawTag($"Ref:{refVal} {compName}", refVal > 0);
                            }
                            // 显示 Render Queue
                            bool queueOk = useCustomRenderQueue && mat.renderQueue == renderQueue;
                            DrawTag($"Q:{mat.renderQueue}", !useCustomRenderQueue || queueOk);
                        }
                    }
                }
                else
                {
                    EditorGUILayout.LabelField("  无 Renderer", EditorStyles.miniLabel);
                }

                EditorGUILayout.EndVertical();
            }

            EditorGUILayout.EndScrollView();

            EditorGUILayout.Space(4);

            // ── 操作按钮 ──
            using (new EditorGUILayout.HorizontalScope())
            {
                GUI.backgroundColor = new Color(0.3f, 0.8f, 0.4f);
                if (GUILayout.Button("一键设置全部", GUILayout.Height(32)))
                    ApplyAll(allObjects);

                GUI.backgroundColor = new Color(0.9f, 0.5f, 0.3f);
                if (GUILayout.Button("仅改 Layer", GUILayout.Height(32)))
                    ApplyLayerOnly(allObjects);

                if (GUILayout.Button("仅开 Shadow", GUILayout.Height(32)))
                    ApplyShadowOnly(allObjects);

                GUI.backgroundColor = new Color(0.4f, 0.6f, 0.9f);
                if (GUILayout.Button("仅设 Stencil", GUILayout.Height(32)))
                    ApplyStencilOnly(allObjects);

                GUI.backgroundColor = new Color(0.8f, 0.4f, 0.8f);
                if (GUILayout.Button("仅设 Queue", GUILayout.Height(32)))
                    ApplyRenderQueueOnly(allObjects);

                GUI.backgroundColor = Color.white;
            }

            EditorGUILayout.Space(4);
        }

        // ── Apply helpers ──

        private void ApplyAll(List<GameObject> objects)
        {
            int mObj = 0, mMat = 0, mStencil = 0, mQueue = 0;
            foreach (var go in objects)
            {
                SetLayer(go); mObj++;
                mMat += EnableShadow(go);
                mStencil += SetStencil(go);
                if (useCustomRenderQueue) mQueue += SetRenderQueue(go);
            }
            Debug.Log($"完成：{mObj} 个物体 Layer → StencilWorld，{mMat} 个材质启用 USEAdditionalShadow，{mStencil} 个材质设置 Stencil，{mQueue} 个材质设置 RenderQueue={renderQueue}。");
        }

        private void ApplyLayerOnly(List<GameObject> objects)
        {
            int mObj = 0;
            foreach (var go in objects) { SetLayer(go); mObj++; }
            Debug.Log($"完成：{mObj} 个物体 Layer → StencilWorld。");
        }

        private void ApplyShadowOnly(List<GameObject> objects)
        {
            int mMat = 0;
            foreach (var go in objects) mMat += EnableShadow(go);
            Debug.Log($"完成：{mMat} 个材质启用 USEAdditionalShadow。");
        }

        private void ApplyStencilOnly(List<GameObject> objects)
        {
            int mStencil = 0;
            foreach (var go in objects) mStencil += SetStencil(go);
            Debug.Log($"完成：{mStencil} 个材质设置 Stencil (Ref={stencilRef}, Comp={stencilComp})。");
        }

        private void ApplyRenderQueueOnly(List<GameObject> objects)
        {
            int mQueue = 0;
            foreach (var go in objects) mQueue += SetRenderQueue(go);
            Debug.Log($"完成：{mQueue} 个材质设置 RenderQueue={renderQueue}。");
        }

        private void SetLayer(GameObject go)
        {
            Undo.RecordObject(go, "Set Layer to StencilWorld");
            go.layer = stencilLayer;
        }

        private int EnableShadow(GameObject go)
        {
            int count = 0;
            Renderer r = go.GetComponent<Renderer>();
            if (r == null) return 0;
            foreach (Material mat in r.sharedMaterials)
            {
                if (mat == null || !mat.HasProperty("_USEAdditionalShadow")) continue;
                Undo.RecordObject(mat, "Enable USEAdditionalShadow");
                mat.SetFloat("_USEAdditionalShadow", 1.0f);
                EditorUtility.SetDirty(mat);
                count++;
            }
            return count;
        }

        private int SetStencil(GameObject go)
        {
            int count = 0;
            Renderer r = go.GetComponent<Renderer>();
            if (r == null) return 0;
            foreach (Material mat in r.sharedMaterials)
            {
                if (mat == null) continue;
                if (!mat.HasProperty("_StencilRef") || !mat.HasProperty("_StencilComp")) continue;
                Undo.RecordObject(mat, "Set Stencil Ref & Comp");
                mat.SetFloat("_StencilRef", stencilRef);
                mat.SetFloat("_StencilComp", (float)stencilComp);
                EditorUtility.SetDirty(mat);
                count++;
            }
            return count;
        }

        private int SetRenderQueue(GameObject go)
        {
            int count = 0;
            Renderer r = go.GetComponent<Renderer>();
            if (r == null) return 0;
            foreach (Material mat in r.sharedMaterials)
            {
                if (mat == null) continue;
                Undo.RecordObject(mat, "Set Render Queue");
                mat.renderQueue = renderQueue;
                EditorUtility.SetDirty(mat);
                count++;
            }
            return count;
        }

        /// <summary>
        /// 收集所有要处理的 GameObject（可选包含子物体），去重
        /// </summary>
        private static List<GameObject> CollectGameObjects(GameObject[] roots, bool includeChildren)
        {
            HashSet<GameObject> set = new HashSet<GameObject>();
            foreach (var root in roots)
            {
                if (includeChildren)
                {
                    // GetComponentsInChildren 包含自身
                    Transform[] allTransforms = root.GetComponentsInChildren<Transform>(true);
                    foreach (var t in allTransforms)
                        set.Add(t.gameObject);
                }
                else
                {
                    set.Add(root);
                }
            }
            return new List<GameObject>(set);
        }

        // ── UI helpers ──

        private static void StatusLabel(string text, bool hasItems, bool isGood)
        {
            Color c = GUI.color;
            if (hasItems)
                GUI.color = isGood ? new Color(0.2f, 0.85f, 0.3f) : new Color(1f, 0.6f, 0.2f);
            EditorGUILayout.LabelField(text, EditorStyles.miniLabel);
            GUI.color = c;
        }

        private static void DrawTag(string label, bool ok)
        {
            Color c = GUI.backgroundColor;
            GUI.backgroundColor = ok ? new Color(0.2f, 0.8f, 0.3f) : new Color(1f, 0.55f, 0.2f);
            GUILayout.Label(label, "miniButton", GUILayout.MinWidth(90));
            GUI.backgroundColor = c;
        }
    }
}
