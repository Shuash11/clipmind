/// What's-new release notes, keyed by version.
///
/// Each entry is a full line INCLUDING the `* ` prefix — the user's exact
/// requested format (`* api fixed` newline, `* features added`). Filled
/// from the cycle commit summaries; the dialog renders the lines as-is.
const Map<String, List<String>> releaseNotes = {
  '1.8.0': [
    '* Transparent activity UI: live step pipeline, persisted steps, confirmation gates',
  ],
  '1.9.0': [
    '* Modern dark theme redesign with ProjectHub refresh',
  ],
  '1.10.0': [
    '* Project-read tools, plan preview mode, analysis persistence',
  ],
  '1.11.0': [
    '* Ollama tool calling via OpenAI-compatible transport',
  ],
  '1.12.0': [
    '* NVIDIA NIM tool calling',
  ],
  '1.13.0': [
    '* Gemini tool calling via native generateContent',
  ],
  '1.14.0': [
    '* Real status bar, provider-aware round timeouts',
  ],
  '1.15.0': [
    '* Timed transcript segments in get_transcript',
  ],
  '1.16.0': [
    '* Burn captions: timed transcript SRT burning',
  ],
  '1.17.0': [
    '* Transitions: xfade cross-fades with clip-pair replacement',
  ],
  '1.18.0': [
    '* Effects library: vignette, blur, grayscale, contrast, saturation',
    '* Audio-aware transitions',
  ],
  '1.19.0': [
    '* Fixed runtime provider wiring: profile-driven resolution',
  ],
  '1.20.0': [
    '* Custom OpenAI-compatible profiles',
    '* Status bar shows the resolved model',
  ],
  '1.21.0': [
    '* Provider conformance suite',
    '* NIM live model discovery with a 49-model catalog',
  ],
  '1.22.0': [
    '* Working undo and redo',
    '* Manual timeline editing: delete, copy, reorder',
    '* Cut range selection on the timeline',
  ],
  '1.24.0': [
    '* CapCut-style panels: Effects, Text, Audio',
    '* Font picker with bundled open fonts',
    '* Add sound to clips (amix)',
    '* NVIDIA model dropdown auto-populates after key entry',
    '* Back button on the AI providers page',
  ],
  '1.25.0': [
    '* Playhead with scrubbing and click-to-seek',
    '* Non-destructive trim handles',
    '* Split at the playhead',
    '* Timeline zoom with Ctrl+wheel',
  ],
  '1.26.0': [
    '* Fixed clip range after cuts (display, AI view, and follow-up edits stay correct)',
  ],
  '1.27.0': [
    '* Fixed ranged cuts on trimmed clips',
    '* Full export test suite',
    '* Fixed a potential export hang',
    '* Live-verified FFmpeg gates',
    '* Code-graph freshness enforcement',
  ],
  '1.28.0': [
    '* Riverpod 3 upgrade with preserved semantics',
    '* Removed unused dependencies',
  ],
  '1.29.0': [
    '* Riverpod 3 test hardening (ProviderContainer.test across the suite)',
    '* Removed dead providers (project metadata, export progress)',
    '* Provider-platform registry provider renamed; import hides removed',
    '* Injected settings-repository seams for quieter test logs',
  ],
  '1.30.0': [
    '* Update verification: release digests checked before install',
    '* Fixed the broken ZIP update path',
  ],
  '1.31.0': [
    '* Transitions panel: one-click cross-fades between clips',
    '* Release-body download names fixed; digest gate added',
  ],
  '1.32.0': [
    '* Adjustments panel: brightness, contrast, saturation, speed, volume',
    '* Speed changes re-time the clip range correctly',
    '* Ranged speed restriction (exact for trimmed clips)',
  ],
  '1.33.0': [
    '* Fixed composed edits with audio-only ops (volume+speed now render)',
    '* Fixed silent audio desync in multi-op edits',
    '* Fixed undefined filter labels in composed graphs',
  ],
  '1.34.0': [
    '* Fixed composed watermark edits (watermark + other ops now render)',
    '* Watermark live-verified through real FFmpeg',
  ],
  '1.35.0': [
    '* Fixed the update install failing while ClipMind was running',
    '* New ClipMind branding: app icon, installer icon, wizard images',
  ],
  '1.36.0': [
    '* ZIP updates work on default installs (script moved to temp)',
    '* App relaunches automatically after updates',
    '* Clear error guidance when the install folder is write-protected',
    '* Hub logo now uses the ClipMind brand mark',
  ],
};
