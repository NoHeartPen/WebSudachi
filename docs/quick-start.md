# WebSudachi 本地启动教程

## 环境准备

### 安装 Python

- 下载并安装 Python 3.8+（警告： 请不要安装 Python 3.14 及以上版本）
- 验证安装：`python --version`

### 获取项目

```bash
git clone https://github.com/NoHeartPen/WebSudachi
cd WebSudachi
```

### 创建虚拟环境

```bash
python -m venv venv
```

Windows 电脑请执行：

```bash
venv\Scripts\activate
```

Mac/Linux 电脑请执行（Windows 电脑请忽略这行命令）:

```bash
source venv/bin/activate
```

### 安装依赖

```bash
pip install -r requirements.txt
```

如果遇到下面的报错提示，请在命令行输入`python`检查系统变量默认的 Python 版本。如果是 3.14 或以上版本，请卸载重装；或安装 3.13 版本的 Python 后将安装路径临时设置为系统变量。

![error: subprocess-exited-with-error](/docs/assets/1766888658162.webp)

![error: failed-wheel-build-for-install](/docs/assets/1766888631774.webp)

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
