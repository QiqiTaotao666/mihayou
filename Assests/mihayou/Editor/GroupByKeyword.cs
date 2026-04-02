using UnityEditor;
using UnityEngine;
using System.Collections.Generic;
using System.Linq;

public class GroupByKeywordWindow : EditorWindow
{
    private string keywords = "Tree, Rock, Grass, Bush";
    private bool caseSensitive = false;
    private bool searchInScene = true; // true=全场景搜索, false=仅选中物体

    [MenuItem("Tools/Group By Keyword")]
    static void ShowWindow()
    {
        var win = GetWindow<GroupByKeywordWindow>("Group By Keyword");
        win.minSize = new Vector2(350, 200);
    }

    void OnGUI()
    {
        GUILayout.Space(10);
        EditorGUILayout.LabelField("按关键词分组工具", EditorStyles.boldLabel);
        GUILayout.Space(5);

        EditorGUILayout.HelpBox(
            "输入关键词（逗号分隔），物体名称包含关键词的会被归到对应的分组父物体下。",
            MessageType.Info);

        GUILayout.Space(5);
        keywords = EditorGUILayout.TextField("关键词（逗号分隔）", keywords);
        caseSensitive = EditorGUILayout.Toggle("区分大小写", caseSensitive);
        searchInScene = EditorGUILayout.Toggle("搜索全场景（否则仅选中）", searchInScene);

        GUILayout.Space(10);

        // 预览
        if (GUILayout.Button("预览分组结果"))
        {
            Preview();
        }

        GUILayout.Space(5);

        GUI.backgroundColor = new Color(0.4f, 0.8f, 0.4f);
        if (GUILayout.Button("执行分组", GUILayout.Height(30)))
        {
            Execute();
        }
        GUI.backgroundColor = Color.white;
    }

    GameObject[] GetTargetObjects()
    {
        if (searchInScene)
        {
            return Object.FindObjectsOfType<GameObject>()
                .Where(go => go.scene.IsValid() && go.transform.parent == null || 
                       (go.transform.parent != null && !go.transform.parent.name.EndsWith("_Group")))
                .ToArray();
        }
        else
        {
            return Selection.gameObjects
                .Where(go => go.scene.IsValid())
                .ToArray();
        }
    }

    string[] ParseKeywords()
    {
        return keywords.Split(',')
            .Select(k => k.Trim())
            .Where(k => !string.IsNullOrEmpty(k))
            .ToArray();
    }

    bool NameContains(string objName, string keyword)
    {
        if (caseSensitive)
            return objName.Contains(keyword);
        return objName.ToLower().Contains(keyword.ToLower());
    }

    void Preview()
    {
        var keys = ParseKeywords();
        var targets = GetTargetObjects();
        var result = new Dictionary<string, List<string>>();

        foreach (var key in keys)
            result[key] = new List<string>();

        foreach (var go in targets)
        {
            foreach (var key in keys)
            {
                if (NameContains(go.name, key))
                {
                    result[key].Add(go.name);
                    break; // 每个物体只归入第一个匹配的关键词
                }
            }
        }

        string msg = "=== 分组预览 ===\n";
        foreach (var kvp in result)
        {
            msg += $"\n【{kvp.Key}_Group】({kvp.Value.Count} 个物体)\n";
            foreach (var name in kvp.Value.Take(10))
                msg += $"  - {name}\n";
            if (kvp.Value.Count > 10)
                msg += $"  ... 还有 {kvp.Value.Count - 10} 个\n";
        }

        Debug.Log(msg);
    }

    void Execute()
    {
        var keys = ParseKeywords();
        var targets = GetTargetObjects();

        Undo.SetCurrentGroupName("Group By Keyword");
        int totalGrouped = 0;

        foreach (var key in keys)
        {
            var matched = targets.Where(go => NameContains(go.name, key)).ToArray();
            if (matched.Length == 0) continue;

            // 查找是否已有该分组
            string groupName = key + "_Group";
            var existing = Object.FindObjectsOfType<GameObject>()
                .FirstOrDefault(go => go.name == groupName && go.scene.IsValid());

            GameObject parent;
            if (existing != null)
            {
                parent = existing;
            }
            else
            {
                parent = new GameObject(groupName);
                Undo.RegisterCreatedObjectUndo(parent, "Create Group " + groupName);
            }

            foreach (var go in matched.OrderBy(x => x.name))
            {
                // 跳过已经在正确分组下的
                if (go.transform.parent == parent.transform) continue;
                Undo.SetTransformParent(go.transform, parent.transform, "Reparent " + go.name);
                totalGrouped++;
            }
        }

        Debug.Log($"分组完成！共移动了 {totalGrouped} 个物体。可通过 Ctrl+Z 撤销。");
    }
}
