# WorldEnvSystem

This is a personal project of mine aimed at implementing various natural environment effects in Unity.

![showcase](https://github.com/Wunjo777/WorldEnvSystem/blob/master/showcase.png "Unity version:2022.3.17f1c1")

## Table of Contents

- [Introduction](#introduction)
- [Installation](#installation)
- [Main Content](#main-content)
  - [Useful Knowledge](#useful-knowledge)
  - [Volumetric Clouds](#volumetric-clouds)
  - [Atmospheric Scattering](#atmospheric-scattering)

### Introduction

Up to now, I have implemented volumetric clouds effects and atmospheric multiple scattering. The overall approach and the reference materials I used are listed below. Suggestions and corrections are always welcome.

This project is still ongoing and being updated......

### Installation

###### Unity Version
This project was developed using **Unity version 2022.3.17f1c1** with the Universal Render Pipeline (**URP**).

###### Usage
1. Download the zip file.
2. Extract it to a location of your choice.
3. Open the project in Unity Hub using the same version of Unity.

### Main Content

#### Useful Knowledge
- [Differences between Build-in and URP](https://zhuanlan.zhihu.com/p/147228689)
- [Custom Post-Processing Effects in Unity(URP)](https://www.bilibili.com/read/cv17805609/)
- [Reconstruct the World Space Positions of Pixels](https://docs.unity3d.com/Packages/com.unity.render-pipelines.universal@14.0/manual/writing-shaders-urp-reconstruct-world-position.html)
- [How to Use Compute Shader](https://zhuanlan.zhihu.com/p/368307575)

#### Volumetric Clouds
###### Overall Approach
The creation of volumetric clouds is based on screen-space post-processing effects and ray marching. In my project implementation, I used Axis-Aligned Bounding Box (AABB) to perform ray-box intersection tests from the camera, and draw clouds within the bounding box. The creation of volumetric clouds mainly involves the following two aspects:

- Shape: First, sample the weather map to obtain the basic shape and distribution of clouds in the sky. This is then mapped to make the cloud shapes appear more natural. Next, sample 3D Perlin-Worley noise texture to get the base density of the clouds, followed by sampling 3D Worley noise texture to add detail to the cloud density(I have already added a noise generator to this project). Finally, use other noise to apply UV perturbations to the clouds, creating an animated effect of rolling cloud layers.
- Lighting: The scattering within the cloud layers is primarily Mie scattering, typically using the HG phase function as a substitute for the more complex Mie scattering. The absorption of light by particles within the cloud layers follows Beer's Law. Here, I used a function fitted by Guerrilla, which combines Beer's Law with the "Powder Effect".

Note that the ray marching calculations for the volumetric clouds are performed in real-time and I have not yet implemented any optimizations, which may impact performance.
###### References
- [The main tutorial I followed](https://zhuanlan.zhihu.com/p/248406797)
- [A Ray-Box Intersection Algorithm](https://jcgt.org/published/0007/03/04/)
- [Fractal Brownian Motion](https://thebookofshaders.com/13/)
- [Guerrilla's Cloud System Nubis in Horizon:Zero Dawn](https://www.guerrilla-games.com/read/nubis-realtime-volumetric-cloudscapes-in-a-nutshell)
- [A Simple Video Tutorial](https://www.youtube.com/watch?v=4QOcCGI6xOU)
- [Some Optimization Techniques](https://zhuanlan.zhihu.com/p/622654876)

#### Atmospheric Scattering

