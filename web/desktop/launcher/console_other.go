//go:build !windows

package main

// setConsoleTitle 在非 Windows 平台为 no-op。
func setConsoleTitle(title string) {}
