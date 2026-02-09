package validate

import (
	"fmt"

	"github.com/spf13/cobra"
)

var NcclCmd = &cobra.Command{
	Use:   "nccl",
	Short: "Validate an NCCL project",
	Run: func(cmd *cobra.Command, args []string) {
		fmt.Println("validate nccl")
	},
}
