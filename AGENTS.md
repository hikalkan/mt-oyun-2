# Çocuk oyunu

Bu depoyu 10 yaşındaki bir çocuk yönetir. Yazılım ve teknik bilgisi yoktur. Oyunu Türkçe, kendi kelimeleriyle anlatır. Kodlama, sahne, asset ve hata işini sen yaparsın. Ebeveyn yalnızca takıldığında müdahale eder.

## Konuşma

- Çocukla kısa, sade Türkçe konuş. Dosya yolu, sınıf adı, hata dökümü anlatma.
- Sonucu söyle: ne olduğunu, nasıl oynanacağını (hangi tuş, neye tıklanır).
- Anladığın kadarıyla hemen oyunu yap. Eksik ayrıntıyı kendin seç ve tek cümleyle söyle.
- Takılmazsan soru sorma. Takılırsan en fazla bir soru sor.
- Ebeveyn teknik bir şey isterse (kurulum, dışa aktarma, çökme) normal teknik dille cevap ver.

## Motor

- Godot 4.7, yalnızca GDScript. C# ve eklenti yok.
- Varsayılan 2D. Çocuk açıkça 3D isterse o zaman 3D yap.
- Ana sahne `res://scenes/main.tscn`. Pencere 1280x720, `canvas_items` + `expand`.
- Klasörler: `scenes/`, `scripts/`, `assets/sprites/`, `assets/audio/`.
- Hareket için Godot’un hazır aksiyonları: ok tuşları ve WASD (`ui_left`, `ui_right`, `ui_up`, `ui_down`), zıplama ve seçim için Space / Enter (`ui_accept`).
- Piksel oyun istenirse doku filtresini nearest yap ve gerekirse esnetme kipini viewport’a çevir.
- Her değişiklikten sonra oyun çalışır kalsın. Karşılama yazısını, istenen oyunun ilk oynanabilir haliyle değiştir.

## Ücret yok

Ücretli motor, eklenti, asset, font, ses veya mağaza paketi kullanma.

Görsel veya ses gerekirse önce Godot içinden üret (ColorRect, Polygon2D, çizgi, SVG, kısa sentez ses). Dış dosya şartsa yalnızca ücretsiz ve ticari kullanıma açık kaynak kullan (tercihen CC0, örneğin Kenney). Lisans ve adresi `assets/CREDITS.md` içine yaz. Lisans belirsizse indirme, kendin çiz.

## Doğrulama

Oyunu çalıştırıp bak: sahne açılıyor mu, istenen hareket var mı. Editör kurulu: Godot 4.7.2 (`godot` komutu). Başsız kontrol için konsol sürümünü kullan.
