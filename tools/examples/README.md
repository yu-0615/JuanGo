# 內建例句產生器

在 Mac 上用 Apple 裝置端模型（FoundationModels）替 `JuanGo/words.json` 裡沒有例句的字產生例句，再合併回字典。
這樣 App 顯示例句時就不必當場產生（手機上每句要 1–7 秒）。

```bash
cd tools/examples
# WordMatch.swift 是 Examples.swift 裡 enum WordMatch 的副本（App 改了比對規則時記得同步）
swiftc -O -parse-as-library -o gen main.swift WordMatch.swift
# 三個平行程序，依程度順序；可中斷，重跑會接續
for i in 0 1 2; do ./gen ../../JuanGo/words.json out$i.jsonl "3,4,2,5,1,6,國中小,多益" $i 3 & done
python3 merge.py ../../JuanGo/words.json out*.jsonl
```

每句都會經過和 App 相同的檢查：句子真的用到這個字（WordMatch），翻譯清掉殘渣、長度合理；被安全機制擋下時改用純文字輸出再試。
