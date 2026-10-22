@python -x "%~f0" %* & pause & exit /b
# ---------------------------------------------------------
# ここからPythonコード
# ---------------------------------------------------------
import os
import sys
import subprocess
from pathlib import Path

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
# chara の左削りを 586 に調整し、最下段(4行目)の合計幅を1行目・2行目(1647px)と完全に一致させる
TRIM_PATTERNS = {
    "chara":   (586, 0, 600, 0, 648, "キャラクター画像"),
    "status":  (499, 97, 748, 335, None, "キャラクター情報"),
    "pallet":  (274, 99, 1102, 374, None, "武器パレット"),
    "item":    (1366, 138, 5, 461, None, "装備アイテム"),
    "new_item":(1366, 138, 5, 461, None, "新規追加装備"),
}

# 配置レシピ（入力ファイルの順番に対応：計9枚）
RECIPE = [
    [("chara", "A4", "キャラクター画像")],    # 1枚目 ➔ A4
    [("status", "B4", "キャラクター情報")],   # 2枚目 ➔ B4
    [                                         # 3枚目（2箇所切り出し）
        ("item", "A1", "武器"),               # ➔ A1
        ("pallet", "C4", "武器パレット")       # ➔ C4
    ],
    [("item", "A2", "防具1")],                # 4枚目 ➔ A2
    [("item", "B2", "防具2")],                # 5枚目 ➔ B2
    [("item", "C2", "防具3")],                # 6枚目 ➔ C2
    [("item", "B1", "スキルリングT1")],       # 7枚目 ➔ B1
    [("item", "C1", "スキルリングT2")],       # 8枚目 ➔ C1
    [("new_item", "A3", "新規追加装備")],     # 9枚目 ➔ A3
]

def get_w(tiles, pos): return tiles[pos].width if pos in tiles else 0
def get_h(tiles, pos): return tiles[pos].height if pos in tiles else 0

# ---------------------------------------------------------
def show_help():
    """ヘルプメッセージ（仕様・使い方）を表示する"""
    print("=" * 75)
    print(" 🛠️  PSO2NGS ステータス画像結合ツール (4行対応版) 仕様＆ヘルプ")
    print("=" * 75)
    print("\n【 使い方 】")
    print("  1. 処理したい画像（9枚）が入ったフォルダを用意します。")
    print("  2. そのフォルダ（複数選択も可）をこのバッチファイルにドラッグ＆ドロップします。")
    print("\n【 仕様（配置レイアウト 3列×4行）】")
    print("  +----------------------+----------------------+----------------------+ ")
    print("  | A1: 武器             | B1: スキルリングT1   | C1: スキルリングT2   | ")
    print("  +----------------------+----------------------+----------------------+ ")
    print("  | A2: 防具1            | B2: 防具2            | C2: 防具3            | ")
    print("  +----------------------+----------------------+----------------------+ ")
    print("  | A3: 新規追加装備     | B3: (空き)           | C3: (空き)           | ")
    print("  +----------------------+----------------------+----------------------+ ")
    print("  | A4: キャラクター画像 | B4: キャラクター情報 | C4: 武器パレット     | ")
    print("  +----------------------+----------------------+----------------------+ ")
    print("=" * 75)


def process_folder(input_dir, output_root):
    """フォルダ1つ分を処理する関数"""
    input_path = Path(input_dir).resolve()
    if not input_path.is_dir():
        print(f"⚠️ スキップ: 対象はフォルダではありません: {input_dir}")
        return False

    folder_name = input_path.name

    valid_extensions = (".jpg", ".jpeg", ".png", ".webp")
    image_files = [f for f in os.listdir(input_path) if f.lower().endswith(valid_extensions)]
    image_files.sort()

    if len(image_files) < len(RECIPE):
        print(f"❌ エラー: 入力画像が足りません({input_dir})。最低 {len(RECIPE)} 枚必要です。")
        return False

    first_file_ext = os.path.splitext(image_files[0])[1].lower()
    tiles = {}

    print(f"\n--- [1] 画像切り出しフェーズ ({folder_name}) ---")
    for idx, actions in enumerate(RECIPE):
        f_name = image_files[idx]
        img_path = input_path / f_name

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

    # 行ごとの最大高さを計算してY方向の詰めを保持
    row_heights = {
        "1": max(get_h(tiles, "A1"), get_h(tiles, "B1"), get_h(tiles, "C1")),
        "2": max(get_h(tiles, "A2"), get_h(tiles, "B2"), get_h(tiles, "C2")),
        "3": max(get_h(tiles, "A3"), get_h(tiles, "B3"), get_h(tiles, "C3")),
        "4": max(get_h(tiles, "A4"), get_h(tiles, "B4"), get_h(tiles, "C4")),
    }

    # 各行ごとのX座標計算（左隣の画像と密着するように詰める）
    x_coords = {
        "A1": 0, "B1": get_w(tiles, "A1"), "C1": get_w(tiles, "A1") + get_w(tiles, "B1"),
        "A2": 0, "B2": get_w(tiles, "A2"), "C2": get_w(tiles, "A2") + get_w(tiles, "B2"),
        "A3": 0, "B3": get_w(tiles, "A3"), "C3": get_w(tiles, "A3") + get_w(tiles, "B3"),
        "A4": 0, "B4": get_w(tiles, "A4"), "C4": get_w(tiles, "A4") + get_w(tiles, "B4"),
    }

    # 各行のY座標（行の高さで固定）
    y_coords = {
        "A1": 0, "B1": 0, "C1": 0,
        "A2": row_heights["1"], "B2": row_heights["1"], "C2": row_heights["1"],
        "A3": row_heights["1"] + row_heights["2"], "B3": row_heights["1"] + row_heights["2"], "C3": row_heights["1"] + row_heights["2"],
        "A4": row_heights["1"] + row_heights["2"] + row_heights["3"], "B4": row_heights["1"] + row_heights["2"] + row_heights["3"], "C4": row_heights["1"] + row_heights["2"] + row_heights["3"],
    }

    # 各行の幅からキャンバス全体の最大幅を取得
    row_widths = [
        x_coords["C1"] + get_w(tiles, "C1"),
        x_coords["C2"] + get_w(tiles, "C2"),
        x_coords["C3"] + get_w(tiles, "C3"),
        x_coords["C4"] + get_w(tiles, "C4"),
    ]
    canvas_w = max(row_widths)
    canvas_h = row_heights["1"] + row_heights["2"] + row_heights["3"] + row_heights["4"]
    
    mode = "RGBA" if first_file_ext == ".png" else "RGB"
    canvas = Image.new(mode, (canvas_w, canvas_h), BG_COLOR)

    print(f"--- [2] 配置フェーズ ({folder_name}) ---")
    all_positions = ["A1", "B1", "C1", "A2", "B2", "C2", "A3", "B3", "C3", "A4", "B4", "C4"]
    for pos in all_positions:
        if pos in tiles:
            tile = tiles[pos]
            x = x_coords[pos]
            y = y_coords[pos]
            print(f"  【配置確定】 マス {pos} -> 座標(X: {x:>4}, Y: {y:>4}) , サイズ({tile.width:>4} x {tile.height:>4})")
            
            if mode == "RGBA" and tile.mode in ("RGBA", "LA"):
                canvas.paste(tile, (x, y), tile)
            else:
                canvas.paste(tile, (x, y))

    # 安全なパス指定に変換
    output_file = str((output_root / f"{folder_name}{first_file_ext}").resolve())
    
    try:
        if first_file_ext in (".jpg", ".jpeg"):
            canvas.save(output_file, quality=95)
        else:
            canvas.save(output_file)
        print(f"✨ 完了: {output_file} (形式: {first_file_ext.upper()} | サイズ: {canvas_w}x{canvas_h})")
        return True
    except Exception as e:
        print(f"❌ 保存失敗: {output_file}\n詳細エラー: {e}")
        return False


def main():
    args = sys.argv[1:]
    absolute_output = any(arg in ("-a", "--absolute") for arg in args)
    targets = [arg for arg in args if arg not in ("-a", "--absolute")]
    output_root = Path("$samples")
    if absolute_output:
        output_root = Path(sys.argv[0]).resolve().parent / output_root
    
    if not targets or any(arg in targets for arg in ["-h", "-?", "--help"]):
        show_help()
        print("  出力先: 通常はカレントディレクトリ基準の $samples。-a / --absolute で ngs_merge_img.bat の場所基準")
        return

    total = len(targets)
    print(f"🚀 計 {total} 個の対象がドロップされました。一括処理を開始します。")
    print("=" * 60)

    success_count = 0
    for idx, path in enumerate(targets, 1):
        print(f"\n🔄 [{idx}/{total}] 処理中: {path}")
        if process_folder(path, output_root):
            success_count += 1
        print("-" * 60)

    print(f"\n🎉 すべての一括処理が終了しました！ (成功: {success_count}/{total})")

if __name__ == "__main__":
    main()