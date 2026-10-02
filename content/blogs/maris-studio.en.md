---
title: "Maris: building an audio console I would want to use"
date: 2026-10-02T21:46:00+08:00
draft: false
url: blog/maris-studio/
images: ["/img/share/maris-studio.en.png"]
translationKey: maris-studio
image: /img/maris/maris-wordmark.svg
description: "Maris is a local audio tool I am building. This round is about making its interface as considered as its device correction, sound controls, and mixer."
tags:
  - Maris
  - Rust
  - Audio
  - TUI
---

[![Maris](/img/maris/maris-wordmark.svg)](https://github.com/francis-du/maris)

[Source](https://github.com/francis-du/maris) · [Project and documentation](https://github.com/francis-du/maris#maris)

The spectrum is an easy distraction when working on Maris.

Make a set of bars move with the sound, add some color and stereo meters, and a terminal starts to feel like audio equipment. But I still need to know which output is in use, which correction is active, and whether the parameter I just changed has reached the audio processor.

Those details deserve as much attention as the moving bars. That is what I want to address in this round of interface work.

Maris is still in development. A public application release has not been completed. The [repository's release notes](https://github.com/francis-du/maris#release-policy) track the remaining native, packaging, and device checks. This article describes the current implementation and direction; it does not offer an installer for a release that is not available yet.

## Start with one pair of headphones and one pair of speakers

Maris processes audio playing on the computer. It can keep settings for different outputs, apply headphone correction, and adjust bass, treble, stereo width, and compression.

Device correction and listening preferences are separate. Correction has a source and a device it applies to; preferences describe how I want to listen. After switching outputs, the interface must not leave me guessing whether the previous device's settings are still active.

The native capture paths differ. macOS 14.2 and later use CoreAudio system capture. Windows uses WASAPI application capture. Linux connects to a local PulseAudio service, including PipeWire's PulseAudio compatibility layer.

The backends share settings and processing logic, but routing remains platform-specific. The normal macOS system-audio path does not require BlackHole. Application selection and mixer routing have their own confirmation and recovery steps. The [architecture document](https://github.com/francis-du/maris/blob/main/docs/reference/architecture.md) describes those differences.

## Give the main screen a proper workbench

![The Maris Studio interface](/img/maris/maris-studio-en.svg)

*This image uses [the current TUI code](https://github.com/francis-du/maris/commit/afa26e853304a2a17a4871977fef44bab539e7cd), rendered with generated test audio. It is not a hardware listening-session capture.*

The analyzer, calculated EQ curve, and stereo levels occupy the center. Spectrum data comes from audio analysis. The EQ curve comes from the current settings; it must not look like a measured headphone response.

Output, correction, and processing state need stable locations. Sound controls have visible selection and adjustment targets. Output choice, presets, settings, comparison, and undo are reachable from the main screen.

I want some visual character here. Real audio already provides good material for it. There is no need to animate invented measurements just to keep the screen lively. Color and highlights should follow genuine state; missing measurements should leave a quiet display.

Terminals vary, too. Some support true color, others only a small palette. Reducing motion should preserve numbers, labels, and controls. A console intended for regular use has to work beyond one screenshot size and one terminal emulator.

## Moving the cursor should not change the sound

One particularly unsettling interaction is browsing a control and finding that the sound has already changed.

The Maris settings page separates current values from an unapplied draft. Arrows and scrolling browse. Adjustment controls edit the draft. Apply or Cancel finishes the edit. Presets also show their content before confirmation.

A preview cannot remain valid if the device or relevant settings change before application. The device shown in the preview must be the device the confirmed change will affect.

Saving is different from applying. Writing the settings does not mean the audio thread has received and acted on them. The interface needs to show that pending state so the listener can understand what is currently audible.

A/B comparison estimates the relative loudness and attenuates the louder branch to reduce volume bias. It is not instrument-calibrated loudness matching. Undo belongs to the relevant changes on the current device; it should not roll another device's settings back along with them.

## Music recognition must not interrupt playback

Maris also has local MusicNN analysis for some genre and instrument information. Its weights are handled by the corresponding build workflow. An ordinary `cargo build --release` does not automatically embed them.

Normal processing remains available when a model is missing, fails to load, or produces uncertain results. Listening suggestions can use measured signal information, such as spectrum and peaks. If reliable semantic information is unavailable, the interface should not invent a genre to fill the space.

Raw audio does not need to be uploaded to a music-recognition service. Speech denoising has a separate purpose and is explicitly enabled per channel; it is not a default music-enhancement control.

For more involved setups, the mixer accepts multiple applications or inputs. Each strip has gain, pan, mute, solo, EQ, and compression, with two independent outputs. The TUI, CLI, menu bar, and MCP share settings validation. MCP starts read-only and requires explicit write enablement; it does not provide another route around confirmation.

## The release work includes less visible details

This round also exposed installer and audit issues. A native Windows test encountered a script-path representation problem. A large dependency tree made a `grep -q` pipeline close early and miss a security finding. Neither is visible in the spectrum, but both matter to a functioning release package.

Offline DSP tests, model execution, native CI, device recovery, and listening checks establish different things. The limiter constrains digital sample peaks; that is not a hearing-protection claim.

If I eventually ask people to pay for Maris, I want to hand them a tool they can understand: what changed, what is still pending, and what cannot currently be confirmed. The analyzer should look good. The Stop control should remain easy to find.
