# SON NÖBET — THE LAST WATCH
NexDrive Game Studio · Godot 4.7.2 · tek bölümlük hikayeli savunma FPS'i (FAY HATTI altyapısıyla)

## Hikaye
Kartaltepe Hudut Karakolu, rakım 2.870 m. Aşağıda bulut denizi, yukarıda yıldızlar; arada on dört kişi:
Yüzbaşı Kerem Aksoy ve on üç er. Sen Er Emre'sin, kuzey mevzisindesin.

03:35'te yüzbaşı timi toplar: istihbarat bölgede hareketlilik bildirmiştir, sis yüzünden hava desteği yoktur.
03:58'de kuzey mevzideki Er Yusuf yamaçta, kayaların arkasına yerleşen kalabalık bir grup görür. 04:00'te
yamaçtan atılan bir roket jeneratörü vurur, projektörler söner, her yer zifiri karanlığa gömülür.
Telsizci Hasan merkezi arar: takviye çıkmıştır ama sis yüzünden saat altıdan önce ulaşamaz.

Saat 06:00'ya kadar, yani GERÇEK ZAMANDA iki saat boyunca karakolu timinle savunacaksın.
- 06:00'ya dayanırsan güneş bulut denizinin üstünden doğar, helikopterler iner, karakol düşmez.
  Son ekranda şehit düşen arkadaşlarının adları yazar.
- Tim tamamen düşerse oyun kaybedilir.

## Savaş düzeni (gerçek zamanlı, 2 saat)
- **4 mevzi:** Kuzey, doğu, güney ve batı yamaçta, zirvenin hemen altına oyulmuş, üstü tomruk + kum
  torbası + karla kapalı mevziler. Arkadan zirveye siper hendeğiyle bağlanır. Sen kuzey mevzidesin
  (yüzbaşı ve 3 er yanında), diğer üç mevzide üçer er var.
- **40 mevzilenmiş terörist:** Dört yanda (her yönde ~10), 35-80 m aşağıda kayaların arkasındalar.
  Açıkta yürümezler: kayanın arkasına çöker, doğrulup seri atar, yine çökerler. Namlu alevi ve izli
  mermi yerlerini ele verir.
- **Döngü (6 dk):** 5 dakika yoğun ateş (sipere çiviler; ayağa kalkıp uzun süre açıkta kalan vurulur),
  1 dakika nefes (ateş neredeyse durur). Her 6 dakikada bir düşmanın eksikleri tamamlanır.
- **Mermi:** İki silahla toplam en fazla 110 (MPT-76: 20+60, tabanca: 17+13). Cephane sandığı
  karakol binasının içinde, telsiz odasında (E basılı tut): her seferinde yalnız 1 tüfek şarjörü
  (20 mermi), 3 dakikada bir. El bombası vermez. Mevziden çıkıp
  hendekten binaya koşmak gerekir; zirveye havan düşer.
- **Görüş:** Zifiri karanlık + hafif sis, gece görüş yok. Düşmanı namlu alevi, izli mermi ve
  aydınlatma fişekleri ele verir.
- **Kayıt noktası:** Her 15 dakikada bir. Ölürsen oradan, o andaki tim durumuyla devam edersin.

## v6: hikâye, müzik, arayüz
- **Erlerin kişiliği:** 12 erin ve yüzbaşının memleketi ve kısa hikâyesi var. Baskından önce sundurmada
  sohbet sahnesi (03:28). Nefes dakikalarında kendi laflarını ederler. Şehit olunca adı ve kim olduğu yazılır.
- **Müzik (sentez, `tools/ses_uretici/muzik.py`):** nefes dakikasında gerilim, şehit olunca iki ağır nota,
  şafakta zafer teması.
- **Vurma hissi:** vurduğun terörist bağırır (uzaktan, yankılı); öldürünce yanındaki er haber verir.
  Ağır yaralanan er de bağırır.
- **Kapanış:** helikopterlerden sonra 06:10 yoklaması: her şehit için kara saplanmış tüfek ve kask,
  ayakta kalanlar karşısında, isimler tek tek okunur.
- **Askerler:** kask ve omuzlarda kar tabakası.
- **Alt panel:** sol altta sağlık çubuğu, kanama damlası ve sargı ikonları; sağ altta panel zemini ve
  yedek şarjör ikonları (gerçekçi modda).
- İnsan sesi (seslendirme) hâlâ yok: `audio/voice/` klasörüne kayıt koyunca çalar.

## v5: görsel detay
- Tahta kaplama (tek tek tahtalar, ek yerleri, çiviler): bina zemini / tavanı, sundurma, mevzi tabanı, hendekler.
- Hendeklerde tahta duvar kaplaması, dikmeler ve ızgara tahta.
- Bina içi: tavan kirişleri, yastık / battaniye, tabureler, dolap kapakları, kask rafı, gerçek tüfekli silahlık,
  detaylı telsiz, eş yükselti eğrili harita, soba detayları, pencerelerde karartma perdesi, yarı saydam cam.
- Avlu: kırmızı-beyaz nöbetçi kulübesi, karakol tabelası, su deposu, tuvalet kulübesi, kar işaret direkleri,
  kürek, paletler, anten gergi telleri, helikopter pistinde H işareti ve kırmızı lambalar.
- Lamba haleleri ve fotoğraflardaki soğuk mavi-yeşil renk tonu.

## v4: ses, animasyon, model
- **Sesler (122 dosya, `audio/sfx/`):** Python ile sentezlendi (`tools/ses_uretici/sentez.py`), kayıt değil.
  Tüfek / tabanca (yakın), AK ve PKM (uzaktan, dağ yankılı), kurşun şaklaması ve sekme, kara / kum
  torbasına / kayaya / ahşaba / metale isabet, patlama (dökülen toprak + uzun gürleme), RPG, havan ıslığı,
  aydınlatma fişeği, kar üstünde adım, ahşap döşemede adım, kovan, kalp, nefes, sargı, telsiz mandalı,
  dağ rüzgârı (rafikalı, dam altında boğulur), jeneratör, helikopter, siren.
  Gerçek kayıt koymak için aynı klasöre .wav at (bkz. `audio/sfx/SES_LISTESI.txt`).
- **Animasyonlar (`tools/anim_yaz.py` ile yazıldı):** Cover_Crouch (sipere çökme), Kneel_Fire, Reload_Cover
  (şarjör değiştirme), Treat_Kneel (sargı), Wounded_Lie (sırtüstü yaralı), Run_Rifle (koşu) + klipler
  arası yumuşak geçiş. Erler ateş edip çöker, 20 atışta şarjör değiştirir; yaralı yatar, arkadaşı
  diz çöküp sarar. Teröristler artık yere gömülmüyor: kayanın arkasına çömelip doğruluyor.
- **Modeller:** Çiğnenmiş kar patikaları, direkler arası kablolar ve güneş panelleri, mevzi içinde loş
  kırmızı karartma lambası + yaşam izleri (boş kovanlar, uyku tulumu, çay bardağı, atış kartı), bina
  içinde çaydanlık, duvar bayrağı, nöbet çizelgesi, işleyen duvar saati, parkalar, postallar.

## v3: gerçekçilik paketi
- **Can sistemi:** Can kendiliğinden dolmaz. Vurulunca kanama başlar; [H] basılı tutarak sargı yapılır
  (3 sargı taşırsın, koğuştaki ilk yardım çantasında 9 tane daha var). Yanındaki ağır yaralı eri de
  aynı tuşla sararsın; sarılmazsa kan kaybından ölür (bazen mevzi arkadaşı sarar).
- **Baskı:** Yakın patlamada kulak çınlaması ve sarsıntı, soğukta nefes buharı.
- **Düşman:** Her yönde bir PKM (uzun, izli seriler), ara sıra RPG, yakına gelen hücum timleri
  (koş - yat - ateş et), yakın kayalardan el bombası. Hücum tutmazsa geri çekilirler.
- **Senaryolu olaylar:** 04:10 anten vurulur (yedek telsizi çalıştır), 04:21 / 04:50 / 05:20 bir
  mevzi cephane ister (sandığı taşı), 04:33 sis bastırır + hücum, 04:46 havancı vurulur (fişeği
  kendin at: havan çukuru, baktığın yöne), 05:00 / 05:15 / 05:30 büyük hücumlar.
- **Boş mevzi:** Bir mevzide savunan kalmaz ve hücum timi yakın kayalara varırsa 2 dakika içinde
  oraya gitmezsen karakol düşer.
- **Tim sesi:** Erler altyazıyla bağırır (şarjör, namlu alevi, yaralı, roket, bomba).
- **Gerçekçi arayüz (Ayarlar > Oynanış, varsayılan açık):** nişangâh, mermi sayısı, vuruş onayı,
  tim sayacı ve geri sayım yok. [T] ile şarjörü tartarsın ("yarım", "bitmek üzere"...).
- **Tuşlar:** [H] sargı, [T] şarjör kontrol, [E] etkileşim, [G] el bombası.

## Tim (AI)
- 12 er + yüzbaşı, dört mevzinin atış aralıklarında.
- Kendi yönlerindeki teröristlere ateş ederler: doğrulanı gördüklerinde nişanlı seri, kaya arkasındakine
  bastırma atışı. Gece uzak mesafede isabetleri düşüktür; oyuncunun katkısı belirleyicidir.
- Vurulurlar, yaralanırlar (9 sn vurulmazlarsa toparlanırlar), şehit düşebilirler.
- Yüzbaşı düşerse komutayı telsizci Hasan alır.
- Teröristler oyuncuyu görmese de erlere ateş eder.

## Görsel
- **Ana menü:** Namlu fotoğrafı (yavaş yaklaşma, film greni).
- **Zirve arazisi:** Kayalık, yarıklı yamaçlar. Kuzey ve güneyde 50 m'lik tırmanış, batıdan ikmal yolu,
  doğu sırtında helikopter pisti (`tools/tepe_gen.py`).
- **Atmosfer:** Zifiri karanlık gece (bulut arkasında soluk ay, hafif kar, hafif sis). 05:15'ten sonra mavi saat, 06:00'da turuncu ufuk
  ve doğan güneş (gönderdiğin fotoğraflardaki atmosfer). Zirvenin altında bulut denizi.
- **Karakol (gönderdiğin fotoğraflara göre):**
  - Yeşil-gri bindirmeli ahşap bina, beşik çatı, doğu ucunda sundurma, tabela
  - İçine girilebilir: koğuş (ranzalar, dolaplar, masa) ve telsiz odası (telsiz, harita, soba,
    silah rafı, cephane sandığı, gaz lambası)
  - Dalgalanan Türk bayrağı (gönderdiğin bayrak görseli) ve kar tepeciğinde Atatürk büstü
  - 4 üstü kapalı yamaç mevzisi ve siper hendekleri
  - Jiletli tel (mevzilerin önünde)
  - Jeneratör ve yakıt varilleri (04:00'te vurulur)
  - Projektörler (söner)
  - Anten ve uydu çanağı
  - Havan çukuru, cephane sandıkları
  - Güney yamaçta "NE MUTLU TÜRKÜM DİYENE"
- **Üniformalar (`tools/doku_uretici/uniforms.py`):**
  - Tim: TSK dijital kamuflaj (haki/yeşil/kahve/koyu) ve haki-zeytin teçhizat, kask.
  - Teröristler: düz, yıpranmış kıyafet (4 renk), kasksız, AKM.

## Bilinmesi gerekenler
- Oyuncunun tüfeği SCAR modeli, ama oyunda "MPT-76" adıyla görünüyor. Bir MPT-76 modeli bulursan
  `weapons/data/scar17.tres` dosyasından değiştiririm.
- Seslendirme yok, şimdilik altyazı. Ses dosyaları `audio/voice/` altına satır anahtarıyla
  (`dlg_sn_b1_tr.ogg` gibi) konunca kendiliğinden çalar.
- Silah ve patlama sesleri kodla üretildi. Gerçek ses paketi önerilir.
- Karakterler, yer adları ve olaylar kurgusaldır.
