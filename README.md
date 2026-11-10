# JuanGo

JuanGo 是一個用 SwiftUI 寫的英文單字複習 App（iOS 26），用間隔複習幫你把單字從「初見」練到「精通」。單字範圍從國小、國中、大考一路到多益、雅思、托福。

## 功能

- **今天**：每日目標進度環、待複習數、連續天數，一鍵開始今日學習
- **探索**：左右滑的單字卡，點兩下收進「我的單字」；裝置端 Apple Intelligence 自動產生例句
- **新增**：輸入英文或中文查字；拍照掃描課本（依句子判斷詞性；拍單字統整頁會直接帶入頁面上的詞性和中文）；從相簿或檔案（txt／csv）匯入
- **字庫**：我的單字、清單，以及內建字庫：
  - 大考詞彙：基礎 2000、進階 4000、學測 6000+（大考中心 6 級）
  - 國中小 1200：教育部國中小基本字彙
  - 多益 TOEIC、雅思 IELTS、托福 TOEFL
- **練習**：翻卡片、英翻中、中翻英、克漏字、聽力、拼單字；自動安排或手動挑選題型、無盡模式
- **我的**：連續天數、學習日曆、熟練階梯、成就勳章
- 7 組主題色，頁面底色與區塊跟著主題色調變化，支援深色模式

## 設計

- 介面以原生 SwiftUI 元件為主（List、`.searchable`、Liquid Glass 按鈕），規則寫在 `DESIGN.md`
- 圖示全部使用 [PulsoIcon](https://github.com/CityPulso/PulsoIcon)（會動的圖示）
- `Packages/PulsoIcon` 是只含用到的 74 個圖示的精簡版（編譯從十幾分鐘變成十幾秒）；要加圖示時，先在 `Lexi/Icons.swift` 加對應，再執行 `scripts/trim.py`

## 安裝

- **自己編譯**：用 Xcode 26 打開 `Lexi.xcodeproj`，在 Signing & Capabilities 換成自己的 Team，執行到 iPhone 或模擬器。
- **自己簽名安裝 IPA**：下載 Releases 裡的 IPA，用 [Sideloadly](https://sideloadly.io) 或 [AltStore](https://altstore.io) 以自己的 Apple ID 簽名安裝。iPhone 要打開「設定 › 隱私權與安全性 › 開發者模式」，並在「設定 › 一般 › VPN 與裝置管理」信任自己的 Apple ID。免費 Apple ID 簽的 App 每 7 天要重簽一次（資料不會消失）。

需求：iOS 26、Xcode 26。

## 資料來源與授權

- 大考詞彙與分級：大學入學考試中心《高中英文參考詞彙表》（111 學年度起適用），僅供非營利學習使用。
- 國中小 1200：教育部《十二年國民基本教育課程綱要 語文領域－英語文》附錄五表一「基本 1,200 字」。
- 多益：[TOEIC Service List 1.2](https://newgeneralservicelist.com/toeic-service-list)（Browne, C. & Culligan, B.），[CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/)；`words.json` 中由它而來的 `toeic` 標記同樣以 CC BY-SA 4.0 釋出。
- 雅思、托福字表，以及中文解釋與音標：整理自 [ECDICT](https://github.com/skywind3000/ECDICT)（MIT License），並轉為繁體中文（台灣用語），內容可能有誤。
- 圖示：[PulsoIcon](https://github.com/CityPulso/PulsoIcon)，授權見該專案的 LICENSE。
- 所有學習資料只存在自己的裝置上，不會上傳。

這是一個高中自主學習專案。
