package new

import (
	"fmt"

	"github.com/spf13/cobra"
)

var name string

var NcclCmd = &cobra.Command{
	Use: "nccl",
	//Short: "Create NCCL project",
	Run: func(cmd *cobra.Command, args []string) {
		fmt.Println("Creating NCCL project:", name)
	},
}

func init() {
	NcclCmd.Flags().StringVar(&name, "name", "", "Project name")
	_ = NcclCmd.MarkFlagRequired("name")
}
