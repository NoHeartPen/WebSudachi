import os
import json
from typing import List, Dict, Any
from fastapi import FastAPI, Request, Form
from fastapi.responses import HTMLResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates


try:
    from sudachipy import Dictionary, SplitMode
    SUDACHI_AVAILABLE = True
    tokenizer = Dictionary().create()
except ImportError:
    SUDACHI_AVAILABLE = False
    tokenizer = None
    print("Warning: sudachipy not installed. Using mock data for development.")

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


def analyze_text_with_sudachi(text: str) -> List[Dict[str, Any]]:
    """Sudachiを使ってテキストを解析する"""
    if not SUDACHI_AVAILABLE or not tokenizer:
        # Sudachiが利用できない場合のモックデータ
        return create_mock_analysis(text)

    try:
        # Sudachiで解析
        tokens = tokenizer.tokenize(text, SplitMode.C)  # Mode Cを使用
        results = []

        for token in tokens:
            # 形態素情報を抽出
            pos = token.part_of_speech()
            features = {
                'surface': token.surface(),  # 表層形
                'dictionary_form': token.dictionary_form(),  # 辞書形
                'reading_form': token.reading_form(),  # 読み
                'pos': pos[0] if len(pos) > 0 else '',  # 品詞大分類
                'pos_detail1': pos[1] if len(pos) > 1 else '',  # 品詞中分類
                'pos_detail2': pos[2] if len(pos) > 2 else '',  # 品詞小分類
                'pos_detail3': pos[3] if len(pos) > 3 else '',  # 品詞細分類
                'conjugation_type': pos[4] if len(pos) > 4 else '',  # 活用型
                'conjugation_form': pos[5] if len(pos) > 5 else '',  # 活用形
                'normalized_form': token.normalized_form(),  # 正規化形
                'word_id': token.word_id(),  # 語彙ID
                'synonym_group_ids': token.synonym_group_ids()  # 同義語グループID
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
    words = text.replace('。', '').replace('、', '').split()

    if not words:
        # 文字ベースで分割
        for i, char in enumerate(text):
            if char.strip():
                mock_results.append({
                    'surface': char,
                    'dictionary_form': char,
                    'reading_form': char,
                    'pos': '記号' if not char.isalnum() else '名詞',
                    'pos_detail1': '一般',
                    'pos_detail2': '*',
                    'pos_detail3': '*',
                    'conjugation_type': '*',
                    'conjugation_form': '*',
                    'normalized_form': char,
                    'word_id': i,
                    'synonym_group_ids': []
                })
    else:
        for i, word in enumerate(words):
            mock_results.append({
                'surface': word,
                'dictionary_form': word,
                'reading_form': word,
                'pos': '名詞',
                'pos_detail1': '一般',
                'pos_detail2': '*',
                'pos_detail3': '*',
                'conjugation_type': '*',
                'conjugation_form': '*',
                'normalized_form': word,
                'word_id': i,
                'synonym_group_ids': []
            })

    return mock_results


@app.get("/", response_class=HTMLResponse)
def index(request: Request):
    """メインページを表示"""
    return templates.TemplateResponse(
        "index.html",
        {"request": request}
    )


@app.post("/analyze")
async def analyze_text(request: Request, text: str = Form(...)):
    """テキスト解析のエンドポイント"""
    if not text or not text.strip():
        return templates.TemplateResponse(
            "partials/analysis_error.html",
            {"request": request, "error": "テキストを入力してください"}
        )

    try:
        # テキスト解析を実行
        analysis_results = analyze_text_with_sudachi(text.strip())

        return templates.TemplateResponse(
            "partials/analysis_result.html",
            {
                "request": request,
                "original_text": text.strip(),
                "results": analysis_results,
                "total_morphemes": len(analysis_results),
                "sudachi_available": SUDACHI_AVAILABLE
            }
        )
    except Exception as e:
        return templates.TemplateResponse(
            "partials/analysis_error.html",
            {"request": request, "error": f"解析中にエラーが発生しました: {str(e)}"}
        )


@app.get("/health")
def health_check():
    """ヘルスチェック用エンドポイント"""
    return {
        "status": "healthy",
        "sudachi_available": SUDACHI_AVAILABLE,
        "version": "1.0.0"
    }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000, reload=True)