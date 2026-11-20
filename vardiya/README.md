# VARDİYA — NexDrive Game Studio

Seçimlere dayalı, üçüncü şahıs sinematik hikâye oyunu (Godot 4.7, Compatibility renderer).
Şu anki durum: **Aşama 6** — sanat geçişi: gri kutuların yerine stilize düşük poligon prop'lar, çalışma anında üretilen 512 px dokular, animasyonlu karakter gövdeleri, mekân atmosferi (gökyüzü, ışık hüzmesi, parçacık, titreyen ışık) ve epilog ışık varyantları. 8 bölüm + 5 son, epiloglar, son kartı, kredi ve "Sonlar" galerisi önceki aşamalardan. Raporlar: `docs/RAPOR_ASAMA_1_2.md` … `docs/RAPOR_ASAMA_6.md`; sonlara test yolları: `docs/SON_TEST_YOLLARI.md`.

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
| `data/locations/` | Mekânlar: çarpışma kutuları + prop türü (`kind`), malzeme (`mat`), duvar stili, gökyüzü, ışıklar (hale / hüzme / titreme), parçacıklar, koşullu varyantlar |
| `data/characters.json` | Konuşmacılar (oynanabilir + NPC), renkler, görünüm (`look`) |
| `scenes/world/` | Mekân kurucu, prop kiti, mesh birleştirici, malzeme/doku kiti, karakter gövdesi, ortam animasyonu, oyuncu, kamera |
| `ui/`, `scenes/` | Menüler, diyalog arayüzü, bölüm oynatıcı |
| `tools/` | Veri doğrulayıcı ve testleri |
| `tests/` | Motor içi (headless) testler |
| `packaging/` | NexDrive manifest taslağı, kapak, afiş |
