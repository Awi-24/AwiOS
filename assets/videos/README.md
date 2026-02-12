# Boot animation

The boot screen uses the GIF `awiOS.gif`.

## Converting video to GIF

If you have `awiOS.mp4`, convert with:

**FFmpeg:**
```bash
ffmpeg -i awiOS.mp4 -vf "fps=15,scale=480:-1:flags=lanczos" -c:v gif awiOS.gif
```

**Online:** [ezgif.com](https://ezgif.com/video-to-gif) or [cloudconvert.com](https://cloudconvert.com/mp4-to-gif)

Place `awiOS.gif` in this folder.
