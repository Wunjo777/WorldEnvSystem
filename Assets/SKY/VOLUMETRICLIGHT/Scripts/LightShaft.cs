using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;



public class LightShaft : VolumeComponent
{
    // 设置参数
    public Transform LightTransform;
    public Vector3Parameter colorThreshold = new(new Vector3(0.5f, 0.5f, 0.5f));
    public FloatParameter lightRadius = new(0.0f);
    public FloatParameter lightPowFactor = new(0.0f);
    public FloatParameter offsets = new(0.0f);
    public FloatParameter intensity = new(0.5f);
}