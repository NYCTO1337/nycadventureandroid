# iOS-ზე გადატანის გეგმა

> **სტატუსი: iOS ვერსია მზად არ არის.** ის არ არის ექსპორტირებული და არ არის გატესტილი. ქვემოთ არის მხოლოდ გეგმა.

## რაც უკვე გაკეთებულია (არქიტექტურა)

| საკითხი | სად არის |
|---|---|
| პლატფორმული ფუნქციები (ვიბრაცია, safe area, input map) | `platform_service.gd` |
| მართვა | `touch_controls.gd` — მხოლოდ Input Action-ებს იყენებს, `InputEventScreenTouch/Drag` ორივე პლატფორმაზე ერთნაირია |
| შენახვა | `save_system.gd` — `user://` ორივე პლატფორმაზე მუშაობს |
| აუდიო | `audio_manager.gd` — ფაილებისგან დამოუკიდებელი |
| აპის მდგომარეობა | `game_state.gd` — `NOTIFICATION_APPLICATION_PAUSED/FOCUS_OUT` |
| რენდერერი | GL Compatibility (iOS-ზე Godot 4 მხარს უჭერს) |

## საჭირო ნაბიჯები

1. **macOS + Xcode** (iOS ექსპორტი სხვა სისტემაზე შეუძლებელია) და **Apple Developer** ანგარიში (ტესტირებისთვის უფასო Apple ID საკმარისია, App Store-სთვის — ფასიანი).
2. Godot-ში iOS ექსპორტის შაბლონების ჩამოტვირთვა, `export_presets.cfg`-ში iOS პრესეტის დამატება: Bundle Identifier, Team ID, ვერსია.
3. აპის ხატულები (iOS-ს სჭირდება ხატულების ნაკრები) და Launch Screen.
4. ექსპორტი Xcode პროექტად → Xcode-ში signing → გაშვება **რეალურ iPhone-ზე**.
5. ტესტი: შეხება, multi-touch, safe area (notch / Dynamic Island / home indicator), ფონური რეჟიმი, ხმა.
6. App Store: Privacy Manifest, ასაკობრივი რეიტინგი, სკრინშოტები.

## შესაძლო შეზღუდვები / გასარკვევი

- `NOTIFICATION_WM_GO_BACK_REQUEST` iOS-ზე არ არსებობს — პაუზა მხოლოდ HUD-ის ღილაკით. (კოდი ამისგან უვნებელია.)
- `Input.vibrate_handheld(ms)` iOS-ზე მხარდაჭერილია, მაგრამ ხანგრძლივობის კონტროლი შეზღუდულია — გადაამოწმე რეალურ მოწყობილობაზე.
- Safe area გამოთვლა (`get_safe_insets`) ჯერ მხოლოდ ლოგიკურად არის დაწერილი; iOS-ზე და Android-ის სხვადასხვა ჭრილიან ეკრანზე რეალური ტესტი სჭირდება.
- სისტემური ფონტის fallback ქართულისთვის iOS-ზე უნდა გადამოწმდეს; უსაფრთხოა Noto Sans Georgian-ის ჩაშენება.
- გარე SDK-ები (რეკლამა, ანალიტიკა) საჭიროებს iOS-ის ცალკე პლაგინს.
