using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;



public class VolumetricLight : VolumeComponent
{
    // 设置参数
    public FloatParameter LightIntensity = new FloatParameter(0.25f);
}