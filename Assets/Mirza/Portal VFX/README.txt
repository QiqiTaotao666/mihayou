1. To fully be able to take advantage the portal effects, including depth and passthrough, you MUST have both Depth Texture and Opaque Texture enabled in URP.
2. For custom post-processing lighting and grid projection, see the renderer feature setup for Mirza Beig/Portal VFX/Settings/URP-PortalVFX-Renderer.
-- You must add Full Screen Pass Renderer Features with the Portal Glow materials to your URP renderer settings in order to use the custom post-processing effects.

If you're on Unity 6, you will need to manually set up the URP renderer features with Compatibility Mode enabled.

LIVE DOCUMENTATION:
> https://mirzabeig.notion.site/Portal-Shaders-VFX-14f8c1476e31809aae58cd00876d6438

RELEASE NOTES:

v1.0.2 | December 01, 2024:

- Added live docs.
- Fixed SphereWaveManager memory leak.

v1.0.1 | November 30, 2024:

- Reorganized project folder structure.

v1.0.0 | November 21, 2024:

- First release.