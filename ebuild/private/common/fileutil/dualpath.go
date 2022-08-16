package fileutil

import (
	"path/filepath"
)

type DualPath struct {
	outside, inside string
}

func NewDualPath(outside, inside string) DualPath {
	return DualPath{outside: outside, inside: inside}
}

func (dp DualPath) Outside() string { return dp.outside }
func (dp DualPath) Inside() string  { return dp.inside }

func (dp DualPath) Add(components ...string) DualPath {
	return NewDualPath(
		filepath.Join(append([]string{dp.outside}, components...)...),
		filepath.Join(append([]string{dp.inside}, components...)...))
}
