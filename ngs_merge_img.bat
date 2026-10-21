@python -x "%~f0" %* & pause & exit /b
# ---------------------------------------------------------
# ここからPythonコード
# ---------------------------------------------------------
import os
import sys
import subprocess

# --- 必須ライブラリの自動インストール処理 ---
try:
    from PIL import Image
except ImportError:
    print("⚠️ 画像処理ライブラリ(Pillow)が見つかりません。自動インストールを開始します...")
    try:
        subprocess.check_call([sys.executable, "-m", "pip", "install", "pillow"])
        from PIL import Image
        print("✅ ライブラリのインストールが完了しました！処理を続行します。\n")
    except Exception as e:
        print(f"❌ 自動インストールに失敗しました。手動で 'pip install pillow' を実行してください。")
        print(f"エラー詳細: {e}")
        sys.exit(1)

# --- 定数・設定エリア ---

# 背景色をカラーコードで指定
BG_COLOR = "#000033"

# パターン定義: (左削り, 上削り, 右削り, 下削り, 目標高さ[Noneならリサイズなし], 日本語定義名)
TRIM_PATTERNS = {
    "chara":  (700, 0, 600, 0, 648, "キャラクター画像"),
    "status": (499, 97, 748, 335, None, "キャラクター情報"),
    "pallet": (274, 99, 1102, 374, None, "武器パレット"),
    "item":   (1366, 138, 5, 461, None, "装備アイテム"),
}

# 配置レシピ（入力ファイルの順番に対応）
RECIPE = [
    [("chara", "A3", "キャラクター画像")],   # 1枚目
    [("status", "B3", "キャラクター情報")],  # 2枚目
    [                                        # 3枚目（2回使用）
        ("item", "A1", "武器"),
        ("pallet", "C3", "武器パレット")
    ],
    [("item", "A2", "防具1")],               # 4枚目
    [("item", "B2", "防具2")],               # 5枚目
    [("item", "C2", "防具3")],               # 6枚目
    [("item", "B1", "スキルリングT1")],      # 7枚目
    [("item", "C1", "スキルリングT2")],      # 8枚目
]

# 各位置の画像の幅と高さを取得するヘルパー
def get_w(tiles, pos): return tiles[pos].width if pos in tiles else 0
def get_h(tiles, pos): return tiles[pos].height if pos in tiles else 0

# ---------------------------------------------------------
def show_help():
    """ヘルプメッセージ（仕様・使い方）を表示する"""
    print("=" * 75)
    print(" 🛠️  PSO2NGS ステータス画像結合ツール (ngs_merge_img.bat) 仕様＆ヘルプ")
    print("=" * 75)
    print("\n【 使い方 】")
    print("  1. 処理したい画像（8枚）が入ったフォルダを用意します。")
    print("  2. そのフォルダ（複数選択も可）をこのバッチファイルにドラッグ＆ドロップします。")
    print("\n【 仕様（配置レイアウトと画像定義）】")
    print("  各マスが左隣・上隣の画像と隙間なく密着結合します。")
    print("  +----------------------+----------------------+----------------------+")
    print("  | A1: 武器             | B1: スキルリングT1   | C1: スキルリングT2   |")
    print("  +----------------------+----------------------+----------------------+")
    print("  | A2: 防具1            | B2: 防具2            | C2: 防具3            |")
    print("  +----------------------+----------------------+----------------------+")
    print("  | A3: キャラクター画像 | B3: キャラクター情報 | C3: 武器パレット     |")
    print("  +----------------------+----------------------+----------------------+")
    print("\n【 各パーツの切り出し設定（定数化）】")
    print(f"  ● キャンバス背景色: {BG_COLOR}")
    print("  ● トリミング範囲 (左削り, 上削り, 右削り, 下削り -> 固定リサイズ高)")
    for key, val in TRIM_PATTERNS.items():
        h_str = f"{val[4]}pxにリサイズ" if val[4] is not None else "リサイズなし"
        print(f"    - {val[5]:<10} ({key}): 削り(左:{val[0]:>4}, 上:{val[1]:>4}, 右:{val[2]:>4}, 下:{val[3]:>4}) -> {h_str}")
    print("\n【 ファイルの割り当て規則（ドロップ時の入力画像順）】")
    print("  入力1枚目 ➔ A3: キャラクター画像")
    print("  入力2枚目 ➔ B3: キャラクター情報")
    print("  入力3枚目 ➔ A1: 武器 ＆ C3: 武器パレット (1枚から2箇所を同時切り出し)")
    print("  入力4枚目 ➔ A2: 防具1")
    print("  入力5枚目 ➔ B2: 防具2")
    print("  入力6枚目 ➔ C2: 防具3")
    print("  入力7枚目 ➔ B1: スキルリングT1")
    print("  入力8枚目 ➔ C1: スキルリングT2")
    print("=" * 75)


def process_folder(input_dir):
    """フォルダ1つ分を処理する関数"""
    if not os.path.isdir(input_dir):
        print(f"⚠️ スキップ: 対象はフォルダではありません: {input_dir}")
        return False

    base_dir = os.path.dirname(input_dir)
    folder_name = os.path.basename(os.path.normpath(input_dir))

    valid_extensions = (".jpg", ".jpeg", ".png", ".webp")
    image_files = [f for f in os.listdir(input_dir) if f.lower().endswith(valid_extensions)]
    image_files.sort()

    if len(image_files) < len(RECIPE):
        print(f"❌ エラー: 入力画像が足りません({input_dir})。最低 {len(RECIPE)} 枚必要です。")
        return False

    # 1枚目の画像の拡張子を採用
    first_file_ext = os.path.splitext(image_files[0])[1].lower()
    tiles = {}

    print(f"\n--- [1] 画像切り出しフェーズ ({folder_name}) ---")
    for idx, actions in enumerate(RECIPE):
        f_name = image_files[idx]
        img_path = os.path.join(input_dir, f_name)

        if not actions:
            continue

        with Image.open(img_path) as img:
            orig_w, orig_h = img.size
            for p_name, pos, label in actions:
                cut_l, cut_t, cut_r, cut_b, target_h = TRIM_PATTERNS[p_name][:5]

                left = cut_l
                top = cut_t
                right = orig_w - cut_r
                bottom = orig_h - cut_b

                cropped = img.crop((left, top, right, bottom))
                
                if target_h is not None:
                    target_w = int(cropped.width * (target_h / cropped.height))
                    processed_tile = cropped.resize((target_w, target_h), Image.Resampling.LANCZOS)
                else:
                    processed_tile = cropped.copy()

                tiles[pos] = processed_tile
                print(f"  【加工】 {f_name} -> {pos} に準備 ({label}: {processed_tile.width}x{processed_tile.height})")

    # 各マスごとの独立座標を計算 (A->B->C)
    x_coords = {
        "A1": 0, "B1": get_w(tiles, "A1"), "C1": get_w(tiles, "A1") + get_w(tiles, "B1"),
        "A2": 0, "B2": get_w(tiles, "A2"), "C2": get_w(tiles, "A2") + get_w(tiles, "B2"),
        "A3": 0, "B3": get_w(tiles, "A3"), "C3": get_w(tiles, "A3") + get_w(tiles, "B3")
    }

    # 各マスごとの独立座標を計算 (1->2->3)
    y_coords = {
        "A1": 0,                        "B1": 0,                        "C1": 0,
        "A2": get_h(tiles, "A1"),       "B2": get_h(tiles, "B1"),       "C2": get_h(tiles, "C1"),
        "A3": get_h(tiles, "A1")+get_h(tiles, "A2"), "B3": get_h(tiles, "B1")+get_h(tiles, "B2"), "C3": get_h(tiles, "C1")+get_h(tiles, "C2")
    }

    canvas_w = max(x_coords["C1"] + get_w(tiles, "C1"), x_coords["C2"] + get_w(tiles, "C2"), x_coords["C3"] + get_w(tiles, "C3"))
    canvas_h = max(y_coords["A3"] + get_h(tiles, "A3"), y_coords["B3"] + get_h(tiles, "B3"), y_coords["C3"] + get_h(tiles, "C3"))
    
    mode = "RGBA" if first_file_ext == ".png" else "RGB"
    canvas = Image.new(mode, (canvas_w, canvas_h), BG_COLOR)

    print(f"--- [2] 配置フェーズ ({folder_name}) ---")
    for pos in ["A1", "B1", "C1", "A2", "B2", "C2", "A3", "B3", "C3"]:
        if pos in tiles:
            tile = tiles[pos]
            x = x_coords[pos]
            y = y_coords[pos]
            print(f"  【配置確定】 マス {pos} -> 座標(X: {x:>4}, Y: {y:>4}) , サイズ({tile.width:>4} x {tile.height:>4})")
            
            if mode == "RGBA" and tile.mode in ("RGBA", "LA"):
                canvas.paste(tile, (x, y), tile)
            else:
                canvas.paste(tile, (x, y))

    output_file = os.path.join(base_dir, f"{folder_name}{first_file_ext}")
    
    if first_file_ext in (".jpg", ".jpeg"):
        canvas.save(output_file, quality=95)
    else:
        canvas.save(output_file)
        
    print(f"✨ 完了: {output_file} (形式: {first_file_ext.upper()} | サイズ: {canvas_w}x{canvas_h})")
    return True


def main():
    targets = sys.argv[1:]
    
    if not targets or any(arg in targets for arg in ["-h", "-?", "--help"]):
        show_help()
        return

    total = len(targets)
    print(f"🚀 計 {total} 個の対象がドロップされました。一括処理を開始します。")
    print("=" * 60)

    success_count = 0
    for idx, path in enumerate(targets, 1):
        print(f"\n🔄 [{idx}/{total}] 処理中: {path}")
        if process_folder(path):
            success_count += 1
        print("-" * 60)

    print(f"\n🎉 すべての一括処理が終了しました！ (成功: {success_count}/{total})")

if __name__ == "__main__":
    main()
