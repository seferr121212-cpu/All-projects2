# Varlıklar (Assets)

Bu ortamın ağ politikası Kenney, Quaternius, Poly Pizza, OpenGameArt ve Freesound'u
engellediği için Aşama 1'deki tüm modeller ve sesler **kodla üretildi**:

| Ne | Nerede | Not |
|---|---|---|
| Ağaç, çay çalısı, kaya, çimen, çiçek, ev, saman, karavan, yolcu | `scripts/world/lowpoly_meshes.gd` | Düz gölgeli low-poly, vertex renkli |
| Rüzgâr, yağmur, cırcır böceği, kuş, gök gürültüsü, motor | `scripts/audio/procedural_audio.gd` | Sentezlenmiş yer tutucu |

Prosedürel varlıklar sanat stiliyle uyumlu, ama gerçek paketler kaliteyi artırır.
Elle indirip aşağıdaki klasörlere koyman yeterli. Sonra ben bağlarım.

## Önerilen CC0 paketler

| Paket | Kaynak | Klasör | Kullanım |
|---|---|---|---|
| Kenney **Nature Kit** | kenney.nl/assets/nature-kit | `assets/models/kenney_nature/` | Ağaç, kaya, çit, köprü |
| Kenney **Car Kit** | kenney.nl/assets/car-kit | `assets/models/kenney_cars/` | Karavan/jeep alternatifi |
| Quaternius **Ultimate Stylized Nature** | quaternius.com | `assets/models/quaternius_nature/` | Daha zengin bitki örtüsü |
| Quaternius **Ultimate Modular Men/Women** | quaternius.com | `assets/models/quaternius_people/` | Esnaf NPC'leri (Aşama 3) |
| Kenney **Interface Sounds** + **Impact Sounds** | kenney.nl/assets | `assets/audio/kenney_ui/` | UI ve etkileşim sesleri |
| Ortam sesleri (rüzgâr, yağmur, kuş, dere) | freesound.org (yalnızca **CC0** filtreli) | `assets/audio/ambience/` | `AudioManager` katmanları |

**Dosya biçimi:** modeller `.glb`/`.gltf`, sesler `.ogg` (döngüler için) veya `.wav`.
Lisans dosyalarını (`License.txt`) paket klasöründe bırak.
