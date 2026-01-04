from typing import Any, Dict, List

from fastapi import FastAPI, Form, Request
from fastapi.responses import HTMLResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates

try:
    from sudachipy import Dictionary, SplitMode

    SUDACHI_AVAILABLE = True
    # 初始化时不创建 tokenizer，改为按需创建
    available_dicts = {}
    missing_dicts = []  # 记录缺失的词典
    # 检查可用的词典
    for dict_type in ["small", "core", "full"]:
        try:
            Dictionary(dict_type=dict_type)
            available_dicts[dict_type] = True
        except (ValueError, KeyError, ImportError) as e:  # Specify expected exceptions
            available_dicts[dict_type] = False
            if dict_type in ["core", "full"]:
                missing_dicts.append(dict_type)
except ImportError:
    SUDACHI_AVAILABLE = False
    available_dicts = {}
    missing_dicts = []
    print("Warning: sudachipy not installed. Using mock data for development.")

import os

# 加载 .env 文件
try:
    from dotenv import load_dotenv

    load_dotenv()
except ImportError:
    print("Warning: dotenv not installed. Environment variables not loaded.")

# 检测是否为演示部署环境
# 默认为 True（演示模式），通过环境变量显式设置为 false/0 来禁用
IS_DEMO_DEPLOY = os.getenv("IS_DEMO_DEPLOY", "true").lower() not in ["false", "0", "no"]

app = FastAPI(title="Chamame", description="Sudachi形態素解析ツール")

# 静的ファイルとテンプレートの設定
app.mount(
    "/static",
    StaticFiles(directory=os.path.join(os.path.dirname(__file__), "static")),
    name="static",
)

templates = Jinja2Templates(
    directory=os.path.join(os.path.dirname(__file__), "templates")
)


def get_split_mode(mode_str: str) -> "SplitMode":
    """文字列から SplitMode を取得"""
    mode_map = {
        "A": SplitMode.A,
        "B": SplitMode.B,
        "C": SplitMode.C,
    }
    return mode_map.get(mode_str.upper(), SplitMode.C)


def analyze_text_with_sudachi(
    text: str, split_mode: str = "A", dict_type: str = "small"
) -> List[Dict[str, Any]]:
    """Sudachiを使ってテキストを解析する"""
    if not SUDACHI_AVAILABLE:
        # Sudachiが利用できない場合のモックデータ
        # FIXME 前端提示报错
        return create_mock_analysis(text)

    # 指定された辞書が利用できない場合はフォールバック
    if not available_dicts.get(dict_type, False):
        print(f"Warning: {dict_type} dictionary not available, falling back to small")
        dict_type = "small"

    try:
        # 動的に tokenizer を作成
        tokenizer = Dictionary(dict_type=dict_type).create()
        mode = get_split_mode(split_mode)

        # Sudachiで解析
        tokens = tokenizer.tokenize(text, mode)
        results = []

        for token in tokens:
            # 形態素情報を抽出
            pos = token.part_of_speech()
            features = {
                "surface": token.surface(),  # 表層形
                "dictionary_form": token.dictionary_form(),  # 辞書形
                "reading_form": token.reading_form(),  # 読み
                "pos": pos[0] if len(pos) > 0 else "",  # 品詞大分類
                "pos_detail1": pos[1] if len(pos) > 1 else "",  # 品詞中分類
                "pos_detail2": pos[2] if len(pos) > 2 else "",  # 品詞小分類
                "pos_detail3": pos[3] if len(pos) > 3 else "",  # 品詞細分類
                "conjugation_type": pos[4] if len(pos) > 4 else "",  # 活用型
                "conjugation_form": pos[5] if len(pos) > 5 else "",  # 活用形
                "normalized_form": token.normalized_form(),  # 正規化形
                "word_id": token.word_id(),  # 語彙ID
                "synonym_group_ids": token.synonym_group_ids(),  # 同義語グループID
            }
            results.append(features)

        return results
    except Exception as e:
        print(f"Sudachi analysis error: {e}")
        return create_mock_analysis(text)


def create_mock_analysis(text: str) -> List[Dict[str, Any]]:
    """開発用のモックデータを生成"""
    # 簡単な文字分割でモックデータを作成
    mock_results = []
    words = text.replace("。", "").replace("、", "").split()

    if not words:
        # 文字ベースで分割
        for i, char in enumerate(text):
            if char.strip():
                mock_results.append(
                    {
                        "surface": char,
                        "dictionary_form": char,
                        "reading_form": char,
                        "pos": "記号" if not char.isalnum() else "名詞",
                        "pos_detail1": "一般",
                        "pos_detail2": "*",
                        "pos_detail3": "*",
                        "conjugation_type": "*",
                        "conjugation_form": "*",
                        "normalized_form": char,
                        "word_id": i,
                        "synonym_group_ids": [],
                    }
                )
    else:
        for i, word in enumerate(words):
            mock_results.append(
                {
                    "surface": word,
                    "dictionary_form": word,
                    "reading_form": word,
                    "pos": "名詞",
                    "pos_detail1": "一般",
                    "pos_detail2": "*",
                    "pos_detail3": "*",
                    "conjugation_type": "*",
                    "conjugation_form": "*",
                    "normalized_form": word,
                    "word_id": i,
                    "synonym_group_ids": [],
                }
            )

    return mock_results


@app.get("/", response_class=HTMLResponse)
def index(request: Request):
    """メインページを表示"""
    return templates.TemplateResponse(
        "index.html",
        {
            "request": request,
            "available_dicts": available_dicts,
            "is_demo_deploy": IS_DEMO_DEPLOY,
            "missing_dicts": missing_dicts,
        },
    )


@app.post("/analyze")
async def analyze_text(
    request: Request,
    text: str = Form(...),
    columns: List[str] = Form(default=[]),
    split_mode: str = Form(default="C"),
    dict_type: str = Form(default="small"),
):
    """テキスト解析のエンドポイント"""
    if not text or not text.strip():
        return templates.TemplateResponse(
            "partials/analysis_error.html",
            {"request": request, "error": "テキストを入力してください"},
        )

    try:
        # テキスト解析を実行（split_mode と dict_type を渡す）
        analysis_results = analyze_text_with_sudachi(
            text.strip(), split_mode=split_mode, dict_type=dict_type
        )

        # デフォルトの列設定（何も選択されていない場合）
        if not columns:
            columns = [
                "number",
                "surface",
                "dictionary_form",
                "reading_form",
                "pos",
                "pos_detail1",
                "pos_detail2",
                "conjugation_type",
                "conjugation_form",
                "normalized_form",
            ]

        return templates.TemplateResponse(
            "partials/analysis_result.html",
            {
                "request": request,
                "original_text": text.strip(),
                "results": analysis_results,
                "total_morphemes": len(analysis_results),
                "sudachi_available": SUDACHI_AVAILABLE,
                "selected_columns": columns,
                "split_mode": split_mode,
                "dict_type": dict_type,
            },
        )
    except Exception as e:
        return templates.TemplateResponse(
            "partials/analysis_error.html",
            {"request": request, "error": f"解析中にエラーが発生しました: {str(e)}"},
        )


@app.get("/health")
def health_check():
    """ヘルスチェック用エンドポイント"""
    return {
        "status": "healthy",
        "sudachi_available": SUDACHI_AVAILABLE,
        "available_dicts": available_dicts,
        "missing_dicts": missing_dicts,
        "is_demo_deploy": IS_DEMO_DEPLOY,
        "version": "1.0.0",
    }


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=8000, reload=True)
