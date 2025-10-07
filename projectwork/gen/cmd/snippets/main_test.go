package main

import (
	"fmt"
	"testing"
	"time"
)

func Test1(t *testing.T) {
	dt := time.Now()
	fmt.Println(fmt.Sprintf("snippets_%04d_%02d", dt.Year(), dt.Month()))
}
