# VARDİYA — NexDrive Game Studio

Seçimlere dayalı, üçüncü şahıs sinematik hikâye oyunu (Godot 4.7, Compatibility renderer).
Şu anki durum: **Aşama 3** — Bölüm 1 "Son Kontrol" gri kutu 3D mekânlarla oynanabilir. Raporlar: `docs/RAPOR_ASAMA_1_2.md`, `docs/RAPOR_ASAMA_3.md`.

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

```bash
python3 vardiya/tools/story_sim.py ch01_last_check
```

```bash
python3 vardiya/tools/render_map.py
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
| `data/locations/` | Gri kutu mekânlar (kutular, ışıklar, başlangıç ve etkileşim noktaları) |
| `data/characters.json` | Konuşmacılar (oynanabilir + NPC), renkler |
| `scenes/world/` | Mekân kurucu, oyuncu, kamera, dünya görünümü |
| `ui/`, `scenes/` | Menüler, diyalog arayüzü, bölüm oynatıcı |
| `tools/` | Veri doğrulayıcı ve testleri |
| `tests/` | Motor içi (headless) testler |
| `packaging/` | NexDrive manifest taslağı, kapak, afiş |
