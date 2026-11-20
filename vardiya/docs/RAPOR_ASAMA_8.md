# VARDİYA — Aşama 8 Raporu (İçerik genişletme)

Sürüm: 0.8.7 · Godot 4.7 · Compatibility renderer

# 8. KISIM: 2 saat hedefine doğru (en güncel durum)

| Sürüm | Hızlı oyuncu | Dikkatli oyuncu | Aşama 8'de eklenen tekil TR kelime |
|---|---|---|---|
| 0.7.0 (Aşama 8 öncesi) | ~25 dk | ~35 dk | — |
| 0.8.5 | ~64 dk | ~90 dk | ~10.680 |
| **0.8.7 (bu teslim)** | **~82 dk** | **~115 dk** (aralık 112-118) | **~14.960** (+ ~22.500 EN) |
| B üst hedefi | | 120 dk | |

**2 saat hedefine ~5 dakika kaldı (~800 ana yol kelimesi).** Oyundaki toplam Türkçe metin ~21.700 kelime. Aşama 8 başında ~5.100 kelimeydi.

Bölüm bölüm dikkatli oyuncu: 1: 20,1 · 2: 15,3 · 3: 14,8 · 4: 12,8 · 5: 12,0 · 6: 11,8 · 7: 11,5 · 8: 11,9 dk · epilog 3,1 · jenerik 1,9.

**Bu teslimde eklenenler:** 10 katman ana yol sahnesi ve her epiloga sona özgü bir kapanış sahnesi. Başlıcaları:

| Bölüm | Sahne |
|---|---|
| 1 | Yaşar usta ve hurdaya giden torna · hücrenin içinde bantlanmış sensör · Bayram: "Tutanak tut" · Kemal'in iş emrinin arkasına yazdığı tutanak · otoparkta radyo |
| 2 | Fırıncı · Hamdi kapıda · muhabire "bir kere söylenen doğrudur" · Rıza kamyon kuyruğundan arıyor · iki baba aynı ateşte · Defne'nin çayı demirlerin arasından |
| 3 | Liman bariyeri · Ferhat'ın zarf rafı ve açılmayan telefon · Nuri'nin konteyner hikâyesi · benzinlik · Rıza'nın eski odası ve rüya |
| 4 | Gülten teyzenin dolması · ince duvar · sarı mutfak · kavanoz kapağı · çantadaki bisküvi · uykusuz baba ile kız |
| 5 | Kurdele ve bant · Kemal'in Defne'ye sesli mesajı · Hamdi telsizde · öğleye şehir · kan bağışı kuyruğu · akşam altıda bütün düdükler |
| 6 | Hamdi ile Nevin · boş sandalye ve simitin yarısı · itfaiye raporu · "Ne diyeceğim?" · "Yarın sabah ne yapacaksınız?" |
| 7 | Sendikanın arka odası · balıkçılar · Hayriye Ana pazarda · eski albüm · mektubun arkası · mutfak lambası · sabahın beşi |
| 8 | Kol bantları · Yaşar ustanın türküsü ve sözü · Deniz'in bayrağı · Nevin'in okuduğu isimler · Hamdi'nin açık kapısı · temizlenen kapı önü |
| Epiloglar | Kooperatifin pastası · Gülten teyzenin biriktirdiği postalar · Yaşar ustanın mermere tebeşirle yazdığı yazı · aynı otobüs · üç bardak çay |

Yeni ses karakteri: Yaşar Usta. Aşama 8'de toplam 11 yan karakter eklendi; NPC sayısı 3'ten 14'e çıktı.

**Testler:**
- Doğrulayıcı: 0 hata, 2 bilinçli uyarı.
- Metin denetimi: 0 bulgu.
- Tam oyun simülasyonu: 5 sonun hepsine ulaşılıyor.
- Python testleri: 39/39.
- Motor testleri ve kare süresi: çalıştırılamadı (Godot izni yok).

**Not (tutarlılık):** Yeni sahneleri yazarken önceki kararlarla çelişen durumları koşullara bağladım:
- Bölüm 1'de sensörü gece değiştiren Kemal otoparka gitmiyor.
- Bölüm 5'te Defne babasıyla fabrikadaysa sesli mesaj sahnesi yerine ofisteki lamba sahnesi geliyor.
- Bölüm 3'te konteyneri açmayan Rıza variller hakkında konuşmuyor.
- Bölüm 2'de grevden ayrılan Defne ateşe gelmiyor.

---


# 7. KISIM: Aşama 9 hazırlığı, bu ortamda yapılabilenler

İçerik eklenmedi; süre değişmedi (dikkatli oyuncu ~90 dk, hızlı oyuncu ~64 dk). Bu teslim Aşama 8'de eklenen metni ve mekânları sağlamlaştırıyor.

**1. Metin denetimi: `tools/text_lint.py` (yeni)**

Aracın denetledikleri:
- Altyazı uzunluğu: en fazla 270 karakter. Kutu 1520 px genişliğinde ve 30 px yazı tipiyle 3 satır gösteriyor.
- Seçim metni uzunluğu: en fazla 95 karakter.
- Fazla boşluk ve noktalamadan önce boşluk.
- Dengesiz parantez ya da tırnak.
- TR ile EN arasında `{n}` gibi yer tutucuların uyuşmaması.
- Diyalog satırında son noktalama eksikliği.
- Tekrarlanan kelime ("şaka şaka", "uzun uzun", "damla damla" gibi bilinçli tekrarlar hariç).
- Sık yapılan Türkçe yazım hataları ("herşey", "yada", "kağıt", "hala"/"hâlâ").
- **Varsayılan yazı tipinde olmayabilecek karakterler.**

Sonuçlar:
- İlk çalıştırmada **gerçek bir sorun** buldu: Bölüm 3'te Defne'nin mesajındaki ❤ emojisi. Godot'nun varsayılan yazı tipinde emoji yok, büyük olasılıkla boş kutu görünecekti. Emoji çıkarıldı.
- Diğer bulgular aracın yanlış sınıflandırmasıydı; araç düzeltildi. Şu an **0 bulgu.**
- 2 yeni Python testi eklendi; toplam **39/39**:
  - Yerelleştirme dosyaları denetimden temiz geçmeli.
  - Denetim emojiyi ve uzun satırı yakalamalı.

**2. Karakterlerin baktığı yön**

Yeni 5 mekândaki aktörlerin ve evle fabrika kapısına gelen misafirlerin yönü artık tahminle değil hesapla veriliyor:
- Model önü +Z kabul ediliyor ve yön `atan2(dx, dz)` ile hesaplanıyor; bu `player_controller.face()` ile aynı formül.
- Her aktör oyuncunun başladığı noktaya bakıyor.
- Örnek: hastane koridorundaki herkes girişe, yani gelen oyuncuya dönük.

Bu, 2. kısımda yazdığım "aktörlerin yönü tahminî" varsayımını kapatıyor. Model önünün +Z olduğunu mevcut kodla ve mevcut yerleşimle (komiser `rot 90` ile oturan kişiye bakıyor) doğruladım.

**3. Hâlâ motor gerektirenler**

Bunları bu ortamda yapamıyorum:
- Motor içi testler.
- Hedef cihazda kare süresi.
- Yeni mekânlarda ışık ve kamera mesafesinin gözle ayarı.
- Uzun Türkçe satırların gerçek yazı tipiyle kaç satıra kırıldığı. Sınırı karakter sayısıyla tahmin ettim.

---


# 6. KISIM: 90 dakika eşiği

| Sürüm | Hızlı oyuncu | Dikkatli oyuncu | Aşama 8'de eklenen tekil TR kelime |
|---|---|---|---|
| 0.7.0 (Aşama 8 öncesi) | ~25 dk | ~35 dk | — |
| 0.8.4 | ~60 dk | ~84 dk | ~9.790 |
| **0.8.5 (bu teslim)** | **~64 dk** | **~90 dk** (ölçüm 89,8; aralık 87-93) | **~10.680** (+ ~16.130 EN) |

**B'nin alt sınırı olan ~1,5 saate dikkatli oyuncu için ulaşıldı.** Hızlı oyuncu ~1 saat. Bölüm bölüm dikkatli oyuncu: 1: 15,8 · 2: 11,6 · 3: 11,8 · 4: 9,4 · 5: 9,4 · 6: 9,1 · 7: 8,7 · 8: 9,2 dk · epilog 2,8 · jenerik 1,9.

**Bu teslimdeki ana yol sahneleri:**
| Bölüm | Sahne |
|---|---|
| 1 | Holün sabah sesleri ve "Kimse dokunmuyor zaten" · koridordaki güvenlik şeması ("İnsan yok iken") |
| 2 | Simitçi: "Grevciye bedava" · grev ateşinde Kemal ("Soğuk herkese aynı soğuk") · bekçi kulübesinin camında Kemal'in yansıması |
| 3 | Liman ışıkları · liman kedisi · yirmi varil ve "Yakıt az" (konteyneri açmayan oyuncuya ayrı metin) |
| 4 | Pili biten mutfak saati · gece yarısı giden Rıza |
| 5 | Soyunma odasında fotoğraf · acil çıkış okları · mavi ışıklar ve kapalı kameralar |
| 6 | Kayıttaki kamera ve mendil kutusu · koridordaki muhabir |
| 7 | Martılar ve bacanın tepesi · plansız masa · mektuptaki çay izi |
| 8 | İki yüz isimlik liste · kurul başkanının duraksaması · Hamdi'nin nöbet çizelgesi |

**Testler:**
- Doğrulayıcı: 0 hata, 2 bilinçli uyarı.
- Tam oyun simülasyonu: 5 sonun hepsine ulaşılıyor.
- Python testleri: 37/37.
- Motor testleri ve kare süresi: çalıştırılamadı (Godot izni yok).

**Sonraki seçenekler:**
1. **2 saat hedefi:** ~4.300 ana yol kelimesi daha; 2-3 teslim.
2. **Burada dur, Aşama 9'a geç:** sizin makinenizde motor testleri ve kare süresi ölçümü, yeni mekânların motorda ince ayarı (ışık, kamera, karakterlerin baktığı yön), metin redaksiyonu ve İngilizce gözden geçirme.

---


# 5. KISIM: ana yol devam

| Sürüm | Hızlı oyuncu | Dikkatli oyuncu | Aşama 8'de eklenen tekil TR kelime |
|---|---|---|---|
| 0.8.3 | ~53 dk | ~75 dk | ~8.220 |
| **0.8.4 (bu teslim)** | **~60 dk** | **~84 dk** | **~9.790** (+ ~14.800 EN) |

Bölüm bölüm dikkatli oyuncu: 1: 15,1 · 2: 10,9 · 3: 11,1 · 4: 8,9 · 5: 8,6 · 6: 8,5 · 7: 8,0 · 8: 8,3 dk · epilog 2,8 · jenerik 1,9.

**Yeni ana yol sahneleri (bu teslim):**
| Bölüm | Sahne |
|---|---|
| 1 | Hücreye girmeden önce kilit ve etiket · kolun ardından koşarak gelen Selim · Nevin'in ofisinde arazi satışı ve "iki yıl" · vardiya sonu · gece yarısı |
| 2 | Kemal kalabalığın üstünden kızını izliyor · grev alanında atkı ören yaşlı kadın |
| 3 | Sevkiyatçı Ferhat: "Zincir böyle işler" · sabah Hayriye Ana'nın kahvaltısı |
| 4 | Ocak başında Kemal · Defne babasının botlarını çıkarıyor · Kemal'in babası ve "bir yıl" |
| 5 | Özensizce bırakılmış fabrika · gece üç buçukta Nevin · sabah haberleri |
| 6 | Komiserin işçi babası · üç fotoğraf ("Hikâyesiz isim sadece suçlamadır") · akşam haberleri |
| 7 | Kapanış mektubu · mahallenin getirdiği yemekler · barışma masası · eve dönüş |
| 8 | Kurulun kâğıdı · kapıdaki mumlar · Bayram'ın megafonu ve sırayla konuşanlar · Ece'nin konuşması · pankarta bağlanan atkı |

**Testler:**
- Doğrulayıcı: 0 hata, 2 bilinçli uyarı.
- Tam oyun simülasyonu: 5 sonun hepsine ulaşılıyor.
- Python testleri: 37/37.
- Motor testleri ve kare süresi: çalıştırılamadı (Godot izni yok).

**Araç düzeltmesi:** İçerik betikleri adlarına göre alfabetik sırayla çalışıyordu, bu yüzden `layer10`, `layer3`'ten önce geliyordu. Ekleme kontrolü sıralama hatasını yakaladı. Dosya adları sıfır dolgulu yapıldı (`layer03`).

**Kalan iş:** 90 dakikaya yaklaşık 6 dakika, yani ~900 kelime kaldı. 2 saat için ~5.000 kelime gerekiyor.

---


# 4. KISIM: ana yol

| Sürüm | Hızlı oyuncu | Dikkatli oyuncu | Aşama 8'de eklenen tekil TR kelime |
|---|---|---|---|
| 0.8.2 | ~47 dk | ~67 dk | ~7.060 |
| **0.8.3 (bu teslim)** | **~53 dk** | **~75 dk** | **~8.220** (+ ~12.380 EN) |

Önceki teslimde önerdiğim gibi bu teslim **ana yola**, yani her oynanışta görülen sahnelere yazıldı. Verim belirgin biçimde arttı: ~1.160 kelime, dikkatli oyuncuya ~8 dakika ekledi. Daldaki içerikte bu oran 1.000 kelimede ~4 dakikaydı.

**Yeni sahneler:**
| Bölüm | Sahne |
|---|---|
| 1 | Bekçi Hamdi ile vardiya devri ("olmalıydı ile oldu arasındaki koridor") · üretim holünde açılış hazırlığı ve geri sayım |
| 2 | Sabah altıda baba ile kızın kısa konuşması ("Anahtar bir taraf seçmez") · kürsüye çıkmadan önce Selim · akşam sendika toplantısında oylama (yeni yan karakter Bayram; süresiz seçim) |
| 3 | Konteyner sıraları · vinççi Nuri telsizden: "Kırk yedi kokuyor" |
| 4 | Defne'nin eve dönüşü · akşam yemeğinde haberler ve "Görmek başka, bakmak başka" |
| 5 | Bekçi Hamdi ve kapalı arka rampa kamerası · şafak: itfaiye şefi ya da polis şeridi, battaniyeler, simit |
| 6 | Bekleme koridorunda Nevin: "Bir kere okumadım" |
| 7 | Üç hafta sonra: bakkalın veresiye defterinde "Fabrika" sayfası |
| 8 | Kapıya varış ve Hamdi'nin son nöbeti · kurul giderken zincir |

Yeni yan karakterler: Bayram (sendika temsilcisi), vinççi Nuri, bekçi Hamdi. Üçü de yalnızca sesle var, sahnede bedenleri yok. Aşama 8'deki yan karakter sayısı böylece 10 oldu.

**Testler:**
- Doğrulayıcı: 0 hata, 2 bilinçli uyarı.
- Tam oyun simülasyonu: 5 sonun hepsine ulaşılıyor.
- Python testleri: 37/37.
- Motor testleri ve kare süresi: çalıştırılamadı (Godot izni yok).

**Kalan iş (B hedefi ~1,5-2 saat):**
- B için planlanan 20.000 tekil kelimenin ~%41'i yazıldı. Ana yol verimiyle (1.000 kelimede ~7 dakika), 90 dakika için **~2.000 kelime daha** yetmeli; 2 saat için **~6.000 kelime**.
- Dolayısıyla 20.000 kelimenin tamamı gerekmeyebilir. Hedef süreye göre kalan iş 1-2 teslim.

---


# 3. KISIM: B devam

| Sürüm | Hızlı oyuncu | Dikkatli oyuncu | Aşama 8'de eklenen tekil TR kelime |
|---|---|---|---|
| 0.7.0 | ~25 dk | ~35 dk | — |
| 0.8.0 | ~36 dk | ~50 dk | ~3.975 |
| 0.8.1 | ~44 dk | ~61 dk | ~5.600 |
| **0.8.2 (bu teslim)** | **~47 dk** | **~67 dk** | **~7.060** (+ ~10.600 EN) |

**Bu teslimde eklenenler:**
- **Bölüm 8:**
  - Son vardiya sabahı 05.10'da evde başlıyor. Ütü masası, Sevgi kanepede, aşağıda bekleyen Rıza; çıkmadan önce masaya not bırakma seçimi.
  - Kapıya gelenlerle konuşulabiliyor: Hüsnü Hoca, Ece, Zeynep ve Deniz, Sevgi.
- **Bölüm 7:**
  - Evde 3 yeni keşif noktası: Defne'nin masası, askılıktaki üç mont, telesekreter.
  - Yalnız kalan karakterin gecesi.
  - Üç barışma konuşmasının uzun hâlleri: baba-kız, Defne-Rıza, Kemal-Rıza.
- **Bölüm 6:** Sendika avukatı Leyla Tan (yeni yan karakter, sahnede yok); sorgu odasında 2 yeni nokta.
- **Bölüm 5:**
  - Kemal'in yangındaki ilk dakikaları: kabloları sökülmüş alarm, 112.
  - Defne Nevin'in masasında Demirtaş teslimat notlarını buluyor.
  - Cevdet Rıza'ya varilleri geri getirme karşılığı borç affı teklif ediyor.
  - Kemal gece Selim'i arıyor.
- **Bölüm 3:** Liman avlusunda 2 yeni nokta. Rıhtım babasında "R + K, 1993" yazısı.
- **Bölüm 2:** Kapının iç tarafında Kemal ile Rıza.
- **Epiloglar:** Beş epilogun hepsinde bir "Sonra:" bölümü var. Sevgi, Ece, Hüsnü Hoca, Cevdet, Rıza'nın kamyonu, Deniz ve Nevin'in akıbeti, oyuncunun yan hikâyelerde yaptığı seçimlere göre değişiyor. Aynı metin beş epilogda tekrarlandığı için **ham** kelime sayısı 8.700; tabloda **tekil** sayı var.

**Toplam (Aşama 8):**
- 536 yeni düğüm.
- 25 süresiz seçim.
- 5 keşif bölümü ve mevcut keşiflere 12 yeni nokta.
- 7 yan karakter.

**Süre neden yavaş artıyor?** Yeni sahnelerin çoğu bir dala bağlı: bakış açısına, kimin yaşadığına ya da yan hikâye seçimine. Tek oynanışta oyuncu eklenen metnin ancak yaklaşık %45'ini görüyor (ölçüm: dikkatli oyuncu Aşama 8 metninden ~3.200 kelime okuyor). Bu dalların hepsi beş sonu ve tekrar oynamayı zenginleştiriyor, ama tek oynanışın süresini sınırlı uzatıyor. B hedefine (~1,5-2 saat) ulaşmak için kalan ~13.000 TR kelimenin büyük kısmını herkesin gördüğü ana yola yazmayı öneriyorum.

**Testler:**
- Doğrulayıcı: 0 hata, 2 bilinçli uyarı.
- Tam oyun simülasyonu: 5 sonun hepsine ulaşılıyor.
- Python testleri: 37/37.
- Motor testleri ve kare süresi: çalıştırılamadı (Godot izni yok).

**Araç:** Belirli düğümlerden yapılan eklemeler artık kontrol ediliyor. Hedef düğüme gitmeyen bir ekleme, sahneyi sessizce erişilemez bırakmak yerine hata veriyor. Bu kontrol bir hatayı yakaladı ve hata düzeltildi.

---


# 2. KISIM: B + D seçenekleri

## Durum özeti
| Sürüm | Hızlı oyuncu | Dikkatli oyuncu | Aşama 8'de eklenen TR kelime |
|---|---|---|---|
| 0.7.0 | ~25 dk | ~35 dk | — |
| 0.8.0 (1. kısım) | ~36 dk | ~50 dk | ~3.975 |
| **0.8.1 (bu teslim)** | **~44 dk** | **~61 dk** | **~5.620** (+ ~8.400 EN) |
| B hedefi | | ~1,5-2 saat | ~20.000 |

- **D (yeni 3B mekânlar, yan karakterler sahnede, daha uzun keşif): tamamlandı.**
- **B (20.000 kelime): yaklaşık %28'i tamamlandı.** Kalan ~14.400 Türkçe kelime ve İngilizcesi sonraki teslimlerde gelecek.

Bölüm bölüm dikkatli oyuncu: 1: 12,0 · 2: 8,1 · 3: 8,5 · 4: 6,5 · 5: 6,2 · 6: 5,7 · 7: 5,3 · 8: 4,4 dk · epilog 2,2 · jenerik 1,9.

## D — yapılanlar
**5 yeni 3B mekân.** Aşama 6'daki gibi tamamen veriyle kuruluyor, model ya da doku dosyası yok:

| Mekân | Bölüm | İçerik |
|---|---|---|
| `harbour_teahouse` (liman kahvesi) | 3 | Masalar, ocak, sessiz televizyon, tavla oynayan iki yaşlı; köşe masada Cevdet |
| `prep_school` (dershane / sınav salonu) | 2, 5 | Sıralar, tahta, deneme sıralaması; Hüsnü Hoca, Ece (Defne'nin onu sınava ikna ettiği yolda) |
| `hospital_corridor` (acil koridoru) | 5 | Floresan, bozuk çay makinesi, hemşire masası; yaşayanlar, Selim ve Zeynep |
| `station_steps` (karakol önü, akşam) | 6 | Merdivenler, sokak lambaları, siyah araba, muhabirler; bakış açısına göre Cevdet, ya da Sevgi ve Ece |
| `cemetery` (deniz kenarında mezarlık) | 7 | Kimin öldüğüne göre beliren yeni mezar taşları, servi ağaçları, bank; Zeynep ve Sevgi |

**Yan karakterler sahnede.** Sevgi, Cevdet, Ece, Hüsnü Hoca ve Zeynep'in görünüş tanımları vardı; artık bedenleriyle duruyorlar. Yeni karakter Hayriye Ana yalnızca telefonda konuşuyor.
- Kamera konuşan kişiye dönüyor.
- Ev ve fabrika kapısına "misafir" olarak geliyorlar: Bölüm 4'te Ece, Bölüm 7'de Selim, Zeynep ve bebek Deniz, Bölüm 8'in şafağında Hüsnü Hoca, Ece, Zeynep ve Sevgi. Misafirler yalnızca kendi sahnelerinde görünüyor; bunu `scene_guests` bayrağı denetliyor ve Bölüm 8 sonunda bayrak temizleniyor, böylece epiloglara sızmıyorlar.

**Daha uzun keşif.** Yeni mekânlarda 5 yeni keşif bölümü var: 15 isteğe bağlı nokta, 5 günlük notu.

1. kısımdaki 2B kart sahnelerinin hepsi artık 3B. Tek istisna Bölüm 5'teki hastane sahnesi: üç karakter de öldüyse sahne hâlâ kartla oynanıyor, çünkü yönetecek kimse kalmıyor.

## B — bu teslimde eklenen sahneler
| Bölüm | Yeni sahne |
|---|---|
| 1 | Öğle arası Defne'yle telefon (robotu anlatmak ya da anlatmamak) |
| 2 | Nevin'le bekçi kulübesinin arkasında: listeyi kim yazdırıyor, Selim için rica |
| 3 | Rıza'nın annesi Hayriye Ana: kamyon için bozdurulan bilezikler, Cevdet'in "selamı" |
| 4 | Balkonda Rıza'nın borç itirafı; Defne birikimini teklif edebilir |
| 5 | Sınav salonu (sınavı seçtiyse); yangına giden yolda Rıza |
| 6 | Komiser önceki kararları tek tek sayıyor: sensör, kapı, konteyner. Bakış açısındaki karakterin cevabı. |
| 7 | Sevgi akşam yemeğinde; son vardiyadan önceki gece limanda |
| 8 | Hüsnü Hoca'nın otuz yıl önceki on dört günlük grevi; Nevin'in son sözü |

Toplam (1. ve 2. kısım):
- **421 yeni düğüm**, **22 yeni süresiz seçim**, **5 keşif bölümü**.
- **~5.620 TR + ~8.400 EN kelime**.
- **6 yan karakter**.

Sonları belirleyen kurallar ve eski 40 karar değişmedi; yeni seçimler yalnızca yan hikâye bayraklarını değiştiriyor.

## Testler (bu teslim)
| Test | Sonuç |
|---|---|
| Doğrulayıcı | **0 hata**, 2 bilinçli uyarı. Yeni mekânların yürünebilirlik, ışık ve parçacık bütçesi ile aktör ve nokta erişimi kontrol edildi. |
| Tam oyun simülasyonu | 5 sonun hepsine ulaşılıyor; bakış açısı hatası yok |
| Python testleri | **37/37** |
| Kuşbakışı haritalar | `docs/maps/` altında 5 yeni mekân (yerleşimi gözle kontrol ettim) |
| Motor testleri, kare süresi | **Çalıştırılamadı** (Godot izni yok). 5 yeni mekân var; bütçeleri en fazla 3 ışık ve 1 parçacık sistemi, yani mevcut mekânlardan hafif. Yine de hedef cihazda ölçülmesi gerekiyor. |

## Varsayımlar (2. kısım)
1. **Yeni mekânlar yalnızca verilerle tanımlandı ve motorda hiç görülmedi.** Yerleşim kuşbakışı haritalarla kontrol edildi. Duvar, ışık ve kamera mesafesi ilk açılışta ayar isteyebilir.
2. **Aktörlerin bakış yönü (`rot`) tahminî.** Bazı karakterler konuşurken yanlış yöne bakıyor olabilir.
3. **Sınav salonu, dershane mekânının aynısını kullanıyor.**

## Sıradaki adım
B'nin kalanı: ~14.400 Türkçe kelime ve İngilizcesi. En kısa bölümlerden (7, 8, 6, 5) başlayarak birkaç teslimde gelecek. Her teslimden sonra süre ölçülecek.

---

# 1. KISIM (önceki teslim, tarihçe)

## 0. Özet ve süre konusunda dürüst durum
8 bölümün hepsine yeni sahneler ve üç kişisel yan hikâye eklendi. Ölçülen oynama süresi (`tools/playtime.py`, 200 rastgele oynanış):

| Sürüm | Hızlı oyuncu | Dikkatli oyuncu | Hikâye metni (TR) |
|---|---|---|---|
| 0.7.0 | ~25 dk | ~35 dk | ~5.100 kelime |
| **0.8.0 (bu teslim)** | **~36 dk** | **~50 dk** | **~9.100 kelime** |
| Hedef | 4-5 saat | 4-5 saat | |

**Aşama 7 raporundaki hesabım yine iyimserdi.** "~20.000 ek Türkçe kelime ile 4-5 saate ulaşılır" demiştim. Bu aşamada ölçtüğüm oran şu: **eklenen her 1.000 Türkçe kelime dikkatli oyuncuya ~4 dakika katıyor.** Oyuncu bir oynanışta metnin ancak bir kısmını görüyor; çünkü dallar, ölüm durumları ve bakış açısı değişiyor. Buna göre:
- 20.000 ek kelime ≈ dikkatli oyuncu için **~2 saat**, hızlı oyuncu için ~1,5 saat.
- 4-5 saat için **~55.000-65.000 ek kelime** gerekir. Bu, kısa bir romanın uzunluğu; İngilizcesiyle iki katı.

Bu yüzden Aşama 8'i burada bir **ara teslim** olarak durdurdum: süre hedefini birlikte yeniden belirlemeniz gerekiyor (bölüm 5'te seçenekler).

## 1. Ne yapıldı
### Yan hikâyeler (TR + EN)
| Karakter | Yan hikâye | Bölümler |
|---|---|---|
| **Kemal** | Defne'nin annesi **Sevgi**, dokuz yıl sonra arıyor. Kemal'in dolabın üst rafında sakladığı, hiç açılmamış mektuplarla dolu ayakkabı kutusu. | 1, 4, 5, 6, 7, 8 |
| **Defne** | Sınav ve dershane arkadaşı **Ece** (çağrı merkezinde gece vardiyası mı, sınav mı?). Hüsnü Hoca. Annesiyle ilk mesaj ve karakol önündeki ilk karşılaşma. İzmir'de hemşirelik sonucu. | 2, 4, 5, 6, 7, 8 |
| **Rıza** | Kamyon taksitleri için tefeci **Cevdet**'e borç. Kırk yedi numaralı konteynerin neden kabul edildiği. Kamyonun anahtarı ve kapıya gelen çekici. | 1, 2, 3, 5, 6, 7, 8 |

### Bölüm bölüm yeni sahneler
| Bölüm | Yeni sahneler |
|---|---|
| 1 Son Kontrol | Soyunma odasında Sevgi'nin telefonu · çay molası, Selim'in bebeğinin adı ve Rıza'nın borç telefonu · akşam: evde yemek **ya da** (sensörü gizlice değiştirdiyse) gece fabrikada tek başına |
| 2 Grev | Grev alanında Ece · Defne'nin akşamı: dershanede Hüsnü Hoca **ya da** grev ateşinin başında Selim ve annesinden gelen mesaj · kapıda Cevdet'in arabası |
| 3 Liman | Liman kahvesinde Cevdet'in defteri · kabinde babasının fotoğrafı ve Defne'nin "sınava götürür müsün" mesajı · sabaha karşı eve dönüş |
| 4 Aile Evi | Ece ile son tekrar · ayakkabı kutusu (Kemal verir **ya da** Defne bulur) · sınav gecesi **ya da** fabrikaya çıkış |
| 5 Gece Vardiyası | Vardiyadan önce evde (Rıza, Sevgi'nin mesajı) · şafakta hastane koridoru: kimin konuştuğu kimin yaşadığına bağlı |
| 6 İhbar | Sorguda beş dakikalık ara (bakış açısına göre Cevdet / annesi ve Ece / Zeynep) · karakol önünde akşam (Cevdet ve anahtar / Sevgi ile ilk karşılaşma / Kemal ve Sevgi) |
| 7 Hesap | Mezarlık (biri öldüyse) **ya da** Selim bebeği Deniz'le geliyor · Cevdet'in çekicisi · Defne'nin yerleştirme sonucu: İzmir |
| 8 Son Vardiya | Şafakta kapıya gelenler: Hüsnü Hoca, Ece, Zeynep ve Deniz, Selim, Rıza'nın kamyonu, Sevgi · kurul sonrası kısa kapanış |

### Sayılar
- **310 yeni düğüm**, **17 yeni seçim**, 392 yeni metin anahtarı.
- **~3.975 Türkçe kelime** + **~5.930 İngilizce kelime**.
- **5 yeni yan karakter** (konuşan, sahnede bedeni olmayan): Sevgi, Cevdet, Ece, Hüsnü Hoca, Zeynep. Görünüş tanımları `characters.json`'da, ileride sahneye konabilir.
- **18 yeni hikâye bayrağı.** Bunlar yalnızca yeni sahnelerdeki replikleri, varyantları ve dalları seçiyor.

### Sonların korunması
- **Yeni seçimlerin hiçbiri güveni, ölüm durumunu, sessizlik sayacını ya da sonları belirleyen bayrakları değiştirmiyor.** Son kuralları (`endings.json`) ve eski 40 karar aynı.
- **Yeni seçimler süresiz.** Konuşma seçimi olarak tasarlandı. Süreli olsalardı, her zaman aşımı "sessizlik" sayacını artırır ve Sır sonunu kolaylaştırırdı. 8 saniyelik süreli kararlar eskisi gibi duruyor.
- Ölüler konuşmasın diye her yeni replik ve sahne yaşam durumuna bağlandı. Bakış açısı kimdeyse sahne ona göre dallanıyor.

### Araç düzeltmeleri
- **`story_sim.py`, ilk bölüm:** Simülatör ilk bölümü yalnızca o bölümün koşullarının gördüğü değişkenlerle ayırt ediyor. Bu kesin bir yöntem. Bu düzeltme olmadan yeni seçimler durum sayısını 2,2 milyona, doğrulayıcının süresini 112 saniyeye çıkarmıştı; şimdi süre yine ~28 saniye.
- **`story_sim.py`, örnekleme:** Bölümden bölüme taşınan durumlar önce yaşam durumuna göre örnekleniyor. Yeni bayraklar örneklemi sulandırınca "herkes öldü" yolu kayboluyordu; doğrulayıcı bunu uyarıyla yakaladı.
- **`playtime.py`:** Koşulu tutmayan replikler artık sayılmıyor; motor da onları atlıyor.
- **2 yeni Python testi**, toplam 37.

## 2. Nasıl çalıştırılır
```bash
godot --path vardiya
```
Yeni sahneler yeni oyunda kendiliğinden geliyor. Eski kayıtlar da açılır: eklemeler yeni düğümler, eski düğüm kimlikleri değişmedi.

## 3. Test sonuçları (bu ortamda)
| Test | Sonuç |
|---|---|
| Doğrulayıcı | **0 hata**, 2 uyarı (önceki aşamalarla aynı, bilinçli) |
| Hikâye simülasyonu | 5 sonun hepsine ulaşılıyor, epiloglar oynanıyor |
| Python testleri | **37/37 geçti** (2'si yeni) |
| GDScript | Bu aşamada GDScript değişmedi |
| Motor içi testler | **ÇALIŞTIRILAMADI.** Godot'yu çalıştırma izni yok. |
| Kare süresi | **ÖLÇÜLEMEDİ.** Yeni 3B mekân yok; mevcut mekânlar yeniden kullanılıyor. Yükte değişiklik beklemiyorum. |
| Okuma / dil kontrolü | Metinler tarafımdan yazıldı ve gözden geçirildi; **bir editör ya da anadili İngilizce olan biri okumadı.** |

```bash
godot --headless --path vardiya res://tests/test_runner.tscn
```
```bash
godot --path vardiya --resolution 1920x1080 --fullscreen -- --benchmark
```

## 4. Varsayımlar
1. **Mekân dışı sahneler 2B kartla oynanıyor.** Liman kahvesi, dershane, hastane, karakol önü ve mezarlık için 3B mekân yapmadım; siyah arka plan, mekân adı ve altyazı var. Kart sonrası oyun ilgili 3B mekâna geri dönüyor. Yeni 3B mekânlar ayrı bir iş.
2. **Yan karakterlerin sahnede bedeni yok.** Telefonda ya da kart sahnelerinde konuşuyorlar. Ev ve fabrika sahnelerinde kamera konuşan kişiye dönmüyor.
3. **Süreler model tahmini.** Okuma hızları `tools/playtime.py` başında yazıyor.
4. **Yeni seçimlerin süresiz olması** spesifikasyondaki "süreli seçim" kuralına bir istisna. Sonları belirleyen kararların hepsi hâlâ süreli.

## 5. Karar gerekiyor: süre hedefi
| Seçenek | Ek iş | Beklenen süre (dikkatli oyuncu) |
|---|---|---|
| **A.** Bu sürümde dur, cila ve hata ayıklamaya geç | — | ~50 dk |
| **B.** Planlanan ~20.000 kelimeyi tamamla: bölüm başına 2-3 sahne daha | ~16.000 TR kelime + EN, birkaç teslimde | **~1,5-2 saat** |
| **C.** 4-5 saat hedefi | ~55.000+ TR kelime + EN | 4-5 saat; çok sayıda teslim, editör desteği önerilir |
| **D.** B'ye ek olarak oynanış süresi: yeni 3B mekânlar (hastane, liman kahvesi, dershane), yan karakterlerin sahneye konması, daha uzun keşif bölümleri | B + sanat işi | ~2-2,5 saat |

**Önerim B ya da D.** Bu türdeki oyunlar tek oynanış için genellikle 2-3 saat hedefler ve birden fazla son tekrar oynamayı teşvik eder. Beş sonu görmek, toplam oynama süresini yaklaşık 2,5 katına çıkarır.
