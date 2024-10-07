using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ExecuteInEditMode]
[RequireComponent(typeof(Renderer))]
public class CloudShadow : MonoBehaviour
{
    private Renderer ObjRenderer = null;
    private Shader ObjShader = null;
    void Awake()
    {
        ObjRenderer = GetComponent<Renderer>();
        ObjShader = ObjRenderer && ObjRenderer.sharedMaterial ? ObjRenderer.sharedMaterial.shader : null;
        CheckSupport();
    }

    void CheckSupport()
    {
        if (!SystemInfo.SupportsRenderTextureFormat(RenderTextureFormat.Depth))
        {
            Debug.LogWarning("ScreenSpaceCloudShadow has been disabled as it's not supported on the current platform.");
            enabled = false;
        }
        ObjRenderer.enabled = enabled;
        if (!ObjShader || !ObjShader.isSupported)
        {
            Debug.LogWarning("ScreenSpaceCloudShadow has been disabled as it's not support shader.");
            ObjRenderer.enabled = false;
            enabled = false;
        }
    }

    void Start()
    {
        OnWillRenderObject();
    }

    void OnEnable()
    {
        if (Camera.main)
            Camera.main.depthTextureMode |= DepthTextureMode.Depth;
    }


    void OnWillRenderObject()
    {
        Camera cam = Camera.main;
        float dist = cam.farClipPlane - 0.1f;
        Vector3 campos = cam.transform.position;
        Vector3 camray = cam.transform.forward * dist;
        Vector3 quadpos = campos + camray;
        transform.position = quadpos;

        Vector3 scale = transform.parent ? transform.parent.localScale : Vector3.one;
        float h = cam.orthographic ? cam.orthographicSize * 2f : Mathf.Tan(cam.fieldOfView * Mathf.Deg2Rad * 0.5f) * dist * 2f;
        transform.localScale = new Vector3(h * cam.aspect / scale.x, h / scale.y, 0f);

        bool isGameView = Camera.current == null || Camera.current == Camera.main;
        if (isGameView)
        {
            transform.rotation = Quaternion.LookRotation(quadpos - campos, cam.transform.up);
        }
    }
}