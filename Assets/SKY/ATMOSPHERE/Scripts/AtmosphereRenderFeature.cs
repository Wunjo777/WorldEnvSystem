/////////////////////////////
/*This file is not used.*/
/////////////////////////////
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;


public class AtmosphereRenderFeature : ScriptableRendererFeature
{
    [System.Serializable]

    public class Settings      // 初始设置
    {
        public RenderPassEvent renderPassEvent = RenderPassEvent.BeforeRenderingPostProcessing;        // 设置渲染顺序  在后处理前
        public Shader shader;      // 设置后处理Shader
    }

    public Settings settings = new Settings();            // 开放设置

    AtmospherePass atmospherePass;    // 设置渲染Pass

    public override void Create() // 初始化 属性
    //被调用时执行，用于初始化
    {
        this.name = "AtmospherePass";        // 外部显示名字
        atmospherePass = new AtmospherePass(RenderPassEvent.BeforeRenderingPostProcessing, settings.shader);      // 初始化Pass
    }
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData) // Pass执行逻辑
    //每帧都会调用，渲染摄像机内容  
    {
        renderer.EnqueuePass(atmospherePass);
    }
}


// 定义执行Pass
public class AtmospherePass : ScriptableRenderPass
{
    static readonly string k_RenderTag = "Atmosphere Effects";          // 设置渲染 Tags
    static readonly int MainTexId = Shader.PropertyToID("_MainTex");   // 设置主贴图
    static readonly int TempTargetId = Shader.PropertyToID("_TempTargetAtmosphere");    // 设置储存图像信息
    /***************************************************************************************************/
    //原文件保留变量
    Atmosphere atmosphere;           // 传递到volume
    Material atmosphereMaterial;     // 后处理使用材质
    //下方定义此脚本文件中的计算需要用到的变量：

    /***************************************************************************************************/



    public AtmospherePass(RenderPassEvent evt, Shader AtmosphereShader)        // 输入渲染位置    Shader
    //构造函数
    {
        renderPassEvent = evt;         // 设置渲染事件的位置
        var shader = AtmosphereShader;  // 输入Shader信息
        // 判断如果不存在Shader
        if (shader == null)         // Shader如果为空提示
        {
            //Debug.LogError("没有指定Shader");
            return;
        }
        //如果存在新建材质
        atmosphereMaterial = CoreUtils.CreateEngineMaterial(AtmosphereShader);
    }

    public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
    //执行逻辑的地方
    {
        // 判断材质是否为空
        if (atmosphereMaterial == null)
        {
            //Debug.LogError("材质初始化失败！");
            return;
        }
        // 判断是否开启后处理
        if (!renderingData.cameraData.postProcessEnabled)
        {
            return;
        }
        // 渲染设置
        var stack = VolumeManager.instance.stack;          // 传入volume
        atmosphere = stack.GetComponent<Atmosphere>();       // 拿到我们的volume
        if (atmosphere == null)
        {
            //Debug.LogError(" Volume组件获取失败 ");
            return;
        }

        var cmd = CommandBufferPool.Get(k_RenderTag);   // 设置渲染标签
        Render(cmd, ref renderingData);                 // 设置渲染函数
        context.ExecuteCommandBuffer(cmd);              // 执行函数
        CommandBufferPool.Release(cmd);                 // 释放
    }

    void Render(CommandBuffer cmd, ref RenderingData renderingData)
    {
        ref var cameraData = ref renderingData.cameraData;      // 获取摄像机属性
        var camera = cameraData.camera;                         // 传入摄像机
        var source = renderingData.cameraData.renderer.cameraColorTargetHandle;                             // 获取渲染图片
        int destination = TempTargetId;                         // 渲染结果图片
        /**********************************************************************************************************/
        //下方进行一些计算或给shader传递参数：




        /**********************************************************************************************************/
        cmd.SetGlobalTexture(MainTexId, source);                // 获取当前摄像机渲染的图片
        cmd.GetTemporaryRT(destination, cameraData.camera.scaledPixelWidth, cameraData.camera.scaledPixelHeight, 0, FilterMode.Trilinear, RenderTextureFormat.Default);
        cmd.Blit(source, destination);                          // 设置后处理
        cmd.Blit(destination, source, atmosphereMaterial, 0);    // 传入颜色校正
    }
}
