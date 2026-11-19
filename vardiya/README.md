# VARDİYA — NexDrive Game Studio

Seçimlere dayalı, üçüncü şahıs sinematik hikâye oyunu (Godot 4.7, Compatibility renderer).
Şu anki durum: **Aşama 5** — 8 bölüm + 5 son, her son için final sahnesi (epilog), son kartı, kredi ve oyunlar arası "Sonlar" galerisi. Raporlar: `docs/RAPOR_ASAMA_1_2.md`, `docs/RAPOR_ASAMA_3.md`, `docs/RAPOR_ASAMA_4.md`, `docs/RAPOR_ASAMA_5.md`; sonlara test yolları: `docs/SON_TEST_YOLLARI.md`.

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
python3 vardiya/tools/story_sim.py --game
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
| `data/chapters/` | Bölüm JSON'ları, epiloglar (`ep0*`) ve `index.json` (oynanış sırası, epilog listesi) |
| `data/endings.json` | Son kuralları (öncelik sırası, eşikler), her sonun epilogu ve galeri ipucu |
| `data/credits.json` | Kredi metni |
| `data/locale/` | `tr.json`, `en.json` — oyuncuya görünen tüm metin |
| `data/story_flags.json` | Bildirilmiş hikâye bayrakları ve varsayılanları |
| `data/locations/` | Gri kutu mekânlar (kutular, ışıklar, başlangıç ve etkileşim noktaları) |
| `data/characters.json` | Konuşmacılar (oynanabilir + NPC), renkler |
| `scenes/world/` | Mekân kurucu, oyuncu, kamera, dünya görünümü |
| `ui/`, `scenes/` | Menüler, diyalog arayüzü, bölüm oynatıcı |
| `tools/` | Veri doğrulayıcı ve testleri |
| `tests/` | Motor içi (headless) testler |
| `packaging/` | NexDrive manifest taslağı, kapak, afiş |
