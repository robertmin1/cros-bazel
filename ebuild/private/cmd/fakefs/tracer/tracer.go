// Copyright 2022 The ChromiumOS Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package tracer

import (
	"fmt"
	"os"
	"os/exec"

	"golang.org/x/sys/unix"

	"cros.local/bazel/ebuild/private/cmd/fakefs/logging"
	"cros.local/bazel/ebuild/private/cmd/fakefs/ptracearch"
)

type Hook interface {
	Syscall(tid int, regs *ptracearch.Regs, logger *logging.ThreadLogger) func(regs *ptracearch.Regs)
}

func startTracee(args []string) (pid int, err error) {
	// Don't use args[0] as the command path as callers (such as Portage!)
	// might have set some fancy strings.
	exe, err := os.Executable()
	if err != nil {
		return 0, err
	}

	cmd := exec.Command(exe, append([]string{"--tracee"}, args[1:]...)...)
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Start(); err != nil {
		return 0, err
	}

	pid = cmd.Process.Pid

	// Wait for the tracee to stop.
	for {
		var ws unix.WaitStatus
		if _, err := unix.Wait4(pid, &ws, unix.WUNTRACED, nil); err != nil {
			return 0, fmt.Errorf("failed to wait for tracee %d to stop initially: %w", pid, err)
		}
		if !ws.Stopped() {
			return 0, fmt.Errorf("tracee exited prematurely: exit code %d", exitCode(ws))
		}
		if ws.StopSignal() == unix.SIGSTOP {
			break
		}
	}

	// Seize the tracee.
	const options = unix.PTRACE_O_EXITKILL |
		unix.PTRACE_O_TRACESYSGOOD |
		unix.PTRACE_O_TRACEEXEC |
		unix.PTRACE_O_TRACECLONE |
		unix.PTRACE_O_TRACEFORK |
		unix.PTRACE_O_TRACEVFORK |
		unix.PTRACE_O_TRACESECCOMP
	if err := ptraceSeize(pid, options); err != nil {
		return 0, fmt.Errorf("failed to initialize tracee: ptrace(PTRACE_SEIZE, %d): %w", pid, err)
	}

	// Start the process.
	if err := unix.Kill(pid, unix.SIGCONT); err != nil {
		return 0, fmt.Errorf("failed to start tracee: kill(%d, SIGCONT): %w", pid, err)
	}

	return pid, nil
}

func waitNextStop(rootPid int, index *threadStateIndex, globalLogger *logging.GlobalLogger) (*threadState, unix.WaitStatus, error) {
	for {
		var ws unix.WaitStatus
		tid, err := unix.Wait4(-1, &ws, unix.WALL, nil)
		if err != nil {
			return nil, 0, fmt.Errorf("wait4: %w", err)
		}

		thread := index.GetByTid(tid)
		if thread == nil {
			// This should be a new thread.
			pid, err := lookupPidByTid(tid)
			if err != nil {
				continue
			}
			thread = &threadState{
				Tid:             tid,
				Pid:             pid,
				CurrentSyscall:  -1,
				SyscallExitHook: nil,
				Logger:          globalLogger.ForThread(&logging.Thread{Tid: tid, Pid: pid}),
			}
			index.Put(thread)
			thread.Logger.Printf("* thread born")
		}

		// Process finished processes.
		if ws.Exited() || ws.Signaled() {
			index.Remove(thread)
			thread.Logger.Printf("* thread exited (%d)", exitCode(ws))

			// If this is the last thread in the root process, terminate
			// the tracer itself with the same exit code.
			if thread.Pid == rootPid && len(index.GetByPid(rootPid)) == 0 {
				os.Exit(exitCode(ws))
			}
			continue
		}

		// The process should have stopped.
		if !ws.Stopped() {
			return nil, 0, fmt.Errorf("wait4: tid %d: unknown wait status 0x%x", tid, ws)
		}

		return thread, ws, nil
	}
}

type continueAction int

const (
	continueActionInject continueAction = iota
	continueActionIgnore
	continueActionSyscall
	continueActionListen
)

func processStop(thread *threadState, ws unix.WaitStatus, hook Hook, index *threadStateIndex) (continueAction, error) {
	stopSignal := ws.StopSignal()

	if stopSignal == unix.SIGTRAP|0x80 {
		// syscall-exit-stop.
		var regs ptracearch.Regs
		if err := ptracearch.GetRegs(thread.Tid, &regs); err != nil {
			return continueActionIgnore, nil
		}

		if thread.CurrentSyscall < 0 {
			return continueActionIgnore, fmt.Errorf("syscall-stop but no current syscall")
		}

		thread.Logger.FinishSyscall(int64(regs.Rax))

		if thread.SyscallExitHook != nil {
			thread.SyscallExitHook(&regs)
		}

		thread.CurrentSyscall = -1
		thread.SyscallExitHook = nil
		return continueActionIgnore, nil
	}

	if trapCause := ws.TrapCause(); trapCause > 0 {
		// PTRACE_EVENT stops.

		switch trapCause {
		case unix.PTRACE_EVENT_SECCOMP:
			// syscall-entry-stop.
			var regs ptracearch.Regs
			if err := ptracearch.GetRegs(thread.Tid, &regs); err != nil {
				return continueActionIgnore, nil
			}

			nr := int(regs.Orig_rax)
			thread.CurrentSyscall = nr
			thread.SyscallExitHook = hook.Syscall(thread.Tid, &regs, thread.Logger)
			thread.Logger.StartSyscall(nr)

			return continueActionSyscall, nil

		case unix.PTRACE_EVENT_CLONE, unix.PTRACE_EVENT_FORK, unix.PTRACE_EVENT_VFORK:
			// Do nothing.
			return continueActionIgnore, nil

		case unix.PTRACE_EVENT_EXEC:
			if thread.Tid != thread.Pid {
				return continueActionIgnore, fmt.Errorf("PTRACE_EVENT_EXEC: expected tid (%d) == pid (%d)", thread.Tid, thread.Pid)
			}
			thread.Logger.Printf("* exec")

			for _, siblingThread := range index.GetByPid(thread.Pid) {
				if siblingThread.Tid != thread.Tid {
					index.Remove(siblingThread)
					siblingThread.Logger.Printf("* thread gone (exec)")
				}
			}
			thread.CurrentSyscall = -1
			thread.SyscallExitHook = nil
			return continueActionIgnore, nil

		case unix.PTRACE_EVENT_STOP:
			if stopSignal == unix.SIGTRAP {
				// Initial stop of clone/fork/vfork threads.
				return continueActionIgnore, nil
			}
			// group-stop.
			thread.Logger.Printf("* group-stop (%s)", unix.SignalName(stopSignal))
			return continueActionListen, nil

		default:
			return continueActionIgnore, fmt.Errorf("unknown trap cause %d", trapCause)
		}
	}

	// signal-delivery-stop.
	thread.Logger.Printf("* %s", unix.SignalName(ws.StopSignal()))
	if ws.StopSignal() == unix.SIGSTOP {
		return continueActionIgnore, nil
	}
	return continueActionInject, nil
}

func Run(origArgs []string, hook Hook, globalLogger *logging.GlobalLogger) error {
	rootPid, err := startTracee(origArgs)
	if err != nil {
		return err
	}

	index := newThreadStateIndex()

	for {
		thread, ws, err := waitNextStop(rootPid, index, globalLogger)
		if err != nil {
			return err
		}

		action, err := processStop(thread, ws, hook, index)
		if err != nil {
			return err
		}

		switch action {
		case continueActionInject:
			_ = unix.PtraceCont(thread.Tid, int(ws.StopSignal()))

		case continueActionIgnore:
			_ = unix.PtraceCont(thread.Tid, 0)

		case continueActionSyscall:
			_ = unix.PtraceSyscall(thread.Tid, 0)

		case continueActionListen:
			_ = ptraceListen(thread.Tid)

		default:
			return fmt.Errorf("unknown stop action %d", action)
		}
	}
}