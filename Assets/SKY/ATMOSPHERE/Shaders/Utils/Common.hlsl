#ifndef _COMMON_INCLUDED
#define _COMMON_INCLUDED

#define SINGLESCATTERING
#define MULTISCATTERING
// #define TEMPORALCALCULATION
#define SAMPLELUT
// #define TESTING
/////////////////////////////////////////////////////////////////////////////////////////////////////////
#define ScatterEffectIntensity float(10)

#define HR_HM float2(8500, 1200)
#define g float(0.999) // Mie phase parameter g

#define _PlanetRadius 6371000
#define _AtmosphereRadius 6421000

#define RayleighCoefficient float3(5.19673, 12.1427, 29.6453) * 1e-6
#define MieCoefficient float3(3.996, 3.996, 3.996) * 1e-6

#define TRANSMITTANCE_TEXTURE_WIDTH 256
#define TRANSMITTANCE_TEXTURE_HEIGHT 64
#define MULTISCATTERING_TEXTURE_SIZE 32

#endif