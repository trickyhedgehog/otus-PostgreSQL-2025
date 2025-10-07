package internal

import "math/rand"

type IDGen struct {
	IDs []int64
}

func NewIDGen(from, to int64) (x *IDGen) {
	x = new(IDGen)
	x.IDs = make([]int64, to-from+1)
	var i int
	for id := from; id <= to; id++ {
		x.IDs[i] = id
		i++
	}
	return
}

func (x *IDGen) Get() int64 {
	n := rand.Intn(len(x.IDs))
	x.IDs[n] = x.IDs[len(x.IDs)-1]
	v := x.IDs[len(x.IDs)-1]
	x.IDs = x.IDs[:len(x.IDs)-1]
	return v
}
