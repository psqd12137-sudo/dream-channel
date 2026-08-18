// 织梦频道·Cabin Slice 本地启动器
// 双击即可运行：内嵌整个游戏目录，在本地起一个 HTTP 服务并自动打开浏览器。
package main

import (
	"bytes"
	"embed"
	"fmt"
	"io"
	"io/fs"
	"log"
	"net"
	"net/http"
	"os"
	"os/exec"
	"path"
	"path/filepath"
	"runtime"
	"strconv"
	"strings"
)

//go:embed web/*
var webFS embed.FS

var mimeTypes = map[string]string{
	".html": "text/html; charset=utf-8",
	".js":   "application/javascript; charset=utf-8",
	".mjs":  "application/javascript; charset=utf-8",
	".css":  "text/css; charset=utf-8",
	".json": "application/json; charset=utf-8",
	".png":  "image/png",
	".jpg":  "image/jpeg",
	".jpeg": "image/jpeg",
	".gif":  "image/gif",
	".webp": "image/webp",
	".svg":  "image/svg+xml",
	".ico":  "image/x-icon",
	".wav":  "audio/wav",
	".mp3":  "audio/mpeg",
	".ogg":  "audio/ogg",
	".mp4":  "video/mp4",
	".ttf":  "font/ttf",
	".otf":  "font/otf",
	".woff": "font/woff",
	".woff2": "font/woff2",
	".xml":  "application/xml; charset=utf-8",
	".txt":  "text/plain; charset=utf-8",
}

func main() {
	sub, err := fs.Sub(webFS, "web")
	if err != nil {
		fatal(err)
	}

	handler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// 调试用：静态服务器下跳过实验数据回传（避免 404 噪音）
		if r.URL.Path == "/__dump-lab" {
			w.WriteHeader(http.StatusNoContent)
			return
		}
		p := strings.TrimPrefix(r.URL.Path, "/")
		if p == "" || p == "index.html" {
			serveFile(w, r, sub, "index.html")
			return
		}
		clean := path.Clean(p)
		if strings.HasPrefix(clean, "../") || clean == ".." {
			http.NotFound(w, r)
			return
		}
		serveFile(w, r, sub, clean)
	})

	port := choosePort(17887)
	addr := fmt.Sprintf("127.0.0.1:%d", port)
	ln, err := net.Listen("tcp", addr)
	if err != nil {
		fatal(fmt.Errorf("无法监听 %s: %w", addr, err))
	}

	url := fmt.Sprintf("http://%s/", addr)
	setConsoleTitle("织梦频道 · Cabin Slice")
	fmt.Println("")
	fmt.Println("==============================")
	fmt.Println(" 织梦频道 · Cabin Slice")
	fmt.Println(" 游戏已在本地启动：" + url)
	fmt.Println(" 请勿关闭本窗口（关闭即退出游戏服务）")
	fmt.Println("==============================")
	fmt.Println("")

	go openBrowser(url)

	if err := http.Serve(ln, handler); err != nil {
		fatal(err)
	}
}

func serveFile(w http.ResponseWriter, r *http.Request, sub fs.FS, name string) {
	f, err := sub.Open(name)
	if err != nil {
		http.NotFound(w, r)
		return
	}
	info, err := f.Stat()
	if err != nil {
		f.Close()
		http.NotFound(w, r)
		return
	}
	if info.IsDir() {
		f.Close()
		// 目录请求：尝试 index.html
		serveFile(w, r, sub, path.Join(name, "index.html"))
		return
	}
	data, err := io.ReadAll(f)
	f.Close()
	if err != nil {
		http.NotFound(w, r)
		return
	}
	if ct, ok := mimeTypes[strings.ToLower(path.Ext(name))]; ok {
		w.Header().Set("Content-Type", ct)
	}
	http.ServeContent(w, r, info.Name(), info.ModTime(), bytes.NewReader(data))
}

// 从 17887 起找空闲端口
func choosePort(start int) int {
	for p := start; p < start+50; p++ {
		ln, err := net.Listen("tcp", "127.0.0.1:"+strconv.Itoa(p))
		if err == nil {
			ln.Close()
			return p
		}
	}
	return start
}

func openBrowser(url string) {
	var cmd *exec.Cmd
	switch runtime.GOOS {
	case "windows":
		// Windows 打开默认浏览器
		cmd = exec.Command("rundll32", "url.dll,FileProtocolHandler", url)
	case "darwin":
		cmd = exec.Command("open", url)
	default:
		cmd = exec.Command("xdg-open", url)
	}
	if err := cmd.Start(); err != nil {
		log.Println("打开浏览器失败（可手动访问 " + url + "）：", err)
	}
}

func fatal(err error) {
	msg := fmt.Sprintf("织梦频道·Cabin Slice 启动失败：%v\n", err)
	fmt.Fprintln(os.Stderr, msg)
	if exe, exeErr := os.Executable(); exeErr == nil {
		if f, fErr := os.OpenFile(filepath.Join(filepath.Dir(exe), "launcher-error.log"),
			os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644); fErr == nil {
			f.WriteString(msg + "\n")
			f.Close()
		}
	}
	if runtime.GOOS == "windows" {
		// 无控制台时用消息框告知用户
		exec.Command("rundll32", "user32.dll,MessageBoxW", "织梦频道", msg).Run()
	} else {
		waitExit()
	}
	os.Exit(1)
}

func waitExit() {
	fmt.Print("按回车键退出…")
	var b [1]byte
	os.Stdin.Read(b[:])
}
