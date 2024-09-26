/*
Volume Profile组件
BASED ON URP CUSTOM POST PROCESSING;
REF:https://www.bilibili.com/read/cv17805609/#:~:text=%E6%89%BE%E5%88%B0%E9%A1%B9%E7%9B%AE%E4%B8%AD%E6%AD%A3%E5%9C%A8%E4%BD%BF%E7%94%A8%E7%9A%84PiplineAsset%E6%96%87%E4%BB%B6%EF%BC%88%E5%9C%A8Edit-%3EProjectSetting-%3EQuality-%3ERendering%E4%B8%8B%E5%8F%AF%E4%BB%A5%E6%89%BE%E5%88%B0%E9%A1%B9%E7%9B%AE%E6%AD%A3%E5%9C%A8%E4%BD%BF%E7%94%A8%E7%9A%84%E6%B8%B2%E6%9F%93%E7%AE%A1%E7%BA%BF%E6%96%87%E4%BB%B6%EF%BC%89%EF%BC%8C%E5%A6%82%E6%9E%9C%E6%B2%A1%E6%9C%89%E7%9A%84%E8%AF%9D%EF%BC%8C%E6%96%B0%E5%BB%BA%E4%B8%80%E4%B8%AAPipline%20Asset%EF%BC%88Project%E4%B8%8B%EF%BC%8C%E5%8F%B3%E9%94%AECreate-%3ERendering-%3EURP-%3EPipline%20Asset%EF%BC%89%2C%E5%88%9B%E5%BB%BA%E5%AE%8C%E6%88%90%E5%90%8E%EF%BC%8C%E9%A1%B9%E7%9B%AE%E4%B8%AD%E9%99%A4%E4%BA%86PiplineAsset%E6%96%87%E4%BB%B6%EF%BC%8C%E8%BF%98%E4%BC%9A%E5%A4%9A%E5%87%BA%E4%B8%80%E4%B8%AAForward,Renderer%E6%96%87%E4%BB%B6%EF%BC%8C%E5%9C%A8Forward%20Renderer%E6%96%87%E4%BB%B6%E4%B8%AD%E7%82%B9%E5%87%BBAdd%20Renderer%20Feature%EF%BC%8C%E5%B0%B1%E5%8F%AF%E4%BB%A5%E6%B7%BB%E5%8A%A0%E8%87%AA%E5%AE%9A%E4%B9%89%E7%9A%84%E5%90%8E%E5%A4%84%E7%90%86%E6%95%88%E6%9E%9C%E4%BA%86%E3%80%82 
*/
using Unity.Mathematics;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.UIElements.Experimental;


public class Clouds : VolumeComponent
{
    public TextureParameter Basic3DTex = new TextureParameter(null);
    public TextureParameter Detail3DTex = new TextureParameter(null);
    public TextureParameter WeatherTexture = new TextureParameter(null);
    public TextureParameter MaskNoise = new TextureParameter(null);
    public TextureParameter BlueNoise = new TextureParameter(null);
    public FloatParameter ShapeTune = new FloatParameter(0.1f);
    public FloatParameter DetailTune = new FloatParameter(0.1f);
    public FloatParameter ShapeSpeed = new FloatParameter(0.05f);
    public FloatParameter DetailSpeed = new FloatParameter(0.05f);
    public FloatParameter WeatherMapSpeed = new FloatParameter(0.05f);
    public FloatParameter MaskNoiseSpeed = new FloatParameter(0.025f);
    public FloatParameter ShapeTiling = new FloatParameter(0.0002f);
    public FloatParameter HeightWeights = new FloatParameter(0.5f);
    public Vector4Parameter ShapeNoiseWeights = new Vector4Parameter(new Vector4(4f, 50f, -3.18f, -20f));
    public FloatParameter DensityOffset = new FloatParameter(-15f);
    public FloatParameter DetailWeights = new FloatParameter(2f);
    public FloatParameter DensityMultiplier = new FloatParameter(0.5f);
    public FloatParameter DetailNoiseWeight = new FloatParameter(0.5f);
    public FloatParameter WeatherMapUvScale = new FloatParameter(1f);
    public FloatParameter MaskNoiseUvScale = new FloatParameter(2.6f);
    public FloatParameter ShapeNoiseUvScale = new FloatParameter(0.5f);
    public FloatParameter DetailNoiseUvScale = new FloatParameter(3f);
    public FloatParameter CloudAbsorbTune = new FloatParameter(4f);
}