# VARDİYA — NexDrive Game Studio

Seçimlere dayalı, üçüncü şahıs sinematik hikâye oyunu (Godot 4.7, Compatibility renderer).
Şu anki durum: **Aşama 1 + 2** (iskelet + hikâye motoru + deneme bölümü). Ayrıntılı rapor: `docs/RAPOR_ASAMA_1_2.md`.

## Çalıştırma

```bash
godot --path vardiya
```

```bash
godot --path vardiya -- --perf-log=user://perf.json
```

## Testler

```bash
godot --headless --path vardiya res://tests/test_runner.tscn
```

```bash
python3 vardiya/tools/validate_data.py
```

```bash
python3 -m unittest discover -s vardiya/tools/tests
```

## Kare süresi ölçümü (hedef cihazda)

```bash
godot --path vardiya --resolution 1920x1080 --fullscreen -- --benchmark
```

Rapor `~/.local/share/vardiya/perf_report.json` içine yazılır; F3 oyun içinde ölçüm katmanını açar.

## Klasörler

| Klasör | İçerik |
|---|---|
| `autoload/` | GameState, DecisionManager, DialogueRunner, SaveSystem, Localization, AudioBus, InputRouter (+ SceneLoader, PerfMonitor) |
| `data/chapters/` | Bölüm JSON'ları ve `index.json` (oynanış sırası) |
| `data/endings.json` | Son kuralları (öncelik sırası, eşikler) |
| `data/locale/` | `tr.json`, `en.json` — oyuncuya görünen tüm metin |
| `data/story_flags.json` | Bildirilmiş hikâye bayrakları ve varsayılanları |
| `ui/`, `scenes/` | Menüler, diyalog arayüzü, bölüm oynatıcı |
| `tools/` | Veri doğrulayıcı ve testleri |
| `tests/` | Motor içi (headless) testler |
| `packaging/` | NexDrive manifest taslağı, kapak, afiş |
