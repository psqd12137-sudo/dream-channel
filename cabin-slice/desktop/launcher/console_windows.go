//go:build windows

package main

import (
	"syscall"
	"unsafe"
)

// setConsoleTitle 设置 Windows 控制台窗口标题，方便用户认出这是游戏服务窗口。
func setConsoleTitle(title string) {
	kernel32 := syscall.NewLazyDLL("kernel32.dll")
	proc := kernel32.NewProc("SetConsoleTitleW")
	ptr, _ := syscall.UTF16PtrFromString(title)
	proc.Call(uintptr(unsafe.Pointer(ptr)))
}
