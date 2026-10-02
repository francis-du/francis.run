---
title: "Maris: tune your computer's sound to your taste"
date: 2026-10-02T21:46:00+08:00
draft: false
url: blog/maris-studio/
images: ["/img/share/maris-studio.en.png"]
translationKey: maris-studio
image: /img/maris/maris-wordmark.svg
description: "Maris is a system audio tool I am building: separate settings for headphones and speakers, sound controls across applications, and a mixer for multiple outputs."
tags:
  - Maris
  - Rust
  - Audio
---

[![Maris](/img/maris/maris-wordmark.svg)](https://github.com/francis-du/maris)

Maris is a system audio tool. It processes sound playing on your computer, with separate settings for headphones and speakers, headphone correction, and controls for bass, treble, stereo width, and dynamics.

A player's equalizer only affects that player. Move to a video in the browser or music in another app, and you often need another setup. Maris works at the system audio layer, so one device configuration can serve different applications. Headphones and speakers can each have their own saved settings.

I want it to be an everyday tool: adjust the sound once, keep using it, and still be able to see exactly what you are changing when you want a closer look.

## Start with the headphones and speakers

The same track can have different bass, vocals, and space on different headphones. Speakers have their own characteristics too. One set of parameters will rarely suit everything.

Maris handles device correction and personal listening preferences separately.

Headphone correction uses AutoEq parameter profiles. With a matching model, its profile can adjust the relevant frequency bands. Those settings come from existing measurements; Maris does not measure your headphones, fit, or room itself.

Then you can adjust the result to your taste: a little more bass, more forward vocals, or less sharp treble. Save the parameters for that device and use them again.

I prefer being able to hear individual changes and return to earlier settings. That makes it easier to find a result I actually want to keep.

## See the adjustment and listen to the result

![The Maris sound workbench](/img/maris/maris-studio-en.svg)

*The current TUI rendered with generated test audio, showing its layout and controls.*

Maris currently has a terminal workbench and a native menu-bar entry. The main view shows the output device, correction profile, spectrum, EQ curve, and stereo levels, with common controls alongside them.

If your headphones sound light on bass, select the bass control and adjust it a step at a time. Press **B** for reference comparison. Keep the result if you like it, or use **U** to undo. A group of changes in the settings page stays in a draft until you apply it.

The EQ curve shows the changes made by the processing settings. The spectrum shows frequency energy in the incoming sound. One helps you follow your adjustments; the other helps you observe the content playing. Listening is still the final part.

Beyond EQ, Maris includes dynamic frequency processing, compression, optional virtual bass, and stereo-width controls. Compression can reduce large changes in level. Virtual bass may be useful on a small device with limited low-frequency output. The result depends on the device and content, and there is no need to enable every processor.

The menu bar is for quick output selection, scene changes, and stopping processing. The terminal workbench lays out the controls for closer adjustment. Both use the same settings and distinguish saved changes waiting to be applied from changes acknowledged by the audio thread.

## Give applications their own channels

You can begin with one output. For more detailed routing, Maris has a mixer.

Multiple applications or audio inputs can become separate channels, with volume, pan, mute, solo, EQ, and compression. Channels can feed two independent outputs.

With headphones and speakers connected, for example, you can route music to one output and another application to the other. Selected applications can also be processed individually. Application selection and route restoration depend on the platform backend.

The current native paths use CoreAudio system capture on macOS 14.2 and later, WASAPI on Windows, and a local PulseAudio service on Linux, including PipeWire's PulseAudio compatibility layer. Device compatibility still needs individual acceptance checks.

## Analyze locally while playback continues

Maris also supports local MusicNN analysis for information such as genres and instruments, as a reference while tuning. It needs the corresponding model weights. Ordinary playback and processing remain available without them or when recognition cannot produce a useful result.

Analysis runs locally without sending raw audio to a cloud recognition service. Speech noise reduction can be enabled separately on channels that need it.

A JSON CLI and MCP interface are available for automation. Programs can read status and, with write access enabled, adjust settings through the same checks and undo used by the interface. That makes it possible to use Maris in scripts or an agent workflow too.

Maris is still in development, with no public application package yet. Source, current capabilities, and documentation are on [GitHub](https://github.com/francis-du/maris). I am continuing to work on device switching, menu-bar controls, and everyday listening operations, then check them on each supported platform.
