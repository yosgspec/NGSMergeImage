@python -x "%~f0" %* & pause & exit /b
# ---------------------------------------------------------
# ここからPythonコード
# ---------------------------------------------------------
import os
import sys
import subprocess

# --- Pillowの自動インストール ---
try:
    from PIL import Image
except ImportError:
    print("⚠️ 画像処理ライブラリ(Pillow)が見つかりません。自動インストールを開始します...")
    try:
        subprocess.check_call([sys.executable, "-m", "pip", "install", "pillow"])
        from PIL import Image
        print("✅ ライブラリのインストールが完了しました！\n")
    except Exception as e:
        print(f"❌ 自動インストールに失敗しました。手動で 'pip install pillow' を実行してください。")
        sys.exit(1)

# --- 設定エリア ---
JPG_QUALITY = 50     # 容量最優先のクオリティ設定（必要に応じて50～85で調整してください）

def process_image(img_path, output_dir):
    """単一の画像ファイルを変換して保存する関数"""
    f_name = os.path.basename(img_path)
    root_name = os.path.splitext(f_name)[0]
    out_path = os.path.join(output_dir, f"{root_name}.jpg")
    
    try:
        with Image.open(img_path) as img:
            # 透過PNG対策：ツール本体に合わせた濃紺背景（#000033）で裏打ち
            if img.mode in ("RGBA", "LA", "P"):
                background = Image.new("RGB", img.size, (0, 0, 51))
                background.paste(img, mask=img.split()[-1] if img.mode == "RGBA" else None)
                final_img = background
            else:
                final_img = img.convert("RGB")
            
            # サイズは変えず、データだけを最適化してJPG保存
            final_img.save(out_path, "JPEG", quality=JPG_QUALITY, optimize=True)
            print(f"  [変換完了] {f_name} ➔ {root_name}.jpg")
            return True
            
    except Exception as e:
        print(f"  [❌失敗] {f_name} の処理中にエラー: {e}")
        return False

def convert_target(target_path, absolute_output=False):
    """ファイルまたはフォルダを判定して適切に処理する"""
    valid_extensions = (".jpg", ".jpeg", ".png", ".webp", ".bmp")
    output_root = "$samples"
    if absolute_output:
        output_root = os.path.join(os.path.dirname(os.path.abspath(sys.argv[0])), output_root)

    if os.path.isdir(target_path):
        # --- フォルダがドロップされた場合 ($samples/フォルダ名/ に出力) ---
        folder_name = os.path.basename(os.path.normpath(target_path))
        output_dir = os.path.join(output_root, folder_name)
        
        files = [f for f in os.listdir(target_path) if f.lower().endswith(valid_extensions)]
        if not files:
            print(f"❓ フォルダ内に画像が見つかりませんでした: {target_path}")
            return

        os.makedirs(output_dir, exist_ok=True)
        print(f"\n📦 フォルダ処理開始: {folder_name} ➔ $samples/{folder_name}")
        
        for f_name in files:
            img_path = os.path.join(target_path, f_name)
            process_image(img_path, output_dir)
            
        print(f"✨ 完了しました！ 出力先: {output_dir}")
        
    elif os.path.isfile(target_path):
        # --- ファイルがドロップされた場合 ($samples/ 直下に直接出力) ---
        if not target_path.lower().endswith(valid_extensions):
            print(f"⚠️ スキップ: 対応していないファイル形式です: {target_path}")
            return
            
        output_dir = output_root
        os.makedirs(output_dir, exist_ok=True)
        
        print(f"\n📦 ファイル処理開始: {os.path.basename(target_path)} ➔ $samples/")
        process_image(target_path, output_dir)
        print(f"✨ 完了しました！ 出力先: {output_dir}")
        
    else:
        print(f"⚠️ スキップ: 無効なパスです: {target_path}")

def main():
    args = sys.argv[1:]
    absolute_output = any(arg in ("-a", "--absolute") for arg in args)
    targets = [arg for arg in args if arg not in ("-a", "--absolute")]
    if not targets:
        print("=" * 60)
        print(" 🛠️  配布サンプル用：等倍JPG一括変換＆軽量化ツール")
        print("=" * 60)
        print("\n【 使い方 】")
        print("  画像ファイル(複数可) または フォルダ を、このバッチにドラッグ＆ドロップしてください。")
        print("  画質を維持したまま、容量の軽い「.jpg」に一括変換します。")
        print("    ・フォルダをドロップ ➔ 「$samples/フォルダ名」内へ保存")
        print("    ・ファイルをドロップ   ➔ 「$samples」フォルダ直下へ保存")
        print("  出力先: 通常はカレントディレクトリ基準。-a / --absolute で min.bat の場所基準")
        print("\n" + "=" * 60)
        return

    for path in targets:
        convert_target(path, absolute_output)

if __name__ == "__main__":
    main()