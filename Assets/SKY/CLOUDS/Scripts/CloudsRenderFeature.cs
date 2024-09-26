/*
Universal Render Data组件
BASED ON URP CUSTOM POST PROCESSING;
REF:https://www.bilibili.com/read/cv17805609/#:~:text=%E6%89%BE%E5%88%B0%E9%A1%B9%E7%9B%AE%E4%B8%AD%E6%AD%A3%E5%9C%A8%E4%BD%BF%E7%94%A8%E7%9A%84PiplineAsset%E6%96%87%E4%BB%B6%EF%BC%88%E5%9C%A8Edit-%3EProjectSetting-%3EQuality-%3ERendering%E4%B8%8B%E5%8F%AF%E4%BB%A5%E6%89%BE%E5%88%B0%E9%A1%B9%E7%9B%AE%E6%AD%A3%E5%9C%A8%E4%BD%BF%E7%94%A8%E7%9A%84%E6%B8%B2%E6%9F%93%E7%AE%A1%E7%BA%BF%E6%96%87%E4%BB%B6%EF%BC%89%EF%BC%8C%E5%A6%82%E6%9E%9C%E6%B2%A1%E6%9C%89%E7%9A%84%E8%AF%9D%EF%BC%8C%E6%96%B0%E5%BB%BA%E4%B8%80%E4%B8%AAPipline%20Asset%EF%BC%88Project%E4%B8%8B%EF%BC%8C%E5%8F%B3%E9%94%AECreate-%3ERendering-%3EURP-%3EPipline%20Asset%EF%BC%89%2C%E5%88%9B%E5%BB%BA%E5%AE%8C%E6%88%90%E5%90%8E%EF%BC%8C%E9%A1%B9%E7%9B%AE%E4%B8%AD%E9%99%A4%E4%BA%86PiplineAsset%E6%96%87%E4%BB%B6%EF%BC%8C%E8%BF%98%E4%BC%9A%E5%A4%9A%E5%87%BA%E4%B8%80%E4%B8%AAForward,Renderer%E6%96%87%E4%BB%B6%EF%BC%8C%E5%9C%A8Forward%20Renderer%E6%96%87%E4%BB%B6%E4%B8%AD%E7%82%B9%E5%87%BBAdd%20Renderer%20Feature%EF%BC%8C%E5%B0%B1%E5%8F%AF%E4%BB%A5%E6%B7%BB%E5%8A%A0%E8%87%AA%E5%AE%9A%E4%B9%89%E7%9A%84%E5%90%8E%E5%A4%84%E7%90%86%E6%95%88%E6%9E%9C%E4%BA%86%E3%80%82 
*/
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;


public class CloudsRenderFeature : ScriptableRendererFeature
{
    [System.Serializable]

    public class Settings      // 初始设置
    {
        public RenderPassEvent renderPassEvent = RenderPassEvent.BeforeRenderingPostProcessing;        // 设置渲染顺序  在后处理前
        public Shader shader;      // 设置后处理Shader
    }

    public Settings settings = new Settings();            // 开放设置

    CloudsPass cloudsPass;    // 设置渲染Pass

    public override void Create() // 初始化 属性
    //被调用时执行，用于初始化
    {
        this.name = "CloudsPass";        // 外部显示名字
        cloudsPass = new CloudsPass(RenderPassEvent.BeforeRenderingPostProcessing, settings.shader);      // 初始化Pass
    }
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData) // Pass执行逻辑
    //每帧都会调用，渲染摄像机内容  
    {
        renderer.EnqueuePass(cloudsPass);
    }
}


// 定义执行Pass
public class CloudsPass : ScriptableRenderPass
{
    static readonly string k_RenderTag = "Clouds Effects";          // 设置渲染 Tags
    static readonly int FinalTexId = Shader.PropertyToID("_FinalTex");   // 设置主贴图
    static readonly int CloudId = Shader.PropertyToID("_CloudTex");
    static readonly int BlurId = Shader.PropertyToID("_BlurTex");
    static readonly int blurLoop = 4;
    /********************************************************************************************/
    Clouds clouds;           // 传递到volume
    Material cloudsMaterial;     // 后处理使用材质
    GameObject findCloudBox;
    Transform cloudTransform;
    Vector3 boundsMin;
    Vector3 boundsMax;

    /********************************************************************************************/
    public CloudsPass(RenderPassEvent evt, Shader CloudsShader)        // 输入渲染位置    Shader
    //构造函数
    {
        renderPassEvent = evt;         // 设置渲染事件的位置
        var shader = CloudsShader;  // 输入Shader信息
        // 判断如果不存在Shader
        if (shader == null)         // Shader如果为空提示
        {
            //Debug.LogError("没有指定Shader");
            return;
        }
        //如果存在新建材质
        cloudsMaterial = CoreUtils.CreateEngineMaterial(CloudsShader);
    }

    public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
    //执行逻辑的地方
    {
        // 判断材质是否为空
        if (cloudsMaterial == null)
        {
            //Debug.LogError("材质初始化失败！");
            return;
        }
        // 判断是否开启后处理
        if (!renderingData.cameraData.postProcessEnabled)
        {
            // Debug.LogError("未开启后处理功能！");
            return;
        }
        // 渲染设置
        var stack = VolumeManager.instance.stack;          // 传入volume
        clouds = stack.GetComponent<Clouds>();       // 拿到我们的volume
        if (clouds == null)
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
                                                                                                            // int destination = TempTargetId;                         // 渲染结果图片
        cloudsMaterial.SetTexture(FinalTexId, source);
        /******************************************************************************************************************/
        findCloudBox = GameObject.Find("CloudBox");
        Debug.Assert(findCloudBox != null, "无法找到CloudBox！");

        if (findCloudBox != null)
        {
            cloudTransform = findCloudBox.GetComponent<Transform>();
        }
        if (cloudTransform != null)
        {
            boundsMin = cloudTransform.position - cloudTransform.localScale / 2;
            boundsMax = cloudTransform.position + cloudTransform.localScale / 2;
            cloudsMaterial.SetVector("_boundsMin", boundsMin);
            cloudsMaterial.SetVector("_boundsMax", boundsMax);
        }

        cloudsMaterial.SetTexture("_Basic3DTex", clouds.Basic3DTex.value);

        cloudsMaterial.SetTexture("_WeatherMap", clouds.WeatherTexture.value);

        cloudsMaterial.SetTexture("_Detail3DTex", clouds.Detail3DTex.value);

        cloudsMaterial.SetTexture("_maskNoise", clouds.MaskNoise.value);

        cloudsMaterial.SetTexture("_BlueNoise", clouds.BlueNoise.value);

        cloudsMaterial.SetFloat("_shapeTune", clouds.ShapeTune.value);

        cloudsMaterial.SetFloat("_detailTune", clouds.DetailTune.value);

        cloudsMaterial.SetFloat("_shapeSpeed", clouds.ShapeSpeed.value);

        cloudsMaterial.SetFloat("_setailSpeed", clouds.DetailSpeed.value);

        cloudsMaterial.SetFloat("_weatherMapSpeed", clouds.WeatherMapSpeed.value);

        cloudsMaterial.SetFloat("_maskNoiseSpeed", clouds.MaskNoiseSpeed.value);

        cloudsMaterial.SetFloat("_shapeTiling", clouds.ShapeTiling.value);

        cloudsMaterial.SetFloat("_heightWeights", clouds.HeightWeights.value);

        cloudsMaterial.SetVector("_shapeNoiseWeights", clouds.ShapeNoiseWeights.value);


        cloudsMaterial.SetFloat("_densityOffset", clouds.DensityOffset.value);


        cloudsMaterial.SetFloat("_detailWeights", clouds.DetailWeights.value);


        cloudsMaterial.SetFloat("_densityMultiplier", clouds.DensityMultiplier.value);


        cloudsMaterial.SetFloat("_detailNoiseWeight", clouds.DetailNoiseWeight.value);


        cloudsMaterial.SetFloat("_weatherMapUvScale", clouds.WeatherMapUvScale.value);


        cloudsMaterial.SetFloat("_maskNoiseUvScale", clouds.MaskNoiseUvScale.value);


        cloudsMaterial.SetFloat("_shapeNoiseUvScale", clouds.ShapeNoiseUvScale.value);


        cloudsMaterial.SetFloat("_detailNoiseUvScale", clouds.DetailNoiseUvScale.value);


        cloudsMaterial.SetFloat("_cloudAbsorbTune", clouds.CloudAbsorbTune.value);

        /******************************************************************************************************************/

        cmd.GetTemporaryRT(CloudId, cameraData.camera.scaledPixelWidth, cameraData.camera.scaledPixelHeight, 0, FilterMode.Trilinear, RenderTextureFormat.Default);
        cmd.GetTemporaryRT(BlurId, cameraData.camera.scaledPixelWidth, cameraData.camera.scaledPixelHeight, 0, FilterMode.Trilinear, RenderTextureFormat.Default);

        cmd.Blit(source, CloudId, cloudsMaterial, 0);//添加体积云
        for (int i = 0; i < blurLoop; i++)
        {
            cmd.Blit(CloudId, BlurId, cloudsMaterial, 1);//模糊
            cmd.Blit(BlurId, CloudId);
        }
        cmd.Blit(CloudId, BlurId, cloudsMaterial, 2);//合并结果
        cmd.Blit(BlurId, source);

        cmd.ReleaseTemporaryRT(CloudId);
        cmd.ReleaseTemporaryRT(BlurId);
        // // cmd.SetGlobalTexture(MainTexId, source);                // 获取当前摄像机渲染的图片
        // cmd.GetTemporaryRT(destination, cameraData.camera.scaledPixelWidth, cameraData.camera.scaledPixelHeight, 0, FilterMode.Trilinear, RenderTextureFormat.Default);
        // cmd.Blit(source, destination);                          // 设置后处理
        // cmd.Blit(destination, source, cloudsMaterial, 0);    // 传入颜色校正
    }
}
