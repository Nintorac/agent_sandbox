package main_test

import (
	"context"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
	"testing"
)

var bvBinaryPath string
var bvBinaryDir string

func TestMain(m *testing.M) {
	// Prevent any test from accidentally opening a browser
	os.Setenv("BV_NO_BROWSER", "1")
	os.Setenv("BV_TEST_MODE", "1")

	// Build the binary once for all tests
	if err := buildBvOnce(); err != nil {
		fmt.Fprintf(os.Stderr, "Failed to build bv binary: %v\n", err)
		os.Exit(1)
	}

	code := m.Run()
	if bvBinaryDir != "" {
		_ = os.RemoveAll(bvBinaryDir)
	}
	os.Exit(code)
}

func buildBvOnce() error {
	tempDir, err := os.MkdirTemp("", "bv-e2e-build-*")
	if err != nil {
		return err
	}
	bvBinaryDir = tempDir

	binName := "bv"
	if runtime.GOOS == "windows" {
		binName += ".exe"
	}
	binPath := filepath.Join(tempDir, binName)

	// Determine project root (../../) relative to this file
	// We assume tests are run from project root or package dir.
	// `go test ./tests/e2e/...` -> CWD is project root?
	// Actually `go test` sets CWD to the package directory.
	// So `../../` is correct for `tests/e2e`.

	cmd := exec.Command("go", "build", "-o", binPath, "../../cmd/bv")
	if out, err := cmd.CombinedOutput(); err != nil {
		return fmt.Errorf("go build failed: %v\n%s", err, out)
	}

	bvBinaryPath = binPath
	return nil
}

// buildBvBinary returns the path to the pre-built binary.
// It acts as a helper to ensure tests use the shared binary.
func buildBvBinary(t *testing.T) string {
	t.Helper()
	if bvBinaryPath == "" {
		t.Fatal("bv binary not built")
	}
	return bvBinaryPath
}

// skipIfNoScript skips the test if the script command is unavailable
func skipIfNoScript(t *testing.T) {
	t.Helper()
	if _, err := exec.LookPath("script"); err != nil {
		t.Skip("skipping: script command not available")
	}
}

// scriptTUICommand creates an exec.Cmd that runs the bv binary under `script`
// to provide a pseudo-TTY for TUI tests. This handles OS-specific differences:
// - macOS: script -q /dev/null <cmd> [args...]
// - Linux: script -q -c "<cmd> [args...]" /dev/null
// Returns nil if script is unavailable (test should skip).
func scriptTUICommand(ctx context.Context, bvPath string, args ...string) *exec.Cmd {
	// Check if script command is available
	if _, err := exec.LookPath("script"); err != nil {
		return nil
	}

	switch runtime.GOOS {
	case "darwin":
		// macOS: script -q /dev/null <cmd> [args...]
		scriptArgs := []string{"-q", "/dev/null", bvPath}
		scriptArgs = append(scriptArgs, args...)
		return exec.CommandContext(ctx, "script", scriptArgs...)

	case "linux":
		// Linux: script -q -c "<cmd> [args...]" /dev/null
		// Build the command string - need to quote/escape properly
		cmdStr := bvPath
		for _, arg := range args {
			// Simple quoting for args with spaces
			if strings.ContainsAny(arg, " \t") {
				cmdStr += " \"" + arg + "\""
			} else {
				cmdStr += " " + arg
			}
		}
		return exec.CommandContext(ctx, "script", "-q", "-c", cmdStr, "/dev/null")

	default:
		// Windows and others don't have script
		return nil
	}
}
