using UnityEngine;

/// <summary>
/// 粒子旋涡效果 —— 粒子从上方生成，螺旋旋转并逐渐被吸收到中心底部
/// 挂载到空物体上即可自动创建 ParticleSystem
/// </summary>
[RequireComponent(typeof(ParticleSystem))]
public class VortexParticleEffect : MonoBehaviour
{
    [Header("=== 旋涡参数 ===")]
    [Tooltip("旋涡顶部半径")]
    public float topRadius = 3f;

    [Tooltip("旋涡底部半径（吸收点半径）")]
    public float bottomRadius = 0.1f;

    [Tooltip("旋涡高度")]
    public float vortexHeight = 5f;

    [Tooltip("旋转速度（度/秒）")]
    public float rotationSpeed = 360f;

    [Tooltip("下降速度")]
    public float descentSpeed = 1.5f;

    [Header("=== 粒子参数 ===")]
    [Tooltip("粒子数量")]
    public int maxParticles = 200;

    [Tooltip("发射速率")]
    public float emissionRate = 60f;

    [Tooltip("粒子生命周期")]
    public float particleLifetime = 3f;

    [Tooltip("粒子起始大小")]
    public float startSize = 0.15f;

    [Tooltip("粒子颜色")]
    public Color particleColor = new Color(0.3f, 0.8f, 1f, 1f);

    [Tooltip("粒子结束颜色")]
    public Color endColor = new Color(0.1f, 0.4f, 1f, 0f);

    [Header("=== 高级 ===")]
    [Tooltip("是否使用噪声扰动")]
    public bool useNoise = true;

    [Tooltip("噪声强度")]
    public float noiseStrength = 0.3f;

    [Tooltip("加速吸收（越大越快被吸到底部）")]
    public float accelerationFactor = 1.5f;

    private ParticleSystem ps;
    private ParticleSystem.Particle[] particles;

    void Start()
    {
        ps = GetComponent<ParticleSystem>();
        ConfigureParticleSystem();
        particles = new ParticleSystem.Particle[maxParticles];
    }

    void ConfigureParticleSystem()
    {
        var main = ps.main;
        main.maxParticles = maxParticles;
        main.startLifetime = particleLifetime;
        main.startSpeed = 0f;  // 我们手动控制位置
        main.startSize = startSize;
        main.startColor = particleColor;
        main.simulationSpace = ParticleSystemSimulationSpace.Local;
        main.loop = true;
        main.playOnAwake = true;

        // 发射模块 - 从圆环顶部发射
        var emission = ps.emission;
        emission.rateOverTime = emissionRate;

        // 形状模块 - 圆环形发射
        var shape = ps.shape;
        shape.shapeType = ParticleSystemShapeType.Circle;
        shape.radius = topRadius;
        shape.radiusThickness = 0.1f; // 从边缘发射
        shape.rotation = new Vector3(0, 0, 0);
        shape.position = new Vector3(0, vortexHeight, 0);

        // 大小随生命周期变化 - 逐渐缩小
        var sizeOverLifetime = ps.sizeOverLifetime;
        sizeOverLifetime.enabled = true;
        AnimationCurve sizeCurve = new AnimationCurve();
        sizeCurve.AddKey(0f, 1f);
        sizeCurve.AddKey(0.7f, 0.6f);
        sizeCurve.AddKey(1f, 0f);
        sizeOverLifetime.size = new ParticleSystem.MinMaxCurve(1f, sizeCurve);

        // 颜色随生命周期变化
        var colorOverLifetime = ps.colorOverLifetime;
        colorOverLifetime.enabled = true;
        Gradient grad = new Gradient();
        grad.SetKeys(
            new GradientColorKey[] {
                new GradientColorKey(particleColor, 0f),
                new GradientColorKey(endColor, 1f)
            },
            new GradientAlphaKey[] {
                new GradientAlphaKey(0f, 0f),
                new GradientAlphaKey(1f, 0.1f),
                new GradientAlphaKey(1f, 0.7f),
                new GradientAlphaKey(0f, 1f)
            }
        );
        colorOverLifetime.color = grad;

        // 渲染器设置
        var renderer = ps.GetComponent<ParticleSystemRenderer>();
        renderer.renderMode = ParticleSystemRenderMode.Billboard;
        renderer.sortMode = ParticleSystemSortMode.YoungestInFront;

        // 尝试加载自定义材质
        var mat = Resources.Load<Material>("VortexParticleMat");
        if (mat != null)
        {
            renderer.material = mat;
        }
        else
        {
            // 使用默认粒子材质
            renderer.material = new Material(Shader.Find("Particles/Standard Unlit"));
            renderer.material.SetFloat("_Mode", 1); // Additive
        }

        // 关闭不需要的模块
        var velocityOverLifetime = ps.velocityOverLifetime;
        velocityOverLifetime.enabled = false;

        var forceOverLifetime = ps.forceOverLifetime;
        forceOverLifetime.enabled = false;
    }

    void LateUpdate()
    {
        if (ps == null) return;

        int numAlive = ps.GetParticles(particles);

        for (int i = 0; i < numAlive; i++)
        {
            // 计算粒子的归一化年龄 [0, 1]
            float normalizedAge = 1f - (particles[i].remainingLifetime / particles[i].startLifetime);

            // 加速下降（使用幂函数让越往下越快）
            float acceleratedAge = Mathf.Pow(normalizedAge, 1f / accelerationFactor);

            // 当前高度（从顶部到底部）
            float currentY = Mathf.Lerp(vortexHeight, 0f, acceleratedAge);

            // 当前半径（从大到小，螺旋收缩）
            float currentRadius = Mathf.Lerp(topRadius, bottomRadius, acceleratedAge);

            // 旋转角度（基于时间累积 + 粒子随机偏移）
            float angle = particles[i].randomSeed % 360f; // 起始角度随机
            angle += rotationSpeed * normalizedAge * particleLifetime; // 累积旋转
            angle *= Mathf.Deg2Rad;

            // 计算螺旋位置
            float x = Mathf.Cos(angle) * currentRadius;
            float z = Mathf.Sin(angle) * currentRadius;

            // 添加噪声扰动
            if (useNoise)
            {
                float noiseTime = Time.time * 0.5f + particles[i].randomSeed * 0.01f;
                x += Mathf.PerlinNoise(noiseTime, 0f) * noiseStrength * (1f - acceleratedAge);
                z += Mathf.PerlinNoise(0f, noiseTime) * noiseStrength * (1f - acceleratedAge);
            }

            particles[i].position = new Vector3(x, currentY, z);
        }

        ps.SetParticles(particles, numAlive);
    }

    // 在编辑器中绘制辅助线
    void OnDrawGizmosSelected()
    {
        Gizmos.color = Color.cyan;
        // 顶部圆
        DrawCircleGizmo(transform.position + Vector3.up * vortexHeight, topRadius, 32);
        // 底部圆
        Gizmos.color = Color.blue;
        DrawCircleGizmo(transform.position, bottomRadius, 16);
        // 连线
        Gizmos.color = new Color(0, 0.5f, 1f, 0.5f);
        for (int i = 0; i < 4; i++)
        {
            float angle = i * 90f * Mathf.Deg2Rad;
            Vector3 top = transform.position + new Vector3(Mathf.Cos(angle) * topRadius, vortexHeight, Mathf.Sin(angle) * topRadius);
            Vector3 bot = transform.position + new Vector3(Mathf.Cos(angle) * bottomRadius, 0, Mathf.Sin(angle) * bottomRadius);
            Gizmos.DrawLine(top, bot);
        }
    }

    void DrawCircleGizmo(Vector3 center, float radius, int segments)
    {
        float step = 2f * Mathf.PI / segments;
        Vector3 prev = center + new Vector3(radius, 0, 0);
        for (int i = 1; i <= segments; i++)
        {
            float angle = step * i;
            Vector3 next = center + new Vector3(Mathf.Cos(angle) * radius, 0, Mathf.Sin(angle) * radius);
            Gizmos.DrawLine(prev, next);
            prev = next;
        }
    }
}
