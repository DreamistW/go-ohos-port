package main

// #include <stdint.h>
import "C"

import "net"

// GoOhosAdd 供 C 调用方验证基本整数 ABI。
//
//export GoOhosAdd
func GoOhosAdd(a, b C.int32_t) C.int32_t {
	return a + b
}

// GoOhosInterfaceCount 返回 Go 枚举到的接口数，失败时返回 -1。
//
//export GoOhosInterfaceCount
func GoOhosInterfaceCount() C.int32_t {
	interfaces, err := net.Interfaces()
	if err != nil {
		return -1
	}
	return C.int32_t(len(interfaces))
}

func main() {}
