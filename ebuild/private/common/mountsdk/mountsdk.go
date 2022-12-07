// Copyright 2022 The ChromiumOS Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package mountsdk

import (
	"context"
	_ "embed"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"

	"cros.local/bazel/ebuild/private/common/fileutil"
	"cros.local/bazel/ebuild/private/common/makechroot"
	"github.com/bazelbuild/rules_go/go/tools/bazel"
)

//go:embed setup.sh
var setupScript []byte

type Action = func(s *MountedSDK) error

const SourceDir = "/mnt/host/source"

type loginMode string

const (
	loginNever      loginMode = ""
	loginBeforeDeps loginMode = "before-deps"
	loginBefore     loginMode = "before"
	loginAfter      loginMode = "after"
	loginAfterFail  loginMode = "after-fail"
)

type Config struct {
	Overlays   []makechroot.OverlayInfo
	BindMounts []makechroot.BindMount
	// A list of paths which need to be remounted on top of the overlays.
	// For example, if you specify an overlay for /dir, but you want /dir/subdir
	// to come from the host, add /dir/subdir to Remounts.
	Remounts []string

	RunInContainerExtraArgs []string
	loginMode               loginMode
}

type MountedSDK struct {
	Config *Config

	RootDir fileutil.DualPath
	DiffDir string

	args []string
	env  []string
}

// RunInSDK prepares the SDK according to the specifications requested
func RunInSDK(cfg *Config, action Action) error {
	sdk := MountedSDK{Config: cfg}
	runInContainerPath, err := bazel.Runfile("bazel/ebuild/private/cmd/run_in_container/run_in_container_/run_in_container")
	if err != nil {
		return err
	}

	tmpDir, err := os.MkdirTemp("", "mountsdk.*")
	if err != nil {
		return err
	}
	defer fileutil.RemoveAllWithChmod(tmpDir)

	scratchDir := filepath.Join(tmpDir, "scratch")
	sdk.DiffDir = filepath.Join(scratchDir, "diff")
	sdk.RootDir = fileutil.NewDualPath(filepath.Join(tmpDir, "root"), "/")
	bazelBuildDir := sdk.RootDir.Add("mnt/host/bazel-build")

	if err := os.MkdirAll(bazelBuildDir.Outside(), 0o755); err != nil {
		return err
	}

	args := append([]string{
		runInContainerPath,
		"--scratch-dir=" + scratchDir,
		"--overlay=/=" + sdk.RootDir.Outside(),
	},
		cfg.RunInContainerExtraArgs...)

	for _, remount := range cfg.Remounts {
		if !filepath.IsAbs(remount) {
			return fmt.Errorf("expected remounts to be an absolute path: got %s", remount)
		}
		dualPath := sdk.RootDir.Add(remount[1:])
		if err := os.MkdirAll(dualPath.Outside(), 0755); err != nil {
			return err
		}
		args = append(args, "--overlay="+dualPath.Inside()+"="+dualPath.Outside())
	}

	for _, overlay := range cfg.Overlays {
		args = append(args, fmt.Sprintf("--overlay=%s=%s", overlay.MountDir, overlay.ImagePath))
	}

	for _, bindMount := range cfg.BindMounts {
		args = append(args, fmt.Sprintf("--bind-mount=%s=%s", bindMount.MountPath, bindMount.Source))
	}

	setupPath := bazelBuildDir.Add("setup.sh")
	if err := os.WriteFile(setupPath.Outside(), setupScript, 0o755); err != nil {
		return err
	}

	args = append(args, setupPath.Inside())
	sdk.args = args
	sdk.env = append(os.Environ(), "PATH=/usr/sbin:/usr/bin:/sbin:/bin")
	if cfg.loginMode != loginNever {
		sdk.env = append(sdk.env, fmt.Sprintf("_LOGIN_MODE=%s", cfg.loginMode))
	}
	return action(&sdk)
}

func (s *MountedSDK) Command(ctx context.Context, name string, args ...string) *exec.Cmd {

	cmd := exec.CommandContext(ctx, s.args[0], append(append(append([]string(nil), s.args[1:]...), name), args...)...)
	cmd.Env = append(cmd.Env, s.env...)
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd
}
