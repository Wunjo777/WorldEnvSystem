#ifndef _ATMOSMATH_INCLUDED
#define _ATMOSMATH_INCLUDED

#include "Assets/SKY/ATMOSPHERE/Shaders/Utils/Common.hlsl"

#define PI 3.1415926535

// 确保根号内部的数大于等于0
float safeSqrt(float a)
{
	return sqrt(max(0.0f, a));
}

// 求直线与球交点坐标
// 直线方程：ray(t)=rayOrigin+t*rayDir
// 球方程：∣p−sphereCenter∣^2 = sphereRadius^2
// 返回交点对应t值
float2 RaySphereIntersection(float3 rayOrigin, float3 rayDir, float3 sphereCenter, float sphereRadius)
{
	rayOrigin -= sphereCenter;
	float a = dot(rayDir, rayDir);
	float b = 2.0 * dot(rayOrigin, rayDir);
	float c = dot(rayOrigin, rayOrigin) - (sphereRadius * sphereRadius);
	float judge = b * b - 4 * a * c;
	if (judge < 0)
	{
		return float2(0, 0);
	}
	else
	{
		judge = safeSqrt(judge);
		return float2(-b - judge, -b + judge) / (2 * a);
	}
}

float RayleiPhase(float cos)
{
	return (3.0 / (16.0 * PI)) * (1.0 + cos * cos);
}

float MiePhase(float cos)
{
	return (3.0 / (8.0 * PI)) * ((1.0 - g * g) / (2.0 + g * g)) * ((1.0 + cos * cos) / (pow(abs(1.0 + g * g - 2 * g * cos), 1.5)));
}

float GetTextureCoordFromUnitRange(float x, int texture_size)
{
	return 0.5 / float(texture_size) + x * (1.0 - 1.0 / float(texture_size));
}

float GetUnitRangeFromTextureCoord(float u, int texture_size)
{
	return (u - 0.5 / float(texture_size)) / (1.0 - 1.0 / float(texture_size));
}

float2 GetTransmittanceLutUv(float bottomRadius, float topRadius, float r, float mu)
{
	float H = safeSqrt(topRadius * topRadius - bottomRadius * bottomRadius);
	float rho = safeSqrt(r * r - bottomRadius * bottomRadius);
	float discriminant = r * r * (mu * mu - 1.0f) + topRadius * topRadius;
	float d = max(0.0f, (-r * mu + safeSqrt(discriminant)));
	float d_min = topRadius - r;
	float d_max = rho + H;
	float x_mu = (d - d_min) / (d_max - d_min);
	float x_r = rho / H;
	float uv_x = GetTextureCoordFromUnitRange(x_mu, TRANSMITTANCE_TEXTURE_WIDTH);
	float uv_y = GetTextureCoordFromUnitRange(x_r, TRANSMITTANCE_TEXTURE_HEIGHT);
	return float2(uv_x, uv_y);
}

float2 GetTransmittanceLutRmu(float bottomRadius, float topRadius, float2 uv)
{
	float x_mu = GetUnitRangeFromTextureCoord(uv.x, TRANSMITTANCE_TEXTURE_WIDTH);
	float x_r = GetUnitRangeFromTextureCoord(uv.y, TRANSMITTANCE_TEXTURE_HEIGHT);
	float H = safeSqrt(topRadius * topRadius - bottomRadius * bottomRadius);
	float rho = H * x_r;
	float r = safeSqrt(rho * rho + bottomRadius * bottomRadius);
	float d_min = topRadius - r;
	float d_max = rho + H;
	float d = d_min + x_mu * (d_max - d_min);
	float mu = d == 0.0f ? 1.0f : (H * H - rho * rho - d * d) / (2.0f * r * d);
	mu = clamp(mu, -1.0f, 1.0f);
	return float2(r, mu);
}

float2 calDensity(float3 p, float planetRadius)
{
	float h = abs(length(p - PlanetCenter)) - planetRadius;
	float2 localDensity = exp(-(h.xx / HR_HM));
	return localDensity;
}

float2 calOpticalDepth(float planetRadius, float3 pSt, float3 pEd)
{
	const int N_SAMPLE = 32;
	float3 dir = normalize(pEd - pSt);
	float dis = length(pEd - pSt);
	float step = dis / N_SAMPLE; // 步长
	float3 p = pSt + dir * step * 0.5;
	float2 totalOpticalDepth = 0;
	for (int i = 0; i < N_SAMPLE; i++)
	{
		p += dir * step;
		float2 localDensity = calDensity(p, planetRadius);
		totalOpticalDepth += localDensity * step;
	}
	return totalOpticalDepth;
}

// 计算大气透视查找表
float2 calOpticalDepthLut(float r, float mu)
{
	const int N_SAMPLE = 64;
	float cos = -mu;
	float dis = r * cos + safeSqrt(r * r * (cos * cos - 1) + _AtmosphereRadius * _AtmosphereRadius);
	float step = max(0, dis) / N_SAMPLE;
	float2 totalOpticalDepth = 0;
	for (int i = 0; i < N_SAMPLE; i++)
	{
		float b = i * step;
		float h = safeSqrt(r * r + b * b - 2 * r * b * cos) - _PlanetRadius;
		totalOpticalDepth += float2(exp(-(h.xx / HR_HM))) * step;
	}
	return totalOpticalDepth;
}

// 计算多重散射查找表
float3 calMultiscatteringLut(float3 samplePoint, float3 lightDir, Texture2D _TransmittanceLut, SamplerState sampler_TransmittanceLut)
{

	const int N_DIRECTION = 64;
	const int N_SAMPLE = 64;
	float3 RandomSphereSamples[64] = {
		float3(-0.7838, -0.620933, 0.00996137),
		float3(0.106751, 0.965982, 0.235549),
		float3(-0.215177, -0.687115, -0.693954),
		float3(0.318002, 0.0640084, -0.945927),
		float3(0.357396, 0.555673, 0.750664),
		float3(0.866397, -0.19756, 0.458613),
		float3(0.130216, 0.232736, -0.963783),
		float3(-0.00174431, 0.376657, 0.926351),
		float3(0.663478, 0.704806, -0.251089),
		float3(0.0327851, 0.110534, -0.993331),
		float3(0.0561973, 0.0234288, 0.998145),
		float3(0.0905264, -0.169771, 0.981317),
		float3(0.26694, 0.95222, -0.148393),
		float3(-0.812874, -0.559051, -0.163393),
		float3(-0.323378, -0.25855, -0.910263),
		float3(-0.1333, 0.591356, -0.795317),
		float3(0.480876, 0.408711, 0.775702),
		float3(-0.332263, -0.533895, -0.777533),
		float3(-0.0392473, -0.704457, -0.708661),
		float3(0.427015, 0.239811, 0.871865),
		float3(-0.416624, -0.563856, 0.713085),
		float3(0.12793, 0.334479, -0.933679),
		float3(-0.0343373, -0.160593, -0.986423),
		float3(0.580614, 0.0692947, 0.811225),
		float3(-0.459187, 0.43944, 0.772036),
		float3(0.215474, -0.539436, -0.81399),
		float3(-0.378969, -0.31988, -0.868366),
		float3(-0.279978, -0.0109692, 0.959944),
		float3(0.692547, 0.690058, 0.210234),
		float3(0.53227, -0.123044, -0.837585),
		float3(-0.772313, -0.283334, -0.568555),
		float3(-0.0311218, 0.995988, -0.0838977),
		float3(-0.366931, -0.276531, -0.888196),
		float3(0.488778, 0.367878, -0.791051),
		float3(-0.885561, -0.453445, 0.100842),
		float3(0.71656, 0.443635, 0.538265),
		float3(0.645383, -0.152576, -0.748466),
		float3(-0.171259, 0.91907, 0.354939),
		float3(-0.0031122, 0.9457, 0.325026),
		float3(0.731503, 0.623089, -0.276881),
		float3(-0.91466, 0.186904, 0.358419),
		float3(0.15595, 0.828193, -0.538309),
		float3(0.175396, 0.584732, 0.792038),
		float3(-0.0838381, -0.943461, 0.320707),
		float3(0.305876, 0.727604, 0.614029),
		float3(0.754642, -0.197903, -0.62558),
		float3(0.217255, -0.0177771, -0.975953),
		float3(0.140412, -0.844826, 0.516287),
		float3(-0.549042, 0.574859, -0.606705),
		float3(0.570057, 0.17459, 0.802841),
		float3(-0.0330304, 0.775077, 0.631003),
		float3(-0.938091, 0.138937, 0.317304),
		float3(0.483197, -0.726405, -0.48873),
		float3(0.485263, 0.52926, 0.695991),
		float3(0.224189, 0.742282, -0.631472),
		float3(-0.322429, 0.662214, -0.676396),
		float3(0.625577, -0.12711, 0.769738),
		float3(-0.714032, -0.584461, -0.385439),
		float3(-0.0652053, -0.892579, -0.446151),
		float3(0.408421, -0.912487, 0.0236566),
		float3(0.0900381, 0.319983, 0.943135),
		float3(-0.708553, 0.483646, 0.513847),
		float3(0.803855, -0.0902273, 0.587942),
		float3(-0.0555802, -0.374602, -0.925519),
	};
	const float uniform_phase = 1.0 / (4.0 * PI);
	const float sphereSolidAngle = 4.0 * PI / float(N_DIRECTION);

	float3 G_2 = float3(0, 0, 0);
	float3 f_ms = float3(0, 0, 0);

	for (int i = 0; i < N_DIRECTION; i++)
	{
		// 光线和大气层求交
		float3 viewDir = RandomSphereSamples[i]; // 随机采样球面积分方向
		float dis = RaySphereIntersection(samplePoint, viewDir, PlanetCenter, _AtmosphereRadius).y;
		float d = RaySphereIntersection(samplePoint, viewDir, PlanetCenter, _PlanetRadius).x;
		if (d > 0)
			dis = min(dis, d);
		float ds = dis / float(N_SAMPLE);
		float2 dpa = 0;
		float3 p = samplePoint + (viewDir * ds) * 0.5;

		for (int j = 0; j < N_SAMPLE; j++)
		{
			float r = length(p - PlanetCenter);
			float3 upVector = normalize(p - PlanetCenter);
			float mu = dot(upVector, lightDir);
			float2 transLutUv = GetTransmittanceLutUv(_PlanetRadius, _AtmosphereRadius, r, mu);
			float2 dcp = _TransmittanceLut.SampleLevel(sampler_TransmittanceLut, transLutUv, 0).rg;
			float3 t1 = exp(-(dcp.x * RayleighCoefficient + dcp.y * MieCoefficient));

			// calculate t2
			float2 dens = calDensity(p, _PlanetRadius);
			dpa += dens * ds;
			float3 t2 = exp(-(dpa.x * RayleighCoefficient + dpa.y * MieCoefficient));

			// calculate scattering
			float2 locDens = calDensity(p, _PlanetRadius);
			float cos = dot(lightDir, viewDir);
			float3 scatteringR = locDens.x * RayleighCoefficient * RayleiPhase(cos);
			float3 scatteringM = locDens.y * MieCoefficient * MiePhase(cos);
			float3 s = scatteringR + scatteringM;

			float3 sigma_s = locDens.x * RayleighCoefficient + locDens.y * MieCoefficient;

			// 用 1.0 代替太阳光颜色, 该变量在后续的计算中乘上去
			G_2 += t1 * s * t2 * uniform_phase * ds * 1.0;
			f_ms += t2 * sigma_s * uniform_phase * ds;

			p += viewDir * ds;
		}
	}

	G_2 *= sphereSolidAngle;
	f_ms *= sphereSolidAngle;
	return G_2 * (1.0 / (1.0 - f_ms));
}

#endif