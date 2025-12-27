# 常见问题

## 端口占用

```bash
# Mac/Linux
lsof -ti:8000 | xargs kill -9

# Windows
netstat -ano | findstr :8000
taskkill /PID <进程ID> /F
```

## 使用其他端口

```bash
uvicorn app:app --port 8001 --reload
```

## 模块未找到

```bash
pip install <缺失包名>
```
