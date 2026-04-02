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

            // ── 统计 ──
            int countCorrectLayer = 0;
            int countWrongLayer = 0;
            int countShadowOn = 0;
            int countShadowOff = 0;
            int countNoRenderer = 0;
            int countNoProperty = 0;

            foreach (var go in selected)
            {
                if (go.layer == stencilLayer) countCorrectLayer++;
                else countWrongLayer++;

                Renderer r = go.GetComponent<Renderer>();
                if (r == null) { countNoRenderer++; continue; }

                foreach (Material mat in r.sharedMaterials)
                {
                    if (mat == null) continue;
                    if (!mat.HasProperty("_USEAdditionalShadow")) { countNoProperty++; continue; }
                    if (mat.GetFloat("_USEAdditionalShadow") >= 0.5f) countShadowOn++;
                    else countShadowOff++;
                }
            }

            // ── 总览 ──
            EditorGUILayout.LabelField("总览", EditorStyles.boldLabel);
            EditorGUILayout.LabelField($"选中物体数：{selected.Length}");

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

            // ── 物体列表 ──
            EditorGUILayout.LabelField("物体详情", EditorStyles.boldLabel);
            scrollPos = EditorGUILayout.BeginScrollView(scrollPos, GUILayout.ExpandHeight(true));

            foreach (var go in selected)
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
                    ApplyAll(selected);

                GUI.backgroundColor = new Color(0.9f, 0.5f, 0.3f);
                if (GUILayout.Button("仅改 Layer", GUILayout.Height(32)))
                    ApplyLayerOnly(selected);

                if (GUILayout.Button("仅开 Shadow", GUILayout.Height(32)))
                    ApplyShadowOnly(selected);

                GUI.backgroundColor = new Color(0.4f, 0.6f, 0.9f);
                if (GUILayout.Button("仅设 Stencil", GUILayout.Height(32)))
                    ApplyStencilOnly(selected);

                GUI.backgroundColor = Color.white;
            }

            EditorGUILayout.Space(4);
        }

        // ── Apply helpers ──

        private void ApplyAll(GameObject[] objects)
        {
            int mObj = 0, mMat = 0, mStencil = 0;
            foreach (var go in objects)
            {
                SetLayer(go); mObj++;
                mMat += EnableShadow(go);
                mStencil += SetStencil(go);
            }
            Debug.Log($"完成：{mObj} 个物体 Layer → StencilWorld，{mMat} 个材质启用 USEAdditionalShadow，{mStencil} 个材质设置 Stencil。");
        }

        private void ApplyLayerOnly(GameObject[] objects)
        {
            int mObj = 0;
            foreach (var go in objects) { SetLayer(go); mObj++; }
            Debug.Log($"完成：{mObj} 个物体 Layer → StencilWorld。");
        }

        private void ApplyShadowOnly(GameObject[] objects)
        {
            int mMat = 0;
            foreach (var go in objects) mMat += EnableShadow(go);
            Debug.Log($"完成：{mMat} 个材质启用 USEAdditionalShadow。");
        }

        private void ApplyStencilOnly(GameObject[] objects)
        {
            int mStencil = 0;
            foreach (var go in objects) mStencil += SetStencil(go);
            Debug.Log($"完成：{mStencil} 个材质设置 Stencil (Ref={stencilRef}, Comp={stencilComp})。");
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
