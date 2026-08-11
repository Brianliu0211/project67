import urllib.request
import json
import sys

def trigger_cloud_edge_function():
    sys.stdout.reconfigure(encoding='utf-8')
    print("==========================================")
    print(" 🚀 正在手動觸動 Supabase 雲端 Edge Function 自動化爬蟲端點...")
    print("==========================================")

    url = "https://algufuoxkeizxwkofmmp.supabase.co/functions/v1/crawl-insurance-products"
    headers = {
        "Content-Type": "application/json",
        "Authorization": "Bearer sb_publishable_hEIRyFKMgmbB2qVOVioGBQ_61oJxceL"
    }

    req = urllib.request.Request(
        url,
        data=json.dumps({"trigger": "manual_execution_test"}).encode("utf-8"),
        headers=headers,
        method="POST"
    )

    try:
        with urllib.request.urlopen(req) as response:
            status = response.status
            body = response.read().decode("utf-8")
            print(f"  ✅ [雲端 Edge Function 觸動成功！] -> HTTP 狀態碼: {status}")
            print(f"  📩 [雲端傳回結果]: {body}")
    except Exception as e:
        print(f"  ℹ️ [Edge Function 手動觸動呼叫]: {e}")
        print("  💡 提示: 若 Edge Function 尚未發布至 Supabase 雲端，可以執行 `npx supabase functions deploy crawl-insurance-products`！")

    print("==========================================")

if __name__ == "__main__":
    trigger_cloud_edge_function()
