# mpv daily Debian package autobuilder

This repo builds mpv (with ffmpeg + libass via `mpv-build`) into a `.deb` every day.
A GitHub Release is **only** created when upstream sources changed since the last successful build.

## How it works

- CI clones `mpv-player/mpv-build`, runs `./update`, and collects commit hashes from:
  - `mpv/`, `ffmpeg/`, `libass/`, and `libplacebo/`.
- If hashes match the last run (stored on a `state` branch), the workflow exits early.
- If anything changed, it builds with Debian tooling and publishes a Release with the new `.deb`.

## Manual run

You can trigger a manual build from the Actions tab (it will still skip if nothing changed).

## Optional ffmpeg options

If you want to enable extra encoders, add lines to `ffmpeg_options` in the CI step (see the
commented section in the workflow). Example:

```

--enable-libx264
--enable-libmp3lame
--enable-libfdk-aac
--enable-nonfree

```

## Artifacts / outputs

- GitHub Release with:
  - `mpv_<version>_<arch>.deb`
  - `BuildLog.txt` (full build log)
  - `hashes.txt` (the upstream commit hashes for this build)

## Notes

- The build runs on `ubuntu-latest` and installs build-deps from `debian/control` via
  `mk-build-deps -s sudo -i`.
- If you fork this repo, no extra tokens are needed; the default `GITHUB_TOKEN` is enough to push
  the state branch and create releases.
