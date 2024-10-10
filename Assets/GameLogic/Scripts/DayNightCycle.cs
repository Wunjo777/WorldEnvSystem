using Unity.Mathematics;
using UnityEngine;

public class DayNightCycle : MonoBehaviour
{
    public float rotationSpeed = 1.0f;  // 旋转速度
    public Color dayColor = Color.white; // 白天颜色
    public Color dawnColor = Color.white;
    public Color nightColor = Color.white; // 晚上颜色
    public float dayIntensity = 1.0f; // 白天强度
    public float nightIntensity = 0.2f; // 晚上强度
    public float dawnBegin = 0.0f;
    public float dawnEnd = 0.0f;
    public float nightBegin = 0.0f;
    public float nightEnd = 0.0f;
    private Light directionalLight;

    void Start()
    {
        // 获取平行光组件
        directionalLight = GetComponent<Light>();
    }

    void Update()
    {
        // 使平行光的x分量随时间增长
        transform.Rotate(Time.deltaTime * rotationSpeed, 0, 0);
        float currentXRotation = transform.localEulerAngles.x;
        if (dawnEnd <= currentXRotation && currentXRotation < dawnBegin)
        {

            float tmp = Mathf.InverseLerp(dawnEnd, dawnBegin, currentXRotation);
            directionalLight.color = Color.Lerp(dawnColor, dayColor, tmp);
            directionalLight.intensity = Mathf.Lerp(nightIntensity, dayIntensity, tmp);
        }
        else if (nightEnd <= currentXRotation && currentXRotation < nightBegin)
        {
            float tmp = Mathf.InverseLerp(nightEnd, nightBegin, currentXRotation);
            directionalLight.color = Color.Lerp(nightColor, dawnColor, tmp);

        }
    }
}
