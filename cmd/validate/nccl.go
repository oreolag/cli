package validate

import (
	"os"
	"os/exec"
	"path/filepath"

	"github.com/spf13/cobra"
)

var NcclCmd = &cobra.Command{
	Use:   "nccl",
	Short: "Benchmark NCCL collective primitives across your network fabric",
	RunE: func(cmd *cobra.Command, args []string) error {
		exe, err := os.Executable()
		if err != nil {
			return err
		}

		exeDir := filepath.Dir(exe)
		script := filepath.Join(
			exeDir,
			"..",
			"src",
			"cmd",
			"validate",
			"nccl.sh",
		)

		c := exec.Command(script)
		c.Stdout = os.Stdout
		c.Stderr = os.Stderr
		c.Stdin = os.Stdin

		return c.Run()
	},
}
