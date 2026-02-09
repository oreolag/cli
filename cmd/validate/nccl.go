package validate

import (
	"fmt"

	"github.com/spf13/cobra"
)

var NcclCmd = &cobra.Command{
	Use:   "nccl",
	Short: "Benchmark NCCL collective primitives across your network fabric",
	Run: func(cmd *cobra.Command, args []string) {
		fmt.Println("validate nccl")
	},
}
