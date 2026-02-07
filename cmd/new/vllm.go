package new

import (
	"fmt"

	"github.com/spf13/cobra"
)

var vllmName string

var VllmCmd = &cobra.Command{
	Use:   "vllm",
	Short: "Create vLLM project",
	Run: func(cmd *cobra.Command, args []string) {
		fmt.Println("Creating vLLM project:", vllmName)
	},
}

func init() {
	VllmCmd.Flags().StringVar(&vllmName, "name", "", "Project name")
	_ = VllmCmd.MarkFlagRequired("name")
}
