#ifndef STARGATE_CG_INCLUDED
#define STARGATE_CG_INCLUDED

// Photoshop-style Overlay blend
// if base <= 0.5: 2 * base * blend
// if base >  0.5: 1 - 2 * (1 - base) * (1 - blend)
inline half OverlaySingle(half base, half blend)
{
    return (base <= 0.5)
        ? 2.0 * base * blend
        : 1.0 - 2.0 * (1.0 - base) * (1.0 - blend);
}

inline half4 Overlay(half4 base, half4 blend)
{
    return half4(
        OverlaySingle(base.r, blend.r),
        OverlaySingle(base.g, blend.g),
        OverlaySingle(base.b, blend.b),
        OverlaySingle(base.a, blend.a)
    );
}

// Scalar overloads used in the shader
inline half Overlay(half base, half blend)
{
    return OverlaySingle(base, blend);
}

#endif // STARGATE_CG_INCLUDED
