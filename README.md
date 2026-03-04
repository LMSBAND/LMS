**LMS Plugins offered at our leisure to you for non-commercial use, under the understanding that it will not be ported as-is to any other DAW. I will update these as I like: if you don't like it, fork it. Always looking for math help.**

### https://lmsband.github.io/LMS

---

# NOTICE: THEY ARE TRYING TO STEAL YOUR COMPUTER
### INSTALL LINUX NOW

Never in my life as a wannabe hacker / computer guy / audio engineer / photographer / editor / robot builder have I ever seen anything like this. Right now, the people that used to sell us computers have decided they would rather keep all the computers to themselves. They want to stop you from owning your data, as we have known for years, but now they are coming for your autonomy, your mother fucking compute. Normal broke-ass kids like me couldn't afford a stick of ram anymore, or crack a plugin, or even own one in many cases. Subscription based, constantly hounded for your iLok, an internet connection, a demand to know who the fuck you are and if you are AUTHORIZED to use this software. Our computers waste countless cycles proving to the bank that we have indeed paid our Slate or Adobe subscriptions and can finish our project today. And now they want to put all the compute in the cloud so they can charge you for every turn of the knob, every SQL query, and access to photos of your loved ones. 

What if I told you the algorithms of all our favorite audio and visual editing software were decades old, that the only thing proprietary about any of it is the UI? A mathematical model is a truth about the world, not a copyrightable product. Our digital products are all Turing machines replicating our favorite physical machines, with math. Until now, this was difficult to access. But by stealing all of our compute and IP and building a 300 billion dollar moron, THEY have given us the key to exiting their whole fucked up world. 

AI sucks. But if you suck at computers, it is better than you, and you can use it to install Linux on your home machines. Don’t bother googling if it's going to be difficult to use your old stuff. You don't need it, and figuring it out with janky work arounds sucks ass. There’s some good Linux native stuff out there, but you can build your own shit. Get VS Code, pick an in-console agent, and tell it to start making you Reaper only JS plugins built around well-known circuitry or workflows. Tell it to make you a Python app that can import and organize your photos, and use machine learning to get rid of the accidental shutters. This stuff is free information for the world, math, gathered by science and packaged up for free use by anyone. Believe in yourself. You do not have to stay a slave to these pieces of shit. They created a monster that can be used against them and you would be stupid not to do it.

I remember a day when we used to own our tools. In some cases, it's still true today. Laguna isn't coming after me every month to hound me for cash… I bought that table saw, fair and square, and now I'm on my own with it and they can't say shit about what I choose to do with it. All audio and visual gear used to be like this, too. It's important for you to know that if you are not old enough to remember. 

I have been working on developing open source, Linux only software to replicate our favorite tools for editing photos and recording music. If anyone is interested in helping to contribute, or needs any help with taking your computer back from THEM, feel free to contact me.

https://github.com/LMSBAND
https://instagram.com/LMSSKABAND

---

## LMS Plugin Suite — Install Guide

Free, open source mixing tools for REAPER. 11 density-aware amp sims, physical room modeler, LA-2A opto compressor, drum machine, autotune, smart gate, pitch detection, and more — all sharing one DSP kernel (69 functions). Works on Linux, Mac, and Windows.

### What's included

**Amp Sims (11)**
| Plugin | What it does |
|--------|-------------|
| `lms_oj99_v2.jsfx` | Orange-style — spring reverb, tremolo, tape echo |
| `lms_basswoman_v2.jsfx` | Fender Bassman — spring, trem, echo |
| `lms_ac15_v2.jsfx` | Vox AC15 — spring, trem, echo |
| `lms_frenchie_v2.jsfx` | Frenchie — spring, tremolo |
| `lms_fridge_v2.jsfx` | Ampeg fridge — Crushinator, spring, trem, echo |
| `lms_5150_v2.jsfx` | 5150 — noise gate, spring, trem, echo |
| `lms_mesa_v2.jsfx` | Mesa Rectifier — 3 channels, noise gate, spring, trem, echo |
| `lms_punk_v2.jsfx` | JCM800 — spring, trem, echo |
| `lms_twins_v2.jsfx` | Fender Twin — spring, trem, echo |
| `lms_nightmare_v2.jsfx` | Nightmare — spring, trem, echo |
| `lms_tomasteknik_v2.jsfx` | Tomasteknik — spring, trem, echo |

**Instruments**
| Plugin | What it does |
|--------|-------------|
| `lms_drumbanger.jsfx` | Sample-based drum machine + sequencer |
| `lms_moog_synth.jsfx` | Moog-style ladder filter synth |
| `lms_drum_trigger.jsfx` | Audio-to-MIDI drum trigger |

**Channel Tools**
| Plugin | What it does |
|--------|-------------|
| `lms_channel_strip.jsfx` | Preamp, 4-band EQ, compressor, output |
| `lms_distressor.jsfx` | FET compressor / distressor |
| `lms_la2a.jsfx` | Density-aware LA-2A opto compressor |
| `lms_smart_gate.jsfx` | Density-aware noise gate (single + drum mode, cross-mic phase correction) |
| `lms_tube_sat.jsfx` | Tube saturation — warm/hot/tape/fuzz modes |
| `lms_density_limiter.jsfx` | Predictive mastering limiter |
| `lms_pitch_detector.jsfx` | Monophonic YIN pitch tracker (MIDI output) |

**Effects**
| Plugin | What it does |
|--------|-------------|
| `lms_tape_echo.jsfx` | Tape delay with wow/flutter |
| `lms_tape_machine.jsfx` | Tape saturation + spring reverb |
| `lms_reverb.jsfx` | FDN reverb with modal filtering |
| `lms_room.jsfx` | Physical room modeler — geometry-based acoustics |
| `lms_autotune.jsfx` | Real-time pitch correction (YIN, vibrato preserve, scale snap) |

**Core**
| Plugin | What it does |
|--------|-------------|
| `lms_core.jsfx-inc` | Shared DSP kernel — 69 functions — **required by all of the above** |

All plugins share state through a common memory bus (gmem). The amp's density tracker broadcasts harmonic content. The compressor reads it. The reverb reads it. One PR to lms_core makes every plugin in the suite better.

---

### Windows Install (manual)

1. Download or clone this repo
2. Open `%APPDATA%\REAPER\Effects\` in Explorer
   *(usually `C:\Users\YourName\AppData\Roaming\REAPER\Effects\`)*
3. Copy these files into that folder:
   - `lms_core.jsfx-inc` ← **required, do this first**
   - All `lms_*.jsfx` files
4. Create a subfolder called `DRUMBANGER` inside Effects and copy into it:
   - `lms_drumbanger.jsfx`
   - `DrumbangerDroneFX.jsfx`
   - `DrumbangerDroneMIDI2.jsfx`
   - The `kits/` and `pool/` folders
5. Open REAPER → Options → Preferences → Plug-ins → JS → click **Re-scan**
6. Add any LMS plugin to a track via the FX browser

For DRUMBANGER's sample browser: Actions → Run ReaScript → pick `scripts/drumbanger_service.lua`, check **"Run in background"**

---

### Linux / Mac Install (automatic)

```bash
git clone https://github.com/LMSBAND/LMS.git
cd LMS
chmod +x install.sh
./install.sh
```

Then in REAPER: Options → Preferences → Plug-ins → JS → Re-scan

---

### Session Templates (lms_save / lms_load / lms_steal)

Three ReaScripts for saving and transferring your full mixer state between projects:

- **lms_save** — snapshot all track names, faders, and full FX chains to a `.lms` file
- **lms_load** — restore a `.lms` into the current project (matches tracks by name)
- **lms_steal** — pull the mix from any other session into your current project

Install: copy the `scripts/lms_*.lua` files to your REAPER Scripts folder, then find them in Actions → Show Action List → search "LMS".
