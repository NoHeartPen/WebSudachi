# WebSudachi 本地启动教程

## 环境准备

### 安装 Python

- 下载并安装 Python 3.8+
- 验证安装：`python --version`

### 获取项目

```bash
git clone https://github.com/NoHeartPen/WebSudachi
cd WebSudachi
```

### 创建虚拟环境

```bash
python -m venv venv

# 激活虚拟环境
# Mac/Linux:
source venv/bin/activate
# Windows:
venv\Scripts\activate
```

### 安装依赖

```bash
pip install -r requirements.txt
```

## 启动服务

### 命令行启动

```bash
uvicorn app:app --reload
```

### VS Code 调试启动

按 `F5` 选择 "Python Debugger: FastAPI"

## 访问地址

- 服务地址: <http://localhost:8000>
- API 文档: <http://localhost:8000/docs>
- 备用文档: <http://localhost:8000/redoc>
