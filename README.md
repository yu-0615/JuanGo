# Lexi

Lexi 是一個用 SwiftUI 寫的英文單字複習 App（iOS 26），用間隔複習幫你把單字從「初見」練到「精通」。

## 功能

- **今天**：每日目標進度環、待複習數、連續天數，一鍵開始今日學習
- **探索**：左右滑的單字卡，點兩下收進「我的單字」；裝置端 Apple Intelligence 自動產生例句
- **新增**：輸入英文或中文查字、拍照掃描課本上的英文字、從相簿或檔案（txt／csv）匯入
- **字庫**：我的單字、清單、內建字庫（大考中心 6 級詞彙），單字詳情頁
- **練習**：翻卡片、英翻中、中翻英、克漏字、聽力、拼單字；自動安排或手動挑選題型、無盡模式
- **我的**：連續天數、學習日曆、熟練階梯、成就勳章
- 6 組主題色（鳳凰紅、琥珀、松針、墨藍、梅子、石墨），支援深色模式

## 設計

- 圖示全部使用 [PulsoIcon](https://github.com/CityPulso/PulsoIcon)（會動的圖示），版面以 SwiftUI Stack 組成
- 按鈕一律圓角矩形；主要按鈕使用 iOS 26 Liquid Glass
- 標題與單字使用襯線字，卡片用細邊框取代陰影

## 安裝

- **自己編譯**：用 Xcode 26 打開 `Lexi.xcodeproj`，在 Signing & Capabilities 換成自己的 Team，執行到 iPhone 或模擬器。
- **Releases 裡的 `Lexi.ipa`**：開發用簽章，只能安裝在作者已登記的裝置上；其他人請自己編譯。

需求：iOS 26、Xcode 26。

## 資料來源與授權

- 詞彙與分級：大學入學考試中心《高中英文參考詞彙表》（111 學年度起適用），僅供非營利學習使用。
- 中文解釋與音標：整理自 [ECDICT](https://github.com/skywind3000/ECDICT)（MIT License），並轉為繁體中文，內容可能有誤。
- 圖示：[PulsoIcon](https://github.com/CityPulso/PulsoIcon)，授權見該專案的 LICENSE。
- 所有學習資料只存在自己的裝置上，不會上傳。

這是一個高中自主學習專案。
