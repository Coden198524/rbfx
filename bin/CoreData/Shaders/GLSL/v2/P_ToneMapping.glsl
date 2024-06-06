#include "_Config.glsl"
#include "_Uniforms.glsl"
#include "_VertexLayout.glsl"
#include "_VertexTransform.glsl"
#include "_VertexScreenPos.glsl"
#include "_DefaultSamplers.glsl"
#include "_SamplerUtils.glsl"
#include "_GammaCorrection.glsl"

VERTEX_OUTPUT_HIGHP(vec2 vTexCoord)
VERTEX_OUTPUT_HIGHP(vec2 vScreenPos)

#ifdef URHO3D_PIXEL_SHADER

/// Reinhard tone mapping
/// 此函数将亮度值缩放到[0-1], 降低整体对比度, 同时保留明亮和黑暗区域的细节。
/// 高亮度通过大约1/L的比例进行缩放，而低亮度则按1的比例进行缩放。分母使这两种缩放方式之间的过渡变得平滑。
/// 这种公式确保所有亮度都在可显示的范围内。然而，这并不总是理想的。
vec3 Reinhard(vec3 x)
{
    return x / (1.0 + x);
}


/// Reinhard tone mapping with white point
/// 对上述公式进行扩展，以允许高亮度以可控的方式逐渐变亮。
/// 其中, white是将被映射到纯白的最小亮度。这个函数是Reinhard和线性映射之间的混合。
/// 如果white值设置为场景中的最大亮度Lmax或更高，则不会出现过曝现象。
/// 如果将其设置为无穷大，则函数Reinhard等效。默认情况下，我们将white设置为场景中的最大亮度。
/// 如果这一默认设置应用于动态范围低的场景（即Lmax < 1），效果是微妙的对比度增强。
/// 对于许多高动态范围图像，这种技术提供的压缩似乎足以在低对比度区域中保留细节，同时将高亮度压缩到可显示范围。
/// 然而，对于非常高动态范围图像，重要细节仍然会丢失。
vec3 ReinhardWhite(vec3 x, float white)
{
    return (x * (1.0 + x / (white * white))) / (1.0 + x);
}

vec3 Filmic(vec3 x) {
  vec3 X = max(vec3(0.0), x - 0.004);
  vec3 result = (X * (6.2 * X + 0.5)) / (X * (6.2 * X + 1.7) + 0.06);
  return pow(result, vec3(2.2));
}


/// Unchared2 tone mapping
/// 神秘海域色调映射算法，该算法旨在通过模仿胶片对光的响应来生成电影般且具有视觉吸引力的图像，
/// 从而提供电影色调映射算子
/// A = Shoulder Strength
/// B = Linear Strength
/// C = Linear Angle
/// D = Toe Strength
/// E = Toe Numerator
/// F = Toe Denominator
/// Note: E/F = Toe Angle
/// LinearWhite = Linear White Point Value
/// F(x) = ((x*(A*x+C*B)+D*E)/(x*(A*x+B)+D*F)) - E/F;
/// FinalColor = F(LinearColor)/F(LinearWhite)
vec3 PartialUncharted2(vec3 x)
{
    const float A = 0.15;
    const float B = 0.50;
    const float C = 0.10;
    const float D = 0.20;
    const float E = 0.02;
    const float F = 0.30;
    return ((x*(A*x + C*B) + D*E) / (x*(A*x + B) + D*F)) - E/F;
}

vec3 Uncharted2(vec3 v) 
{
    const float exposureBias = 2.0;
    vec3 curr = PartialUncharted2(v * exposureBias);

    vec3 W = vec3(11.2);
    const vec3 whiteScale = vec3(1.0) / PartialUncharted2(W);
    return curr * whiteScale;
}


#endif

#ifdef URHO3D_VERTEX_SHADER
void main()
{
    VertexTransform vertexTransform = GetVertexTransform();
    gl_Position = WorldToClipSpace(vertexTransform.position.xyz);
    vTexCoord = GetQuadTexCoord(gl_Position);
    vScreenPos = GetScreenPosPreDiv(gl_Position);
}
#endif

#ifdef URHO3D_PIXEL_SHADER
void main()
{
    vec3 finalColor = texture(sAlbedo, vScreenPos).rgb;

#ifdef REINHARD
    finalColor = Reinhard(finalColor);
#endif

#ifdef REINHARDWHITE
    finalColor = ReinhardWhite(finalColor, 4.0);
#endif

#ifdef FILMIC
    finalColor = Filmic(finalColor);
#endif

#ifdef UNCHARTED2
    const vec3 whiteScale = 1.0 / Uncharted2(vec3(4.0));
    finalColor = Uncharted2(finalColor) * whiteScale;
#endif

    gl_FragColor = vec4(LinearToGammaSpace(finalColor), 1.0);
}
#endif
