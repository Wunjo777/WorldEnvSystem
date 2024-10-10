using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class LUTCalController : MonoBehaviour
{
    public ComputeShader computeShader;
    public Material theSkyBox;
    private int _TransmittanceKernel;
    private int _MultiscatteringKernel;
    private RenderTexture transmittanceTex;
    private RenderTexture multiscatteringTex;

    // Start is called before the first frame update
    void Start()
    {
        ///////////////////////////////Transmittance Part///////////////////////////////
        _TransmittanceKernel = computeShader.FindKernel("TRANSmittance");
        // Create RenderTexture
        transmittanceTex = new RenderTexture(256, 64, 0, RenderTextureFormat.ARGBFloat);
        transmittanceTex.enableRandomWrite = true;
        transmittanceTex.Create();
        // Assign the texture to the material
        theSkyBox.SetTexture("_TransmittanceLut", transmittanceTex);
        // Assign the texture to the compute shader
        computeShader.SetTexture(_TransmittanceKernel, "TransmittanceResult", transmittanceTex);
        // Dispatch the compute shader
        computeShader.Dispatch(_TransmittanceKernel, 32, 8, 1);
        ///////////////////////////////Multiscattering Part///////////////////////////////
        _MultiscatteringKernel = computeShader.FindKernel("MULTIscattering");
        // Create RenderTexture
        multiscatteringTex = new RenderTexture(32, 32, 0, RenderTextureFormat.ARGBFloat);
        multiscatteringTex.enableRandomWrite = true;
        multiscatteringTex.Create();
        // Assign the texture to the material
        theSkyBox.SetTexture("_MultiscatteringLut", multiscatteringTex);
        // Assign the texture to the compute shader
        computeShader.SetTexture(_MultiscatteringKernel, "_TransmittanceLut", transmittanceTex);
        computeShader.SetTexture(_MultiscatteringKernel, "MultiscatteringResult", multiscatteringTex);
        // Dispatch the compute shader
        computeShader.Dispatch(_MultiscatteringKernel, 4, 4, 1);
    }

    // Update is called once per frame
    void Update()
    {

    }
}
