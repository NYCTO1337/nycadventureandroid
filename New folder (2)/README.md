# NYCTO'S ADVENTURE

2D პლატფორმერი, **Godot 4** ძრავზე. პირველი სამიზნე — **Android**, არქიტექტურა მზადაა **iOS**-ისთვის.

> სტატუსი: ეს არის **მუშა პროტოტიპის კოდი** (1 დონე, სრული მობილური მართვა, შენახვა, აუდიო, პაუზა).
> APK ამ გარემოში **არ აგებულა** და თამაში **არ გაშვებულა** — იხილე `docs/TEST_REPORT.md`.

## რას შეიცავს

- 1 სრული დონე: პლატფორმები, წვეტიანები, 3 მტერი (თავზე ახტომით ამარცხებ), 20 მონეტა, ბანიკები (ურთიერთქმედება), ჩექფოინთები, ფინიშის დროშა.
- სენსორული მართვა: მცურავი ჯოისტიკი მარცხნივ, ხტომა + ურთიერთქმედება მარჯვნივ, მულტი-შეხება, ხანგრძლივი დაჭერა, გამჭვირვალობა/ზომა/მგრძნობელობა/მხარეების შებრუნება პაუზის მენიუში.
- 2D განათება (`PointLight2D`), ნაწილაკები (`CPUParticles2D`), ანიმაციები (squash & stretch, მონეტების ბრუნვა).
- ავტომატური ხარისხის შემცირება სუსტ მოწყობილობებზე (`PerfGovernor`).
- უსაფრთხო შენახვა (დროებითი ფაილი + backup), პაუზა ფონურ რეჟიმში გადასვლისას, Android-ის "უკან" ჟესტი ხსნის პაუზას.
- ყველა ხმა და გრაფიკა კოდით იქმნება — გარე ფაილები არ არის.

## პროექტის სტრუქტურა

```
project.godot            პარამეტრები (GL Compatibility, landscape, stretch=expand)
export_presets.cfg       Android APK / AAB შაბლონები (გადასამოწმებელი)
scenes/main.tscn         ერთადერთი სცენა, ყველაფერს main.gd აგებს
scripts/autoload/
  save_system.gd         შენახვა (user://)
  game_state.gd          პარამეტრები, პროგრესი, პაუზა, აპის სასიცოცხლო ციკლი
  platform_service.gd    ერთადერთი ადგილი პლატფორმული ფუნქციებისთვის
  audio_manager.gd       სინთეზირებული მუსიკა და ეფექტები
  perf_governor.gd       FPS მონიტორინგი, ხარისხის დონეები
scripts/controls/touch_controls.gd   მართვის ცალკე სისტემა (მხოლოდ Input Action-ებს აგზავნის)
scripts/game/            player, enemy, level, hud, pause_menu, main
docs/                    ძრავის არჩევა, iOS გეგმა, ტესტები, ლიცენზიები
```

## გაშვება კომპიუტერზე (სწრაფი შემოწმება)

1. დააინსტალირე **Godot 4.3 ან უფრო ახალი** (სტანდარტული, არა .NET).
2. Godot → Import → აირჩიე `project.godot` → გახსნისას დაელოდე იმპორტს.
3. F5. მაუსი ცვლის შეხებას; კლავიატურა: A/D ან ისრები, Space/W — ხტომა, E — ურთიერთქმედება, Esc — პაუზა.

## გაშვება Android მოწყობილობაზე

1. ტელეფონზე ჩართე Developer options → **USB debugging**.
2. Godot-ში (Android-ის გარემო უკვე მორგებულია, იხ. ქვემოთ) მოწყობილობა გამოჩნდება ზედა მარჯვენა კუთხეში (Android ხატულა) → დააჭირე ▶ **Remote Debug**.

## APK-ის შექმნა

**ერთჯერადი მომზადება**

1. დააინსტალირე **JDK 17** და **Android SDK** (Android Studio-ს Command-line Tools-ით): `platform-tools`, `build-tools;34.0.0`, `platforms;android-34`, `cmdline-tools;latest`.
2. Godot → *Editor → Manage Export Templates* → ჩამოტვირთე შაბლონები (ზუსტად ისეთივე ვერსიის, როგორიც Godot-ია).
3. *Editor → Editor Settings → Export → Android*: მიუთითე **Android SDK Path** და **Java SDK Path**.
4. Debug keystore: Godot თვითონ ქმნის ან ხელით:
   `keytool -keyalg RSA -genkeypair -alias androiddebugkey -keypass android -keystore debug.keystore -storepass android -dname "CN=Android Debug,O=Android,C=US" -validity 9999 -deststoretype pkcs12`
   და მიუთითე Editor Settings-ში (Debug Keystore, User: `androiddebugkey`, Password: `android`).

**Debug APK (ტესტისთვის)**

- Godot: *Project → Export → Android APK → Export Project* (**Export With Debug** ჩართული) → `build/nyctos-adventure.apk`.
- ან ტერმინალიდან: `godot --headless --export-debug "Android APK" build/nyctos-adventure.apk`
- დაინსტალირება: `adb install -r build/nyctos-adventure.apk`

**Release APK / AAB (გამოსაშვებად)**

1. შექმენი საკუთარი keystore (და **შეინახე უსაფრთხოდ + backup**, დაკარგვის შემთხვევაში განახლებას ვეღარ გამოაქვეყნებ):
   `keytool -genkeypair -v -keystore nyctos-release.keystore -alias nyctos -keyalg RSA -keysize 2048 -validity 10000`
2. Export პრესეტში ჩაწერე Release keystore-ის გზა, alias და პაროლი (ან გარემოს ცვლადებით: `GODOT_ANDROID_KEYSTORE_RELEASE_PATH`, `..._USER`, `..._PASSWORD`).
3. **AAB-ისთვის**: *Project → Install Android Build Template*, პრესეტ "Android AAB"-ში ჩართე *Use Gradle Build* და *Export Format = Export AAB*. ამისთვის საჭიროა დამატებით Android NDK (Godot-ის დოკუმენტაცია მიუთითებს ზუსტ ვერსიას თქვენი Godot-ისთვის).
4. Export → `build/nyctos-adventure.aab` (Google Play-ში ატვირთვისთვის).

## ცნობილი შეზღუდვები

- ქართული ტექსტი იყენებს სისტემურ ფონტის fallback-ს. თუ რომელიმე მოწყობილობაზე ასოები არ ჩანს, ჩაამატე **Noto Sans Georgian** (OFL ლიცენზია) `assets/fonts/`-ში და Project Settings → GUI → Theme → Custom Font-ში მიუთითე.
- გრაფიკა მინიმალისტური, კოდით დახატული placeholder-ია; საბოლოო არტისთვის სპრაიტებზე გადასვლა საჭიროა.
- იხ. `docs/TEST_REPORT.md` — რა არ არის გატესტილი.

## დოკუმენტები

- `docs/ENGINE_CHOICE.md` — რატომ Godot
- `docs/IOS_PLAN.md` — iOS-ზე გადატანის გეგმა და შეზღუდვები
- `docs/TEST_REPORT.md` — ტესტირების შედეგები და რისკები
- `docs/LICENSES.md` — რესურსები და ლიცენზიები
