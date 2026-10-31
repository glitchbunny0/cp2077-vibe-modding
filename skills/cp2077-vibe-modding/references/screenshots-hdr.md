# Screenshots and video of an HDR game (2.5, measured with HDR10 PQ output)

## Why normal grabs look wrong

- Every integer grab clips at SDR white. That includes `uvmod shot` (CET), a GDI `CopyFromScreen` capture, and ffmpeg's `ddagrab` in both 8-bit and 10-bit. Windows converts the frame to SDR and clips the highlights: the picture is too bright, with blown highlights.
- ffmpeg's `ddagrab` tags integer formats as sRGB, as Microsoft's documentation describes. The tag is wrong for an HDR frame.

## Capturing the HDR range

- Use `output_fmt=rgbaf16` in ffmpeg's `ddagrab`. This is scRGB linear, half-float RGBA. It is the only route measured to carry the HDR range.
- In scRGB, 1.0 is 80 nits.
- Measured on a daylight frame: 39% of pixels were above 1.0. HUD white sat at about 1.7 to 2.0. The peak was 5.2, about 415 nits.

## Tone-map recipe (single frames)

1. Divide the linear values by the paper white. The measured HUD white was about 2.0, so 2.0 was the divisor used. This value depends on the display and its settings. Re-measure on your setup.
2. Apply extended Reinhard to luminance, L' = L (1 + L / W^2) / (1 + L), with the white point W = peak / paper, here
   5.2 / 2.0 = 2.6, and scale each pixel's RGB by L' / L.
3. Apply a small gain.
4. Encode the result as sRGB.

The numpy version of this recipe produced a natural-looking frame.

## Video

- A CPU tone-map chain (zscale plus tonemap) ran at about 12 fps at 1440p on the test machine. That is not real time.
- Some ffmpeg builds lack libplacebo, so their tone-map filters differ.
- Video needs a GPU tone-mapper, such as a capture path that handles HDR (the notes name OBS and the Windows Game Bar), or else HDR turned off.
- A plain video grab does not capture game audio.

## Window and frame capture

- Capture tools refuse to grab unless the game window is in front. That is a guard, not a bug. Ask the player to switch windows.
- In a window that is not 16:9, the game renders a 16:9 image with pillarbox bars. Crop the bars before analysis.
- `uvmod shot --burst` is UE4SS-only. It is not available for CET.
