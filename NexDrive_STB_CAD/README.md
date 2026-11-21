# NexDrive STB Power Unit – Montaj CAD Modeli

Kaynak: *NexDrive STB Ünite AR-GE Hesap Raporu v7* (12.11.2026). Tüm ana ölçüler rapordan alınmıştır; her parçanın hangi bölüme dayandığı BOM'da yazılıdır.

## Dosyalar

| Dosya | İçerik |
|---|---|
| `stb_model.py` | Parametrik CadQuery modeli (tek komutla tüm çıktıları üretir) |
| `out/NexDrive_STB_Montaj.step` | Tam montaj, 186 katı parça (Fusion/SolidWorks/CATIA'ya aktarılabilir) |
| `out/step/NN_*.step` | 18 montaj adımının her biri ayrı STEP |
| `out/NexDrive_STB_Montaj.glb` | Web/AR görüntüleme için mesh |
| `out/BOM_parca_listesi.csv` | Parça listesi (Excel, `;` ayraçlı) |
| `viewer/index.html` | 3B montaj görüntüleyici (adım, patlatma, kesit) |

## Ana parametreler

Çap 72 · strok 73,6 · biyel 128 · bore pitch 84 · gömlek 3,0 (köprü 6,0) · deck 193,3 mm · pentroof 2×14° · supap E Ø27,5 / Eg Ø23,5 · kaldırma 8,5 / 7,5 · VCR-P taç hareketi 1,97 mm.

Koordinatlar: X krank ekseni (−X ön/zincir tarafı), −Y emme, +Y egzoz/turbo, Z yukarı, Z=0 krank ekseni. Gösterim konumu: 1. silindir ateşleme ÜÖN, VCR-P düşük CR (9,2).

## Montaj sırası ve parçalar

### 1. Silindir bloğu
_Al döküm blok, cast-in gri dökme demir gömlekler_

| Parça | Adet | Malzeme | Ana ölçüler | Rapor § |
|---|---|---|---|---|
| Silindir bloğu | 1 | AlSi7Mg0,3 T6 (LPDC) | 372×190×193 mm, bore pitch 84, köprü 6,0 mm, açık deck | 3.1, 10.1, 13.1 |
| Silindir gömleği | 4 | Gri dökme demir, cast-in | Ø72 / Ø78 × 135 mm, et 3,0 mm | 3.1, 10.2, 13.1 |

### 2. Piston soğutma jetleri
_4 adet Ø1,5 mm jet, 2,8 bar açma_

| Parça | Adet | Malzeme | Ana ölçüler | Rapor § |
|---|---|---|---|---|
| Piston soğutma jeti | 4 | Çelik | Ø1,5 mm nozul, Cd 0,70, açma 2,8 bar | 5.2, 13.4 |

### 3. Krank mili ve ana yatak grubu
_5 ana yatak, bedplate (yatak iskeleti)_

| Parça | Adet | Malzeme | Ana ölçüler | Rapor § |
|---|---|---|---|---|
| Krank mili | 1 | Dövme çelik (42CrMo4) | Strok 73,6 (r 36,8), ana muylu Ø48, biyel muylusu Ø42, 180° flat | 1.1, 4, 21 |
| Ana yatak iskeleti (bedplate) | 1 | AlSi9Cu3 + çelik insert | 372×190×45 mm, 5 ana yatak | 3, 21 |
| Ana yatak burçları (5 çift) | 1 | Çelik/Al-Sn kaplama | Ø48 × 18 mm, et 1,8 | 21 |

### 4. Balans şaftları (VCR-P varyantı)
_2× ters dönen, 2× devir_

| Parça | Adet | Malzeme | Ana ölçüler | Rapor § |
|---|---|---|---|---|
| Balans şaftı | 2 | Çelik | m·e ≈ 2,3 g·m, 2× krank devri, ters yönlü | 4, 15.5, 21 |

### 5. Piston – biyel grubu (VCR-P)
_İki parçalı piston, segman, pim, biyel_

| Parça | Adet | Malzeme | Ana ölçüler | Rapor § |
|---|---|---|---|---|
| VCR-P üst taç | 4 | Dövme Al 2618-T61 | Ø72, 3 segman yuvası, supap cebi E 5,8 / Eg 4,9 mm, hareket 1,97 mm | 15.2, 20.1, 20.4 |
| VCR-P alt gövde | 4 | Dövme Al 2618-T61 | Ø71,6 etek, pim deliği Ø19 | 15, 20.1 |
| Dayanma halkası | 4 | 42CrMo4, preslenmiş | Ø56 / Ø51 mm, alan 420 mm², 97 MPa | 20.1, 20.2 |
| Kilit pimi seti | 4 | 42CrMo4 nitrürlü | 2× Ø6 radyal, 3,0–3,5 bar geçiş, yay 5–8 N | 20.1–20.3 |
| Piston pimi | 4 | Çelik (içi boş DLC) | Ø19 / Ø11 × 58 mm, 62 g | 4 |
| Segman seti | 4 | Çelik / dökme demir | 3 segman: 1,2 / 1,5 / 2,0 mm | 4, 21 |
| Biyel | 4 | Dövme çelik, yağ kanallı | L = 128 mm (λ 0,2875), büyük uç Ø42, küçük uç Ø19, Ø2,5 yağ kanalı | 1.1, 20.3, 21 |

### 6. Yağlama: pompa ve karter
_Değişken debili pompa, emiş, karter_

| Parça | Adet | Malzeme | Ana ölçüler | Rapor § |
|---|---|---|---|---|
| Yağ karteri | 1 | Al döküm / çelik sac | 372×190 mm, sump 300×160, ≈ 4,5 L | 5 |
| Değişken debili yağ pompası | 1 | Al gövde, vane tip | 11 cc/dev, 2 kademe, röle 5 bar | 5.1, 13.4, 21 |
| Yağ emiş borusu ve süzgeç | 1 | Çelik | Ø18 boru, süzgeç Ø44 | 5 |

### 7. Tahrik plakası ve krank sensörü
_Flexplate (CVT), 60-2 tetik tekerleği_

| Parça | Adet | Malzeme | Ana ölçüler | Rapor § |
|---|---|---|---|---|
| Tahrik plakası (flexplate) + marş dişlisi | 1 | Çelik sac | Ø286, CVT tork konvertörüne bağlanır (damper'sız) | 6, 11.2, 13.5 |
| Krank tetik tekerleği 60-2 | 1 | Çelik | Ø112, 58 diş + 2 boşluk | 7.3, 7.9 |
| Krank konum sensörü (Hall) | 1 | Plastik gövde | Hall, tek cıvata flanşlı | 7.3, 7.9 |

### 8. Silindir kapağı grubu
_MLS conta, DOHC 16V kapak, supap takımı, kapak cıvataları_

| Parça | Adet | Malzeme | Ana ölçüler | Rapor § |
|---|---|---|---|---|
| Kapak contası (MLS) | 1 | Çok katlı çelik | 0,7 mm, bore Ø74, kalibre su delikleri Ø4–7 | 3.1, 10.3 |
| Silindir kapağı DOHC 16V | 1 | AlSi7Mg T6 / AlSi10Mg | Pentroof 28°, emme Ø27,5 / egzoz Ø23,5, M10 buji, 84 mm pitch | 1.3, 3.3, 8.4, 10.1 |
| Eksantrik yatak kepleri (10) | 1 | Al | Ø30 yatak, 20 mm genişlik | 3.3 |
| Supap emme | 8 | Emme: çelik / Egzoz: Ni-Cr, sodyum dolgulu ops. | Ø27.5, sap Ø5,5, kaldırma 8.5 mm | 1.3, 8.1 |
| Supap egzoz | 8 | Emme: çelik / Egzoz: Ni-Cr, sodyum dolgulu ops. | Ø23.5, sap Ø5,5, kaldırma 7.5 mm | 1.3, 8.1 |
| Supap yayı | 16 | Si-Cr yay çeliği | Ø22 ort., ön yük ≥ 384 N, k ≈ 29 N/mm | 7.2 |
| Supap tutucu | 16 | Çelik | Ø23 | 7.2 |
| Kovan itici | 16 | Çelik, DLC | Ø30 × 18, ayar pulu | 7.2 |
| Kapak cıvatası M10×1,25 12.9 | 10 | 12.9 alaşımlı çelik | Ön yük 38,7 kN, tork + açı (30 Nm + 2×90°) | 3.2, 10.1 |

### 9. Eksantrik, çift VVT ve zincir
_2 eksantrik, 2 faz ayarlayıcı, duplex zincir, gergi, zincir kapağı_

| Parça | Adet | Malzeme | Ana ölçüler | Rapor § |
|---|---|---|---|---|
| Eksantrik mili | 2 | Çelik (kütükten taşlama) | Taban Ø36, kaldırma 8.5 mm, süre 274.0° KA, LSA 107° | 8.1, 7.2 |
| VVT faz ayarlayıcı | 2 | Çelik/Al, kanatlı | Kanatlı tip, aralık 50° KA, kilit pimi | 14.1, 8.2 |
| OCV solenoid | 2 | Plastik/çelik | 4/3 oransal, PWM 250–300 Hz | 14.1 |
| Krank zincir dişlisi | 1 | Çelik | Ø50, 2:1 oran | 21 |
| Duplex triger zinciri | 1 | Çelik | Duplex, gergi + kılavuz | 21 |
| Zincir gergisi + pabuç | 1 | Hidrolik gergi, PA66 pabuç | Hidrolik, yağ beslemeli | 21 |
| Zincir kılavuzu | 1 | PA66 | Sabit kılavuz | 21 |
| Zincir kapağı (ön kapak) | 1 | Al döküm | Krank keçesi Ø34 | 21 |

### 10. Ateşleme ve kam kapağı
_M10 buji, COP bobin, kam kapağı_

| Parça | Adet | Malzeme | Ana ölçüler | Rapor § |
|---|---|---|---|---|
| M10 buji | 4 | Cu çekirdek, 2 kademe soğuk, ince elektrot | M10, ısı derecesi 2 kademe soğuk, aralık 0,7 mm | 3.3, 13.2 |
| COP bobin | 4 | Plastik gövde | Gövde Ø ≤ 20, ≥ 28 kV, 60–80 mJ | 7.5 |
| Kam kapağı (külbütör kapağı) | 1 | PA66-GF / Al | 372×180×52 mm, COP delikleri Ø24 | 7 |

### 11. Emme sistemi ve yakıt
_Plenum, runner, gaz kelebeği, enjektör, yakıt rayı_

| Parça | Adet | Malzeme | Ana ölçüler | Rapor § |
|---|---|---|---|---|
| Emme manifoldu (plenum + runner, TCV entegre) | 1 | PA6-GF30 | Plenum ≤ 2,5 L, runner Ø34, TCV (alt %60 kesit) | 1.3, 8.4, 2.4 |
| Elektronik gaz kelebeği (drive-by-wire) | 1 | Al gövde | Ø50 kelebek, çift TPS | 7.3 |
| Enjektör | 4 | Plastik/çelik | ≥ 200 cc/dk @ 3,5 bar, EOI IVO'dan 20–40° önce | 7.4 |
| Yakıt rayı | 1 | Paslanmaz çelik | Ø22, 3,5 bar sabit fark | 7.4 |

### 12. Egzoz ve turbo
_Twin-scroll manifold, K03 twin-scroll, EWG, downpipe_

| Parça | Adet | Malzeme | Ana ölçüler | Rapor § |
|---|---|---|---|---|
| Twin-scroll egzoz manifoldu (1-4 / 2-3) | 1 | 1.4828 / 321 paslanmaz | Kol Ø38×1,5 (iç Ø35), kol boyu 150–200 mm, flanş 10 mm | 19.2, 7.6 |
| Turbo türbin gövdesi (twin-scroll, A/R 0,65–0,70) | 1 | Ni-Resist / paslanmaz | BorgWarner K03 twin-scroll, T3 ≤ 1273 K | 2.3, 19.1 |
| Turbo yatak gövdesi (CHRA, su soğutmalı) | 1 | Dökme demir | Motor yağı + su soğutma | 19.1 |
| Turbo kompresör gövdesi | 1 | Al döküm | TD025/K03 sınıfı, D2 42–46 mm, PR 2,14 | 2.2, 19.1 |
| Elektronik wastegate aktüatörü (rotary) | 1 | Al/plastik | Etkin alan ≥ 196 mm², valf Ø22 | 2.3, 9.2 |
| Downpipe + yakın bağlı katalizör girişi | 1 | Paslanmaz | Ø56, katalizör ısıtma (bölüm 13.3) | 13.3 |

### 13. Soğutma ve yağ filtresi
_Su pompası, termostat, yağ filtresi_

| Parça | Adet | Malzeme | Ana ölçüler | Rapor § |
|---|---|---|---|---|
| Mekanik su pompası | 1 | Al gövde | 154 L/dk @6000, Δp 1,2 bar | 5.3, 10.3 |
| Termostat gövdesi + ECT sensörü | 1 | PA66 / Al | Termostat → radyatör, bypass | 10.3 |
| Yağ filtresi + modül | 1 | Çelik kartuş | Ø76 × 95 | 5 |

### 14. Ön aksesuar tahriki
_Krank kasnağı, alternatör, gergi, kayış_

| Parça | Adet | Malzeme | Ana ölçüler | Rapor § |
|---|---|---|---|---|
| Krank kasnağı (torsiyon damperli) | 1 | Çelik/kauçuk | Ø150, PK kayış | 7.7 |
| Alternatör (OAD kasnaklı) | 1 | Al gövde / Cu sargı | 110–140 A @14 V, kasnak oranı 2,3–2,6 | 7.7 |
| Su pompası kasnağı | 1 | Çelik | Ø100 | 5.3 |
| Kayış gergisi | 1 | Çelik/Al | Otomatik gergi Ø70 | — |
| Kanallı kayış (PK) | 1 | EPDM | 6PK | 7.7 |

### 15. Hydro-Turbo
_Rotrex C15-60, hidrolik motor + 1:2 dişli, pompa, tank, akümülatör_

| Parça | Adet | Malzeme | Ana ölçüler | Rapor § |
|---|---|---|---|---|
| Hidrolik pompa 10 cc + elektromanyetik kavrama | 1 | Çelik/Al | 10 cc/dev, klima kompresörü konumunda | 18.2, 18.3 |
| Rotrex C15-60 yardımcı kompresör | 1 | Al, traction drive | 0,22 kg/s, PR 2,35, 150.000 / 11.840 d/d, 2,9 kg | 18.1 |
| Hidrolik motor 3,2 cc + 1:2 dişli kademe | 1 | Çelik/Al | Flanşlı 1:2 hız artırıcı | 18.2, 18.3 |
| Baypas klapesi Ø50 + HT valf bloğu | 1 | Al | Kompresöre paralel, Ø50 | 18.2 |
| Hidrolik tank 2 L + filtre + hava-yağ soğutucu | 1 | Al / plastik | HLP 46, 10 µm dönüş filtresi | 18.2 |
| Akümülatör 4 L, 250+ bar (şasi rayı) | 1 | Çelik | Egzozdan ≥ 250 mm uzak, ısı kalkanı arkası | 18.2, 18.3 |
| Hidrolik hortumlar (basınç / dönüş) | 1 | Hidrolik hortum | Ø12 | 18.2 |

### 16. Şarj havası hattı
_Intercooler 300×200×76, boost boruları_

| Parça | Adet | Malzeme | Ana ölçüler | Rapor § |
|---|---|---|---|---|
| Intercooler çekirdeği 300×200×76 (≈4,5 L) | 1 | Al, ofset şerit kanat | UA ≈ 224 W/K, ε 0,85, Δp ≤ 50 mbar | 2.4, 9.3 |
| Intercooler giriş / çıkış tankları | 1 | Al döküm | Hacim ≤ 2,5 L (kompresör sonrası) | 2.4, 9.3 |
| Boost borusu: turbo → Rotrex | 1 | Al boru / silikon | Ø54 | 18.2 |
| Boost borusu: Rotrex → intercooler | 1 | Al boru / silikon | Ø54 | 18.2 |
| Boost borusu: intercooler → gaz kelebeği | 1 | Al boru / silikon | Ø54, boru içi ≤ 20 mbar | 2.4 |

### 17. Sensörler
_Vuruntu ×2, kam fazı ×2, MAP_

| Parça | Adet | Malzeme | Ana ölçüler | Rapor § |
|---|---|---|---|---|
| Vuruntu sensörü | 2 | Piezo | Sil. 1-2 / 3-4 arası, 20 Nm, band 5–9 kHz | 7.9, 12.2 |
| Kam fazı sensörü | 2 | Hall | VVT konum geri beslemesi | 7.3, 14.1 |
| MAP + IAT sensörü (plenum) | 1 | Plastik | Plenum basınç/sıcaklık, speed-density | 7.3 |

### 18. Motor takozları
_M1 hidrotakoz, M2 şanzıman takozu, M3 roll sınırlayıcı_

| Parça | Adet | Malzeme | Ana ölçüler | Rapor § |
|---|---|---|---|---|
| M1 sağ motor takozu (hidrotakoz) | 1 | Hidrotakoz, Shore A 55 | Yük %45, kz 311 N/mm | 11.1 |
| M2 sol takoz (şanzıman tarafı) | 1 | Kauçuk, Shore A 55 | Yük %40, kz 276 N/mm | 11.1 |
| M3 roll sınırlayıcı (burç tipi) | 1 | Kauçuk, Shore A 65–70 | Yük %15, kz 104 N/mm | 11.1 |

## Modelin sınırları

- Ön tasarım (konsept) geometrisidir: parçalar doğru ölçü, konum ve arayüzlerle yerleştirildi, ancak döküm detayları (su ceketi çekirdekleri, yağ galerileri, fileto/eğim açıları) basitleştirildi.
- Kam profili rapordaki sin^1,5 başlangıç eğrisidir; nihai profil polidin sentezle yapılmalıdır (§8.1).
- Hidrolik akümülatör şasi rayında; modeldeki konumu temsilidir. CVT, radyatör, hava filtresi kapsam dışı.
- Sonraki adım: STEP dosyası Fusion'a alınıp FEA (§3.1, §10.1 yük durumları) ve supap–piston boşluğu kontrolü (§20.4).

## Yeniden üretme

```bash
pip install cadquery
python3 stb_model.py
```
